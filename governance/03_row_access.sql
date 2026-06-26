-- =============================================================================
-- Governance 03 - Row-access policy (regional data scoping)
-- A store manager only sees their region's rows; steward/admin see everything.
-- Demonstrates governance that OPENS access safely (per-region self-service).
-- Idempotent. Run as ACCOUNTADMIN after 01_tags.sql.
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

-- Mapping: which role can see which French departement codes.
CREATE TABLE IF NOT EXISTS CROCEVIA_DB.PLATFORM_DEMO.ROLE_REGION_MAP (
  ROLE_NAME         STRING,
  DEPARTEMENT_CODE  STRING
);

-- Give the demo store-manager role a small set of departements (Nord region).
DELETE FROM CROCEVIA_DB.PLATFORM_DEMO.ROLE_REGION_MAP WHERE ROLE_NAME = 'CROCEVIA_STORE_MANAGER_DEMO';
INSERT INTO CROCEVIA_DB.PLATFORM_DEMO.ROLE_REGION_MAP (ROLE_NAME, DEPARTEMENT_CODE) VALUES
  ('CROCEVIA_STORE_MANAGER_DEMO', '59'),
  ('CROCEVIA_STORE_MANAGER_DEMO', '62'),
  ('CROCEVIA_STORE_MANAGER_DEMO', '80');

CREATE OR REPLACE ROW ACCESS POLICY RAP_REGION
AS (departement_code STRING) RETURNS BOOLEAN ->
  -- Full visibility for admin/steward
  CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CROCEVIA_DATA_STEWARD')
  -- Otherwise only rows for departements mapped to the current role
  OR EXISTS (
    SELECT 1 FROM CROCEVIA_DB.PLATFORM_DEMO.ROLE_REGION_MAP m
    WHERE m.ROLE_NAME = CURRENT_ROLE()
      AND m.DEPARTEMENT_CODE = departement_code
  );

ALTER TABLE CROCEVIA_DB.PLATFORM_DEMO.MART_SALES_DAILY
  ADD ROW ACCESS POLICY RAP_REGION ON (DEPARTEMENT_CODE);
ALTER TABLE CROCEVIA_DB.PLATFORM_DEMO.MART_STORE_PERFORMANCE
  ADD ROW ACCESS POLICY RAP_REGION ON (DEPARTEMENT_CODE);

-- Quick proof (run after USE ROLE CROCEVIA_STORE_MANAGER_DEMO): should only show 59/62/80
-- SELECT DISTINCT departement_code FROM CROCEVIA_DB.PLATFORM_DEMO.MART_STORE_PERFORMANCE ORDER BY 1;
