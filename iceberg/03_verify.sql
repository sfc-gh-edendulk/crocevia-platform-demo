-- =============================================================================
-- Iceberg 03 - Proof points (run live during the demo)
-- -----------------------------------------------------------------------------
-- Three things to show:
--   A. It is a real open Iceberg table, with metadata/data files in GCS.
--   B. Masking works on the open table (admin sees clear; others see masked).
--   C. Row-access works on the open table (store manager sees only their region).
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

-- --- A. Open format, in your bucket ------------------------------------------
-- Catalog = SNOWFLAKE, external_volume = GCS, plus the base location path.
SHOW ICEBERG TABLES LIKE 'CUSTOMER_360_ICEBERG' IN SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

-- Current Iceberg metadata file location (this path lives in YOUR GCS bucket and
-- is what an external engine like BigQuery/Spark would point at).
SELECT SYSTEM$GET_ICEBERG_TABLE_INFORMATION('CROCEVIA_DB.PLATFORM_DEMO.CUSTOMER_360_ICEBERG') AS iceberg_metadata;

-- --- B. Masking on the open table (as ACCOUNTADMIN: clear values) ------------
SELECT CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE, DEPARTEMENT_CODE
FROM CROCEVIA_DB.PLATFORM_DEMO.CUSTOMER_360_ICEBERG
LIMIT 5;
-- Then re-run the same SELECT as a non-privileged role to see masked output:
--   snow sql -q "USE ROLE CROCEVIA_STORE_MANAGER_DEMO; SELECT ... FROM CUSTOMER_360_ICEBERG LIMIT 5;"
--   -> FIRST_NAME 'J***', EMAIL '****@domain', PHONE 'XX XX XX XX 12'

-- --- C. Row-access on the open table -----------------------------------------
-- As admin: all departements present.
SELECT DEPARTEMENT_CODE, COUNT(*) AS n_customers
FROM CROCEVIA_DB.PLATFORM_DEMO.CUSTOMER_360_ICEBERG
GROUP BY DEPARTEMENT_CODE
ORDER BY n_customers DESC
LIMIT 10;
-- As CROCEVIA_STORE_MANAGER_DEMO: only departements 59 / 62 / 80 come back,
-- proving the regional row-access policy is enforced on the Iceberg table too.
