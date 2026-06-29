-- =============================================================================
-- Iceberg 01 - Snowflake-managed Apache Iceberg table on YOUR Google Cloud Storage
-- -----------------------------------------------------------------------------
-- Story for a Google Cloud / BigQuery shop: your data does NOT have to move into
-- a proprietary format to get Snowflake. Snowflake writes this table as open
-- Apache Iceberg (Parquet data + Iceberg metadata) directly into a GCS bucket you
-- own. Any engine that speaks Iceberg (BigQuery, Spark, Trino, Flink, DuckDB...)
-- can read the exact same files. No lock-in, no copy, one source of truth -- with
-- Snowflake performance, governance and ML on top.
--
-- Uses the existing, already-verified external volume UNLMT_ICEBERG_VOL
--   -> gcs://crocevia_rawdata/unlmt_dcr/ (region EU).
-- Idempotent. Run as ACCOUNTADMIN after deploy/00_context.sql.
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

-- Sanity check: confirm the external volume can read/write/list/delete in GCS.
SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('UNLMT_ICEBERG_VOL') AS volume_check;

-- Snowflake-managed Iceberg table (CATALOG='SNOWFLAKE'): Snowflake owns the
-- Iceberg metadata and writes open Parquet to the BASE_LOCATION below, inside
-- the GCS bucket. DROP first so re-runs cannot collide with an existing layout.
DROP ICEBERG TABLE IF EXISTS CROCEVIA_DB.PLATFORM_DEMO.CUSTOMER_360_ICEBERG;

CREATE ICEBERG TABLE CROCEVIA_DB.PLATFORM_DEMO.CUSTOMER_360_ICEBERG (
  CUSTOMER_ID       STRING,
  FIRST_NAME        STRING,
  LAST_NAME         STRING,
  EMAIL             STRING,
  PHONE             STRING,
  POSTAL_CODE       STRING,
  DEPARTEMENT_CODE  STRING,   -- first 2 digits of FR postal code (row-access key)
  BIRTH_DATE        DATE,
  GENDER            STRING,
  LATITUDE          FLOAT,
  LONGITUDE         FLOAT
)
  CATALOG = 'SNOWFLAKE'
  EXTERNAL_VOLUME = 'UNLMT_ICEBERG_VOL'
  BASE_LOCATION = 'crocevia_platform_demo/customer_360/'
  COMMENT = 'Customer 360 as open Apache Iceberg in GCS. Demonstrates open-format, no-lock-in storage with Snowflake governance applied (see iceberg/02).';

-- Load from the existing CRM source. DEPARTEMENT_CODE is derived from the French
-- postal code so the same regional row-access policy applies here too.
INSERT INTO CROCEVIA_DB.PLATFORM_DEMO.CUSTOMER_360_ICEBERG
SELECT
  CUSTOMER_ID,
  FIRST_NAME,
  LAST_NAME,
  EMAIL,
  PHONE,
  POSTAL_CODE,
  LEFT(POSTAL_CODE, 2)        AS DEPARTEMENT_CODE,
  BIRTH_DATE,
  GENDER,
  LATITUDE,
  LONGITUDE
FROM CROCEVIA_DB.BRONZE_DATA.CROCEVIA_CRM
WHERE POSTAL_CODE IS NOT NULL;

-- Confirm it really is an Iceberg table and see the row count.
SHOW ICEBERG TABLES LIKE 'CUSTOMER_360_ICEBERG' IN SCHEMA CROCEVIA_DB.PLATFORM_DEMO;
SELECT COUNT(*) AS rows_loaded FROM CROCEVIA_DB.PLATFORM_DEMO.CUSTOMER_360_ICEBERG;
