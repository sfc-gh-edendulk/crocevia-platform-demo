# Crocevia Platform Demo — Storyline / Déroulé de la démo

**Format:** ~75–90 min live walkthrough. **Audience:** retail data-platform / data
engineering team. **Thread:** one French hypermarket dataset, from raw → governed → AI →
app, all in Snowflake, no data movement.

---

## 0. Cadrage / Framing (5 min)

> *FR :* « Vous avez déjà une plateforme data solide. L'objectif aujourd'hui n'est pas de
> tout remplacer, mais de montrer ce que Snowflake permet de faire — de bout en bout — sur
> **une seule copie de la donnée** : pipelines fiables, gouvernance qui ouvre l'accès au
> lieu de le bloquer, maîtrise des coûts, ML et IA dans la base, et des apps métier. On
> déroule sur un hypermarché fictif, Crocevia. »

Pains we will hit, in order: **pipeline reliability → governance → cost (TCO) →
forecasting → natural-language analytics → business apps.**

---

## 1. Transformation fiable — dbt (12 min)

**Pain:** pipelines spread across tools, slow time-to-data, unclear quality.

- Show `dbt_crocevia/`: sources on `BRONZE_DATA`, staging models, then marts
  (`MART_SALES_DAILY`, `MART_PRODUCT_PERFORMANCE`, `MART_STORE_PERFORMANCE`,
  `MART_CUSTOMER_RFM`).
- Run `EXECUTE DBT PROJECT` (or `dbt build`) live → models + **tests** (not_null, unique,
  relationships) run in Snowflake compute, no external orchestrator.
- Open the generated **docs / lineage**.

> *Message :* « Une transformation versionnée, testée, documentée — qui tourne nativement
> dans Snowflake. Le `time-to-data` passe de jours à minutes, et la qualité est testée à
> chaque exécution. »

**Demo line:** "From 1.3 B raw sales rows to a tested daily mart in one command."

---

## 1b. Lakehouse ouvert — Apache Iceberg sur GCS (8 min)

**Pain:** "we're already on Google Cloud / BigQuery — why move our data, why a second
copy, why risk lock-in?"

- `iceberg/01_iceberg_table.sql`: create the **Snowflake-managed Iceberg** table
  `CUSTOMER_360_ICEBERG` (5.5 M rows) on external volume `UNLMT_ICEBERG_VOL` → Snowflake
  writes **open Apache Iceberg (Parquet + metadata) into a GCS bucket the customer owns**.
- `03_verify.sql`: `SYSTEM$GET_ICEBERG_TABLE_INFORMATION` shows the metadata file path is in
  `gcs://…` — the *same files* BigQuery, Spark or Trino can read. No copy, no migration.
- `iceberg/02_governance_reuse.sql`: attach the **same** `MASK_*` + `RAP_REGION` policies
  from §2 to the open table → governance is decoupled from storage format.

> *Message :* « Vos données restent dans votre Google Cloud Storage, au format ouvert
> Apache Iceberg — lisibles par BigQuery ou Spark. Snowflake ajoute la performance, la
> gouvernance et l'IA *par-dessus*, sans déplacer ni recopier la donnée. Pas de
> verrouillage. »

**Demo line:** "Your data, your bucket, open format — Snowflake's engine and governance on top."

---

## 2. Gouvernance qui ouvre l'accès — tags, masking, row-access (15 min)

**Pain:** governance is often restrictive and slows predictive use cases; PII everywhere;
data scattered across many systems.

- `governance/01_tags.sql`: tag taxonomy (`COST_CENTER`, `DATA_DOMAIN`, `SENSITIVITY`,
  `ENVIRONMENT`) applied to schemas, warehouse and PII columns.
- `02_masking.sql`: **tag-based masking** — tag a column `SENSITIVITY='PII'` and it is
  masked automatically everywhere. Show email/phone/name masked.
- `03_row_access.sql`: a store manager only sees their **region**'s sales; a brand partner
  only sees their **brand**.
