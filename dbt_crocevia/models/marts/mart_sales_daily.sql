-- Daily sales fact at store x product-category grain. The core mart consumed by the
-- apps, the semantic view and the forecast notebook.
with sales as (
    select * from {{ ref('stg_sales') }}
),
products as (
    select product_id, product_category, brand from {{ ref('stg_products') }}
),
stores as (
    select store_id, store_name, departement_code from {{ ref('stg_stores') }}
)

select
    s.sale_date,
    s.store_id,
    coalesce(st.store_name, s.store_name)               as store_name,
    st.departement_code,
    coalesce(p.product_category, 'UNKNOWN')             as product_category,
    count(distinct s.order_id)                          as orders,
    sum(s.quantity)                                     as units,
    round(sum(s.net_sales_euro), 2)                     as revenue_eur,
    round(sum(s.discount_amount_euro), 2)               as discount_eur,
    count(distinct s.customer_id)                       as distinct_customers
from sales s
left join products p on s.product_id = p.product_id
left join stores st  on s.store_id = st.store_id
group by 1, 2, 3, 4, 5
