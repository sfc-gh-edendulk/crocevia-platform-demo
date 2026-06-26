// Thin Node proxy: runs a fixed set of read-only queries against Snowflake using the
// Node SDK and exposes them as JSON. Credentials stay server-side (.env). The React
// client only ever calls /api/* — it never sees Snowflake credentials.
import express from 'express'
import cors from 'cors'
import snowflake from 'snowflake-sdk'
import dotenv from 'dotenv'
import fs from 'fs'

dotenv.config()
const app = express()
app.use(cors())

const SCHEMA = `${process.env.SNOWFLAKE_DATABASE}.${process.env.SNOWFLAKE_SCHEMA}`

function connectionOptions() {
  const base = {
    account: process.env.SNOWFLAKE_ACCOUNT,
    username: process.env.SNOWFLAKE_USER,
    role: process.env.SNOWFLAKE_ROLE,
    warehouse: process.env.SNOWFLAKE_WAREHOUSE,
    database: process.env.SNOWFLAKE_DATABASE,
    schema: process.env.SNOWFLAKE_SCHEMA,
  }
  if (process.env.SNOWFLAKE_PRIVATE_KEY_PATH) {
    return {
      ...base,
      authenticator: 'SNOWFLAKE_JWT',
      privateKey: fs.readFileSync(process.env.SNOWFLAKE_PRIVATE_KEY_PATH, 'utf8'),
      privateKeyPass: process.env.SNOWFLAKE_PRIVATE_KEY_PASSPHRASE || undefined,
    }
  }
  return { ...base, password: process.env.SNOWFLAKE_PASSWORD }
}

const conn = snowflake.createConnection(connectionOptions())
const ready = new Promise((resolve, reject) =>
  conn.connect((err) => (err ? reject(err) : resolve()))
)

function run(sql) {
  return new Promise((resolve, reject) =>
    conn.execute({ sqlText: sql, complete: (err, _s, rows) => (err ? reject(err) : resolve(rows)) })
  )
}

// Fixed, parameter-free queries (no user input -> no injection surface).
const QUERIES = {
  kpis: `SELECT ROUND(SUM(revenue_eur)) AS revenue, SUM(units) AS units,
                SUM(orders) AS orders, ROUND(SUM(revenue_eur)/NULLIF(SUM(orders),0),2) AS basket
         FROM ${SCHEMA}.MART_SALES_DAILY`,
  trend: `SELECT TO_CHAR(DATE_TRUNC('month', sale_date),'YYYY-MM') AS month, ROUND(SUM(revenue_eur)) AS revenue
          FROM ${SCHEMA}.MART_SALES_DAILY
          WHERE sale_date >= DATEADD('month',-24,(SELECT MAX(sale_date) FROM ${SCHEMA}.MART_SALES_DAILY))
          GROUP BY 1 ORDER BY 1`,
  categories: `SELECT product_category AS category, ROUND(SUM(revenue_eur)) AS revenue
               FROM ${SCHEMA}.MART_SALES_DAILY WHERE product_category <> 'UNKNOWN'
               GROUP BY 1 ORDER BY revenue DESC LIMIT 10`,
  regions: `SELECT departement_code AS dep, ROUND(SUM(revenue_eur)) AS revenue
            FROM ${SCHEMA}.MART_STORE_PERFORMANCE GROUP BY 1 ORDER BY revenue DESC LIMIT 12`,
  segments: `SELECT segment, COUNT(*) AS customers FROM ${SCHEMA}.MART_CUSTOMER_RFM GROUP BY 1 ORDER BY customers DESC`,
}

for (const [name, sql] of Object.entries(QUERIES)) {
  app.get(`/api/${name}`, async (_req, res) => {
    try {
      await ready
      res.json(await run(sql))
    } catch (e) {
      res.status(500).json({ error: String(e) })
    }
  })
}

// Forecast for one category (category validated against the known list).
app.get('/api/forecast', async (req, res) => {
  try {
    await ready
    const cats = (await run(`SELECT DISTINCT product_category AS c FROM ${SCHEMA}.FORECAST_DEMAND_CATEGORY`)).map(r => r.C)
    const cat = cats.includes(req.query.category) ? req.query.category : cats[0]
    const rows = await run(
      `SELECT TO_CHAR(forecast_date,'YYYY-MM-DD') AS date, forecast_units AS forecast,
              lower_units AS lower, upper_units AS upper
       FROM ${SCHEMA}.FORECAST_DEMAND_CATEGORY
       WHERE product_category = '${cat.replace(/'/g, "''")}' ORDER BY forecast_date`)
    res.json({ category: cat, categories: cats, rows })
  } catch (e) {
    res.status(500).json({ error: String(e) })
  }
})

const PORT = process.env.PORT || 8787
app.listen(PORT, () => console.log(`Crocevia proxy on http://localhost:${PORT}`))
