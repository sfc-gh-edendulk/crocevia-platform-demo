-- Cleaned product catalogue. Parses French-formatted price ("1,49" -> 1.49) and the
-- AVIS rating string ("4.8/5 (5)" -> 4.8). Deduplicated on product_id.
select
    product_id,
    product                                                         as product_name,
    nullif(trim(brand), '')                                         as brand,
    coalesce(product_category, 'UNKNOWN')                           as product_category,
    coalesce(product_subcategory, 'UNKNOWN')                        as product_subcategory,
    volume,
    try_to_decimal(replace(price, ',', '.'), 10, 2)                 as price_eur,
    try_to_decimal(split_part(avis, '/', 1), 4, 2)                  as rating
from {{ source('bronze', 'CROCEVIA_PRODUCTS') }}
where product_id is not null
qualify row_number() over (partition by product_id order by product) = 1
