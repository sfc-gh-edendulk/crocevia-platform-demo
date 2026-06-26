-- =============================================================================
-- ML 00 - Demand forecast + accuracy metrics objects
-- In-database ML: no data export, no separate ML stack.
-- Run:  snow sql -f notebooks/forecast_objects.sql -c <connection>
-- Idempotent. The notebook crocevia_demand_forecast.ipynb runs the same logic
-- interactively with charts.
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE DATABASE CROCEVIA_DB;
USE SCHEMA PLATFORM_DEMO;
USE WAREHOUSE CR_DEV_WH;

-- 1) Training set: daily units per product category, last 18 months.
--    Materialized as a TABLE (not a view) so the ML engine reads it directly and is
--    not filtered by the row-access policy on MART_SALES_DAILY.
CREATE OR REPLACE TABLE FORECAST_TRAIN_CATEGORY AS
SELECT
    product_category::VARCHAR        AS series_category,
    sale_date::TIMESTAMP_NTZ         AS ts,
    SUM(units)::FLOAT                AS y
FROM MART_SALES_DAILY
WHERE sale_date >= DATEADD('month', -18, (SELECT MAX(sale_date) FROM MART_SALES_DAILY))
  AND product_category <> 'UNKNOWN'
GROUP BY 1, 2;

-- 2) Train a multi-series forecast model (one model, 27 category series).
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST DEMAND_MODEL(
    INPUT_DATA        => SYSTEM$REFERENCE('TABLE', 'FORECAST_TRAIN_CATEGORY'),
    SERIES_COLNAME    => 'SERIES_CATEGORY',
    TIMESTAMP_COLNAME => 'TS',
    TARGET_COLNAME    => 'Y'
);

-- 3) Forecast the next 14 days per category and persist (with prediction intervals).
CALL DEMAND_MODEL!FORECAST(FORECASTING_PERIODS => 14);
CREATE OR REPLACE TABLE FORECAST_DEMAND_CATEGORY AS
SELECT
    series::VARCHAR                  AS product_category,
    ts::DATE                         AS forecast_date,
    ROUND(forecast, 0)               AS forecast_units,
    ROUND(lower_bound, 0)            AS lower_units,
    ROUND(upper_bound, 0)            AS upper_units
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- 3b) Forecast accuracy: persist the model's built-in evaluation metrics (MAPE/SMAPE
--     per series), so the business can trust the numbers.
CALL DEMAND_MODEL!SHOW_EVALUATION_METRICS();
CREATE OR REPLACE TABLE FORECAST_EVAL_METRICS AS
SELECT
    series::VARCHAR          AS product_category,
    error_metric,
    ROUND(metric_value, 3)   AS metric_value
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Quick checks
SELECT COUNT(*) AS forecast_rows, COUNT(DISTINCT product_category) AS series
FROM FORECAST_DEMAND_CATEGORY;
SELECT error_metric, ROUND(AVG(metric_value), 3) AS avg_value
FROM FORECAST_EVAL_METRICS
GROUP BY 1 ORDER BY 1;
