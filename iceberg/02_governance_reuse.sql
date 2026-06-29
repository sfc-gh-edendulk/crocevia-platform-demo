-- =============================================================================
-- Iceberg 02 - Reuse the SAME governance on the open Iceberg table
-- -----------------------------------------------------------------------------
-- The punchline: governance is decoupled from storage format. The masking and
-- row-access policies we built for native tables attach, unchanged, to an open
-- Apache Iceberg table living in GCS. One policy definition, enforced whether the
-- bytes are Snowflake-native or open Parquet in your own bucket.
--
-- Reuses objects from governance/01-03:
--   MASK_NAME, MASK_EMAIL, MASK_PHONE   (masking policies)
--   SENSITIVITY tag                      (tag-based masking)
--   RAP_REGION                           (regional row-access policy)
-- Idempotent. Run as ACCOUNTADMIN after iceberg/01 and governance/01-03.
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

-- --- Column masking on the Iceberg table -------------------------------------
ALTER ICEBERG TABLE CUSTOMER_360_ICEBERG MODIFY COLUMN FIRST_NAME SET MASKING POLICY MASK_NAME;
ALTER ICEBERG TABLE CUSTOMER_360_ICEBERG MODIFY COLUMN LAST_NAME  SET MASKING POLICY MASK_NAME;
ALTER ICEBERG TABLE CUSTOMER_360_ICEBERG MODIFY COLUMN EMAIL      SET MASKING POLICY MASK_EMAIL;
ALTER ICEBERG TABLE CUSTOMER_360_ICEBERG MODIFY COLUMN PHONE      SET MASKING POLICY MASK_PHONE;

-- --- Tag the PII columns (drives tag-based discovery + auto-masking) ----------
ALTER ICEBERG TABLE CUSTOMER_360_ICEBERG MODIFY COLUMN FIRST_NAME SET TAG SENSITIVITY = 'PII';
ALTER ICEBERG TABLE CUSTOMER_360_ICEBERG MODIFY COLUMN LAST_NAME  SET TAG SENSITIVITY = 'PII';
ALTER ICEBERG TABLE CUSTOMER_360_ICEBERG MODIFY COLUMN EMAIL      SET TAG SENSITIVITY = 'PII';
ALTER ICEBERG TABLE CUSTOMER_360_ICEBERG MODIFY COLUMN PHONE      SET TAG SENSITIVITY = 'PII';

-- --- Regional row-access (store manager sees only their departements) ---------
ALTER ICEBERG TABLE CUSTOMER_360_ICEBERG
  ADD ROW ACCESS POLICY RAP_REGION ON (DEPARTEMENT_CODE);

-- Verify all policy attachments landed on the Iceberg table.
SELECT POLICY_KIND, POLICY_NAME, REF_COLUMN_NAME
FROM TABLE(CROCEVIA_DB.INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME   => 'CROCEVIA_DB.PLATFORM_DEMO.CUSTOMER_360_ICEBERG',
  REF_ENTITY_DOMAIN => 'TABLE'))
ORDER BY POLICY_KIND, POLICY_NAME;
