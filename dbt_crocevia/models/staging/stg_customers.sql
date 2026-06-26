-- Cleaned customer master. PII columns (email, phone, names) are retained here and
-- protected downstream by tag-based masking (see governance/). Deduplicated on customer_id.
select
    customer_id,
    first_name,
    last_name,
    gender,
    birth_date,
    email,
    phone,
    postal_code,
    left(postal_code, 2)                                            as departement_code,
    source
from {{ source('bronze', 'CROCEVIA_CRM') }}
where customer_id is not null
qualify row_number() over (partition by customer_id order by source) = 1
