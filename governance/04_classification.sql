-- =============================================================================
-- Governance 04 - Auto-classification (PII discovery)
-- Snowflake inspects columns and proposes semantic/privacy categories, so you don't
-- hunt for PII by hand across scattered systems.
-- Idempotent. Run as ACCOUNTADMIN.
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

-- Classify the CRM table and show proposed semantic + privacy categories per column.
-- (EXTRACT_SEMANTIC_CATEGORIES samples the data; runs in seconds.)
WITH c AS (
  SELECT EXTRACT_SEMANTIC_CATEGORIES('CROCEVIA_DB.BRONZE_DATA.CROCEVIA_CRM') AS res
)
SELECT
  f.key                                                   AS column_name,
  f.value:"recommendation":"semantic_category"::STRING    AS semantic_category,
  f.value:"recommendation":"privacy_category"::STRING     AS privacy_category,
  f.value:"recommendation":"confidence"::STRING           AS confidence
FROM c, TABLE(FLATTEN(INPUT => c.res)) f
ORDER BY 1;

-- Result highlights EMAIL / NAME / PHONE_NUMBER as IDENTIFIERs and
-- DATE_OF_BIRTH / GENDER / LAT-LONG / POSTAL_CODE as QUASI_IDENTIFIERs,
-- which is exactly what the SENSITIVITY='PII' tags + masking in 01/02 protect.

-- Optional: persist tags automatically with ASSOCIATE_SEMANTIC_CATEGORY_TAGS, or run
-- continuous classification via a CLASSIFICATION PROFILE with auto_tag=true so newly
-- added PII columns are tagged without manual work.