- `04_classification.sql`: auto-classification flags PII columns for you.
- Switch to role `CROCEVIA_STORE_MANAGER_DEMO` live → same query, governed result.

> *Message :* « La gouvernance n'est pas un mur : on tague une fois, la politique suit la
> donnée partout — y compris dans l'agent IA et les apps. On ouvre l'accès en sécurité. »

---

## 3. Maîtrise des coûts — FinOps & budgets (12 min)

**Pain:** TCO, "cost per workload", and chargeback by cost-center.

- `finops/01_resource_monitor.sql`: credit quota + auto-suspend guardrails on the WH.
- `02_budget.sql`: a `SNOWFLAKE.CORE.BUDGET` with a spend threshold + notification.
- `03_cost_views.sql`: cost attribution **by tag / cost-center / warehouse / AI service**
  from `ACCOUNT_USAGE` — the chargeback view, in SQL, on live telemetry.

> *Message :* « Le coût est une donnée comme une autre : observable, attribuable au centre
> de coût, et plafonnable. Pas de facture surprise. »

---

## 4. Prévision dans la base — ML notebook (12 min)

**Pain:** merchandise forecasting (replenishment 7–14 days) and price elasticity.

- `notebooks/crocevia_demand_forecast.ipynb`:
  - **Demand forecast** 7–14 days per store × category with Cortex `FORECAST` — no data
    export, no separate ML stack.
  - **Price elasticity** mini-model (units vs price) → which categories are
    promo-sensitive.
- Results written to `PLATFORM_DEMO.FORECAST_*`, reused by the apps.

> *Message :* « La data scientist reste dans Snowflake : la prévision tourne là où vit la
> donnée, et le résultat est immédiatement consommable par le métier. »

---

## 5. Analytique en langage naturel — Snowflake CoWork (15 min) — **le moment fort**

**Pain:** business users stuck on static dashboards, waiting on the data team.

- `cowork/`: a **semantic view** (business metrics + FR/EN synonyms) + **Cortex Search**
  over the product catalogue + a **Cortex Agent**.
- In CoWork, ask live (FR):
  - « Quelles catégories ont le plus progressé sur les 3 derniers mois ? »
  - « Montre les ventes par région et fais un graphique. »
  - « Pourquoi les ventes de surgelés ont-elles augmenté en décembre ? »
- Show traceability (SQL behind the answer) and that it **respects the masking / row-access
  from step 2**.

> *Message :* « Le métier pose la question en français, obtient la réponse, le graphique et
> la requête — gouverné. C'est le dépassement du dashboard statique. »

---

## 6. Apps métier — Streamlit + React (10 min)

**Pain:** self-service for store/category managers; "phygital" cockpit.

- `streamlit/`: bilingual cockpit in Snowsight — store performance, demand forecast,
  segment insights, **FinOps cost panel**.
- `react_app/`: a modern "phygital" exec dashboard hitting the same governed data via the
  Snowflake **SQL API**.

> *Message :* « La même donnée gouvernée, deux expériences : un cockpit interne rapide
> (Streamlit) et une app sur-mesure (React). »

---

## 7. Conclusion & next step (4 min)

- Recap: **one copy of the data**, governed once, served to pipelines, ML, an AI agent and
  apps — with cost under control.
- Next step suggestion: a scoped workshop on the highest-value pain (forecasting *or*
  CoWork-vs-dashboards).

---

### Pain → capability cheat sheet (for Q&A)

| If they ask about… | Point to |
| --- | --- |
| warehouse / cloud cost | FinOps (§3), single copy, per-workload attribution |
| reporting / dashboards | CoWork (§5) + semantic view |
| pipelines / orchestration | dbt (§1), tests, lineage |
| security / RGPD | governance (§2), tag-based masking, classification |
| forecasting / replenishment | ML notebook (§4), Cortex FORECAST |
| data sharing with partners | row-access + secure share pattern (governance §2) |
