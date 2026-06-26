# dbt project — Crocevia marts

Transforms raw `BRONZE_DATA` tables into tested, documented marts in
`CROCEVIA_DB.PLATFORM_DEMO`.

```
models/
  staging/   stg_sales, stg_products, stg_stores, stg_customers   (views)
  marts/     mart_sales_daily, mart_product_performance,
             mart_store_performance, mart_customer_rfm            (tables)
```

Marts cover the **last 24 months** of sales (var `sales_lookback_months`), so live
rebuilds stay fast and cheap.

## Run it — native Snowflake dbt project (recommended for the demo)

Files are deployed to a stage and run with Snowflake-managed dbt (no local install):

```sql
-- one-time: stage the project, then create + execute
CREATE OR REPLACE DBT PROJECT CROCEVIA_DB.PLATFORM_DEMO.CROCEVIA_DBT
  FROM '@CROCEVIA_DB.PLATFORM_DEMO.DBT_STAGE/dbt_crocevia';

EXECUTE DBT PROJECT CROCEVIA_DB.PLATFORM_DEMO.CROCEVIA_DBT ARGS='build';
```

See [`../deploy/RUNBOOK.md`](../deploy/RUNBOOK.md) for the staged deploy commands.

## Run it — local dbt

```bash
cp profiles.yml.example ~/.dbt/profiles.yml   # edit creds
export SNOWFLAKE_ACCOUNT=... SNOWFLAKE_USER=...
dbt deps && dbt build          # runs models + tests
dbt docs generate && dbt docs serve
```

## Tests
not_null / unique on all keys, `accepted_values` on `mart_customer_rfm.segment`. Run with
`dbt test` or as part of `dbt build`.
