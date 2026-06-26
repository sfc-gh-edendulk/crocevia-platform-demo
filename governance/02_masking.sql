-- =============================================================================
-- Governance 02 - Masking policies (tag-based + direct)
-- Demonstrates: tag a column SENSITIVITY='PII' once -> it is masked everywhere.
-- The data steward sees clear values; everyone else sees masked.
-- Idempotent. Run as ACCOUNTADMIN after 01_tags.sql.
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

-- Generic email mask: keep domain, hide local part unless steward.
CREATE OR REPLACE MASKING POLICY MASK_EMAIL AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CROCEVIA_DATA_STEWARD') THEN val
    WHEN val IS NULL THEN NULL
    ELSE '****@' || SPLIT_PART(val, '@', 2)
  END;

-- Generic string mask (names): show first char only.
CREATE OR REPLACE MASKING POLICY MASK_NAME AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CROCEVIA_DATA_STEWARD') THEN val
    WHEN val IS NULL THEN NULL
    ELSE LEFT(val, 1) || '***'
  END;

-- Phone mask: keep last 2 digits.
CREATE OR REPLACE MASKING POLICY MASK_PHONE AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CROCEVIA_DATA_STEWARD') THEN val
    WHEN val IS NULL THEN NULL
    ELSE 'XX XX XX XX ' || RIGHT(val, 2)
  END;

-- --- Tag-based masking: bind a policy to the SENSITIVITY tag -----------------
-- Any column tagged SENSITIVITY (string type) is automatically protected by MASK_NAME.
-- (Email/phone get more specific policies attached directly below for nicer output.)
ALTER TAG CROCEVIA_DB.PLATFORM_DEMO.SENSITIVITY SET
  MASKING POLICY MASK_NAME;

-- More specific direct policies on email/phone override the generic tag policy.
ALTER TABLE CROCEVIA_DB.BRONZE_DATA.CROCEVIA_CRM MODIFY COLUMN EMAIL SET MASKING POLICY MASK_EMAIL;
ALTER TABLE CROCEVIA_DB.BRONZE_DATA.CROCEVIA_CRM MODIFY COLUMN PHONE SET MASKING POLICY MASK_PHONE;

-- Verify attachments
SELECT * FROM TABLE(CROCEVIA_DB.INFORMATION_SCHEMA.POLICY_REFERENCES(
  REF_ENTITY_NAME => 'CROCEVIA_DB.BRONZE_DATA.CROCEVIA_CRM',
  REF_ENTITY_DOMAIN => 'TABLE'));
