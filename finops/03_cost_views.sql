-- =============================================================================
-- FinOps 03 - Cost attribution views
-- Cost is just another dataset: attribute credits by warehouse, by COST_CENTER tag,
-- and by AI service. These views feed the Streamlit + React cost panels.
-- Idempotent. Run as ACCOUNTADMIN. (ACCOUNT_USAGE has up to a few hours latency.)
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

-- Daily credits per warehouse (last 180 days).
CREATE OR REPLACE VIEW V_FINOPS_WAREHOUSE_DAILY AS
SELECT
    TO_DATE(start_time)                 AS usage_date,
    warehouse_name,
    ROUND(SUM(credits_used), 2)         AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD('day', -180, CURRENT_TIMESTAMP())
GROUP BY 1, 2;

-- Credits attributed to a cost-center via the COST_CENTER tag on warehouses.
CREATE OR REPLACE VIEW V_FINOPS_BY_COST_CENTER AS
WITH wh_cc AS (
    SELECT object_name AS warehouse_name, tag_value AS cost_center
    FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
    WHERE tag_name = 'COST_CENTER' AND domain = 'WAREHOUSE'
)
SELECT
    TO_DATE(m.start_time)               AS usage_date,
    COALESCE(cc.cost_center, 'UNALLOCATED') AS cost_center,
    ROUND(SUM(m.credits_used), 2)       AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY m
LEFT JOIN wh_cc cc ON m.warehouse_name = cc.warehouse_name
WHERE m.start_time >= DATEADD('day', -180, CURRENT_TIMESTAMP())
GROUP BY 1, 2;

-- Credits by service type (COMPUTE, AI_SERVICES, STORAGE-equivalent, etc.).
CREATE OR REPLACE VIEW V_FINOPS_BY_SERVICE AS
SELECT
    usage_date,
    service_type,
    ROUND(SUM(credits_used), 2)         AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE usage_date >= DATEADD('day', -180, CURRENT_DATE())
GROUP BY 1, 2;

-- Headline KPIs for the last 30 days (used by app metric cards).
CREATE OR REPLACE VIEW V_FINOPS_SUMMARY_30D AS
SELECT
    ROUND(SUM(credits_used), 1)                                                   AS total_credits_30d,
    ROUND(SUM(IFF(service_type = 'AI_SERVICES', credits_used, 0)), 1)             AS ai_credits_30d,
    ROUND(SUM(IFF(service_type = 'WAREHOUSE_METERING', credits_used, 0)), 1)      AS compute_credits_30d
FROM SNOWFLAKE.ACCOUNT_USAGE.METERING_DAILY_HISTORY
WHERE usage_date >= DATEADD('day', -30, CURRENT_DATE());

-- Grant to demo roles + apps.
GRANT SELECT ON VIEW V_FINOPS_WAREHOUSE_DAILY  TO ROLE CROCEVIA_DATA_STEWARD;
GRANT SELECT ON VIEW V_FINOPS_BY_COST_CENTER   TO ROLE CROCEVIA_DATA_STEWARD;
GRANT SELECT ON VIEW V_FINOPS_BY_SERVICE       TO ROLE CROCEVIA_DATA_STEWARD;
GRANT SELECT ON VIEW V_FINOPS_SUMMARY_30D      TO ROLE CROCEVIA_DATA_STEWARD;

SELECT * FROM V_FINOPS_SUMMARY_30D;
