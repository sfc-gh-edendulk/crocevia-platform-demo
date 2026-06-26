-- =============================================================================
-- Crocevia Platform Demo - Context & account-level setup
-- Run FIRST. Idempotent. Target: a Snowflake account on GCP europe-west3.
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- Reuse existing data foundation
USE DATABASE CROCEVIA_DB;
USE WAREHOUSE CR_DEV_WH;

-- New schema that holds all demo-built objects (marts, forecasts, semantic view).
-- Keeps the demo additive and easy to drop without touching existing data.
CREATE SCHEMA IF NOT EXISTS CROCEVIA_DB.PLATFORM_DEMO
  COMMENT = 'Crocevia platform demo: dbt marts, forecasts, governance, FinOps, CoWork assets';

-- Cortex / CoWork models: account is in GCP europe-west3, enable cross-region
-- inference so the agent can reach the full model set.
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- Anchor "today" to the latest sale date (data ends 2025-06-30) so recency logic
-- in marts / forecast / apps behaves as if it were live.
CREATE OR REPLACE VIEW CROCEVIA_DB.PLATFORM_DEMO.V_DEMO_AS_OF AS
SELECT MAX(SALE_DATE) AS AS_OF_DATE
FROM CROCEVIA_DB.BRONZE_DATA.CROCEVIA_SALES_20PCT_STORES;

SELECT * FROM CROCEVIA_DB.PLATFORM_DEMO.V_DEMO_AS_OF;
