# Deploy Runbook — Crocevia Platform Demo

All steps are idempotent (`CREATE OR REPLACE` / `IF NOT EXISTS`). Deploy with a role that
can create objects in `CROCEVIA_DB` and read `SNOWFLAKE.ACCOUNT_USAGE` (e.g. `ACCOUNTADMIN`).
Prereq: `CROCEVIA_DB` exists with the `BRONZE_DATA` tables (sales, products, stores, CRM).

## Order

| # | Step | How |
| --- | --- | --- |
| 0 | Context + cross-region | run `deploy/00_context.sql` |
| 1 | dbt marts | `EXECUTE DBT PROJECT` (see `dbt_crocevia/README.md`) or local `dbt build` |
| 2 | Governance | run `governance/01_tags.sql` → `02_masking.sql` → `03_row_access.sql` → `04_classification.sql` |
| 2b | Iceberg (open lakehouse) | run `iceberg/01_iceberg_table.sql` → `02_governance_reuse.sql` → `03_verify.sql` (needs an external volume; uses `UNLMT_ICEBERG_VOL`) |
| 3 | FinOps | run `finops/01_resource_monitor.sql` → `02_budget.sql` → `03_cost_views.sql` |
| 4 | ML forecast | open `notebooks/crocevia_demand_forecast.ipynb` in Snowsight, Run all |
| 5 | CoWork | run `cowork/01_semantic_view.sql` → `02_search_service.sql` → `03_agent.sql` |
| 6 | Streamlit | run `streamlit/deploy_streamlit.sql` (uploads app to a stage + creates STREAMLIT) |
| 7 | React | `cd react_app && cp .env.example .env && npm install && npm run dev` |

## Notes
- All built objects live in `CROCEVIA_DB.PLATFORM_DEMO` (additive; drop the schema to clean up).
- `00_context.sql` enables `CORTEX_ENABLED_CROSS_REGION='ANY_REGION'` (needed for CoWork on GCP eu-west3).
- Recency is anchored to `PLATFORM_DEMO.V_DEMO_AS_OF` (max sale date), not `CURRENT_DATE`,
  because the synthetic sales end 2025-06-30.
- Deployment uses Snowflake-native tooling only (SQL + `PUT` to stages). No `snow` CLI required.
- Iceberg step writes open Apache Iceberg into the GCS bucket behind external volume
  `UNLMT_ICEBERG_VOL`. Swap in your own external volume name if different; verify it first
  with `SELECT SYSTEM$VERIFY_EXTERNAL_VOLUME('<vol>');`.

## Teardown
```sql
DROP SCHEMA IF EXISTS CROCEVIA_DB.PLATFORM_DEMO CASCADE;
-- (DROP SCHEMA ... CASCADE also drops CUSTOMER_360_ICEBERG; its data files in GCS are removed too)
-- plus: DROP the demo role, masking/row-access policies, budget, resource monitor, agent
--       (see the header of each script for the exact object names).
```
