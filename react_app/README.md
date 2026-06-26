# Crocevia — Phygital Cockpit (React)

A modern exec dashboard (Vite + React + Recharts) over the **same governed Snowflake data**
as the Streamlit app and the CoWork agent. The browser never touches Snowflake — a thin
Node proxy (`server/index.js`) runs a fixed set of read-only queries via the Snowflake SDK.

```
react_app/
  server/index.js     Node/Express proxy -> Snowflake (creds from .env)
  src/App.jsx         dashboard UI (KPIs, revenue trend, categories, regions, forecast)
  src/styles.css      Snowflake-themed styling
  .env.example        connection template (copy to .env)
```

## Run locally

```bash
cd react_app
cp .env.example .env        # fill in account/user + password OR key-pair
npm install
npm run dev                 # starts the proxy (:8787) AND vite (:5173)
# open http://localhost:5173
```

`.env` is gitignored. Use a read-only role; the proxy only issues SELECTs against
`CROCEVIA_DB.PLATFORM_DEMO`.

## Endpoints (proxy)
`/api/kpis` · `/api/trend` · `/api/categories` · `/api/regions` · `/api/segments` ·
`/api/forecast?category=...`

## Optional: deploy to SPCS
Containerize (`server` + built `dist/`) and deploy to Snowpark Container Services so it runs
inside Snowflake. Out of scope for the live demo (the Streamlit app covers the in-Snowflake
surface); this React app is the "custom UI" story and runs great locally.

## Data
All KPIs come from the dbt marts and the Cortex `FORECAST` output — one governed copy of the
data, surfaced as a bespoke UI.
