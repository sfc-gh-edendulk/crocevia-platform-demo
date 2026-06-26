-- Cleaned store directory. Derives a French region key from the postcode
-- (first two digits = departement). Deduplicated on store_id.
select
    storeid                                                         as store_id,
    store                                                           as store_name,
    address,
    postcode,
    left(postcode, 2)                                               as departement_code,
    open_hours
from {{ source('bronze', 'CROCEVIA_STORES') }}
where storeid is not null
qualify row_number() over (partition by storeid order by store) = 1
