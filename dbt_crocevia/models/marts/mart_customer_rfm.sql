-- Customer RFM scoring over the demo window. Recency is measured against the latest
-- sale date (synthetic data ends 2025-06-30), not CURRENT_DATE.
with sales as (
    select * from {{ ref('stg_sales') }}
    where customer_id is not null
),
bounds as (
    select max(sale_date) as max_sale_date from sales
),
facts as (
    select
        s.customer_id,
        datediff('day', max(s.sale_date), b.max_sale_date)          as recency_days,
        count(distinct s.order_id)                                  as frequency,
        round(sum(s.net_sales_euro), 2)                             as monetary_eur
    from sales s
    cross join bounds b
    group by s.customer_id, b.max_sale_date
),
scored as (
    select
        customer_id,
        recency_days,
        frequency,
        monetary_eur,
        case when recency_days <= 30  then 'R3'
             when recency_days <= 90  then 'R2'
             when recency_days <= 180 then 'R1' else 'R0' end       as r_score,
        case when frequency >= 10 then 'F3'
             when frequency >= 5  then 'F2'
             when frequency >= 2  then 'F1' else 'F0' end           as f_score,
        case when monetary_eur >= 1000 then 'M3'
             when monetary_eur >= 300  then 'M2'
             when monetary_eur >= 100  then 'M1' else 'M0' end      as m_score
    from facts
)

select
    customer_id,
    recency_days,
    frequency,
    monetary_eur,
    r_score, f_score, m_score,
    r_score || f_score || m_score                                   as rfm_code,
    case
        when r_score = 'R3' and f_score in ('F2','F3') and m_score in ('M2','M3') then 'LOYAL_HIGH_VALUE'
        when r_score in ('R2','R3') and f_score = 'F0' then 'NEW_CUSTOMER'
        when r_score in ('R0','R1') and f_score in ('F0','F1') then 'AT_RISK'
        when m_score = 'M3' then 'HIGH_SPENDER'
        else 'STANDARD'
    end                                                             as segment
from scored
