-- Cleaned sales line items, scoped to the last N months (var: sales_lookback_months)
-- relative to the latest sale date in the source. Materialized as a view to avoid
-- copying the very large source table.
with bounds as (
    select
        max(sale_date)                                          as max_sale_date,
        dateadd('month', -{{ var('sales_lookback_months') }},
                max(sale_date))                                 as min_sale_date
    from {{ source('bronze', 'CROCEVIA_SALES_20PCT_STORES') }}
)

select
    s.order_id,
    s.store_id,
    s.store_name,
    s.sale_date,
    s.product_id,
    s.quantity,
    s.sales_price_euro,
    coalesce(s.discount_amount_euro, 0)                         as discount_amount_euro,
    s.sales_price_euro - coalesce(s.discount_amount_euro, 0)    as net_sales_euro,
    s.payment_method,
    s.sales_assistant_id,
    s.customer_id
from {{ source('bronze', 'CROCEVIA_SALES_20PCT_STORES') }} s
cross join bounds b
where s.sale_date >= b.min_sale_date
