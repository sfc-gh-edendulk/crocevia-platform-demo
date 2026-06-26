-- Store performance over the demo window, with a recent-30-day revenue slice.
with sales as (
    select * from {{ ref('stg_sales') }}
),
bounds as (
    select max(sale_date) as max_sale_date from sales
),
stores as (
    select * from {{ ref('stg_stores') }}
),
agg as (
    select
        s.store_id,
        count(distinct s.order_id)                                  as orders,
        sum(s.quantity)                                             as units,
        round(sum(s.net_sales_euro), 2)                             as revenue_eur,
        round(sum(case when s.sale_date >= dateadd('day', -30, b.max_sale_date)
                       then s.net_sales_euro else 0 end), 2)        as revenue_last_30d_eur,
        count(distinct s.customer_id)                               as distinct_customers,
        round(sum(s.net_sales_euro) / nullif(count(distinct s.order_id), 0), 2) as avg_basket_eur
    from sales s
    cross join bounds b
    group by 1
)

select
    coalesce(st.store_id, a.store_id)                               as store_id,
    st.store_name,
    st.departement_code,
    st.postcode,
    a.orders,
    a.units,
    a.revenue_eur,
    a.revenue_last_30d_eur,
    a.distinct_customers,
    a.avg_basket_eur
from agg a
left join stores st on a.store_id = st.store_id
