-- Product performance over the demo window, with a recent-30-day revenue slice
-- (relative to the latest sale date, since synthetic data ends 2025-06-30).
with sales as (
    select * from {{ ref('stg_sales') }}
),
bounds as (
    select max(sale_date) as max_sale_date from sales
),
products as (
    select * from {{ ref('stg_products') }}
),
agg as (
    select
        s.product_id,
        count(distinct s.order_id)                                  as orders,
        sum(s.quantity)                                             as units,
        round(sum(s.net_sales_euro), 2)                             as revenue_eur,
        round(sum(case when s.sale_date >= dateadd('day', -30, b.max_sale_date)
                       then s.net_sales_euro else 0 end), 2)        as revenue_last_30d_eur,
        max(s.sale_date)                                            as last_sale_date
    from sales s
    cross join bounds b
    group by 1
)

select
    p.product_id,
    p.product_name,
    p.brand,
    p.product_category,
    p.product_subcategory,
    p.price_eur,
    p.rating,
    a.orders,
    a.units,
    a.revenue_eur,
    a.revenue_last_30d_eur,
    a.last_sale_date
from agg a
join products p on a.product_id = p.product_id
