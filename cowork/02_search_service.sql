-- =============================================================================
-- CoWork 02 - Cortex Search service over the product catalogue (unstructured-ish)
-- Lets the agent resolve fuzzy product / brand names in questions.
-- Run:  snow sql -f cowork/02_search_service.sql -c <connection>
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

CREATE OR REPLACE CORTEX SEARCH SERVICE CROCEVIA_DB.PLATFORM_DEMO.PRODUCT_SEARCH
  ON product_name
  ATTRIBUTES product_category, brand, product_subcategory
  WAREHOUSE = CR_DEV_WH
  TARGET_LAG = '1 day'
  AS (
    SELECT
      product_id,
      product_name,
      COALESCE(brand, 'N/A')        AS brand,
      product_category,
      product_subcategory
    FROM CROCEVIA_DB.PLATFORM_DEMO.MART_PRODUCT_PERFORMANCE
  );

SHOW CORTEX SEARCH SERVICES LIKE 'PRODUCT_SEARCH' IN SCHEMA CROCEVIA_DB.PLATFORM_DEMO;
