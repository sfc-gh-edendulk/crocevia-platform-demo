# Crocevia Platform Demo — Snowflake "Art of the Possible"

A single, coherent demo that walks a retail data-platform team through what Snowflake
delivers end-to-end on **one French hypermarket dataset (Crocevia, fictional)** — from raw
data to governed, AI-ready, self-service insight.

> **Who it's for:** a retail data-platform / data-engineering team that already runs a
> capable cloud data stack and wants to see, end-to-end, what Snowflake adds on **one copy
> of the data**: reliable pipelines, governance that enables rather than blocks, cost
> control (TCO), in-database ML forecasting, natural-language analytics that replaces
> static dashboards, and business-facing apps — without moving data between systems.

## What's inside (each piece maps to a real platform pain)

| Layer | Folder | Snowflake capability | Pain it answers |
| --- | --- | --- | --- |
| Transformation | `dbt_crocevia/` | dbt project on Snowflake | reliable pipelines, data quality, time-to-data, domain onboarding |
| Governance | `governance/` | tags, masking, row-access, classification | strong-but-not-restrictive governance, PII, scattered systems |
| FinOps | `finops/` | budgets, resource monitors, cost attribution | TCO, cost-per-workload, cost-center chargeback |
| ML | `notebooks/` | Cortex `FORECAST` + price elasticity | merchandise forecasting (7–14d), price elasticity |
| AI analytics | `cowork/` | Snowflake CoWork (Cortex Agent + semantic view + search) | "talk to your data" vs static dashboards |
| Apps | `streamlit/`, `react_app/` | Streamlit-in-Snowflake + React via SQL API | self-service, phygital cockpit |

## Data foundation (`CROCEVIA_DB`)

| Table | Rows | Notes |
| --- | --- | --- |
| `BRONZE_DATA.CROCEVIA_SALES_20PCT_STORES` | 1.3 B | sales 2022-01-01 → 2025-06-30 |
| `BRONZE_DATA.CROCEVIA_CRM` | 6.2 M | customers (PII: email, phone, name, DOB) |
| `BRONZE_DATA.CROCEVIA_PRODUCTS` | 3.1 k | 27 categories / 542 subcategories / 770 brands |
| `BRONZE_DATA.CROCEVIA_STORES` | 1.3 k | French stores |
| `GOLD_ANALYTICS.C360_*` | up to 92 M | existing RFM segments / lookalikes |

All demo-built objects land in the additive schema **`CROCEVIA_DB.PLATFORM_DEMO`**.

> Data is **synthetic**. Crocevia is a fictional retailer used purely to illustrate
> Snowflake capabilities.

## Run order

See [`deploy/RUNBOOK.md`](deploy/RUNBOOK.md). Short version:

```
deploy/00_context.sql
dbt_crocevia/         (EXECUTE DBT PROJECT, or local `dbt build`)
governance/01_tags.sql → 02_masking.sql → 03_row_access.sql → 04_classification.sql
finops/01_resource_monitor.sql → 02_budget.sql → 03_cost_views.sql
notebooks/crocevia_demand_forecast.ipynb
cowork/01_semantic_view.sql → 02_search_service.sql → 03_agent.sql
streamlit/deploy_streamlit.sql
react_app/  (npm install && npm run dev)
```

## Language

Bilingual: **French** for user-facing labels, app UI and the demo narrative; **English**
for code comments and developer docs.
