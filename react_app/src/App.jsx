import { useEffect, useState } from 'react'
import {
  ResponsiveContainer, AreaChart, Area, LineChart, Line, BarChart, Bar,
  XAxis, YAxis, Tooltip, CartesianGrid,
} from 'recharts'

const fmt = (n) => new Intl.NumberFormat('fr-FR').format(n)
const get = (path) => fetch(`/api/${path}`).then((r) => r.json())

function Kpi({ label, value, suffix }) {
  return (
    <div className="kpi">
      <div className="kpi-label">{label}</div>
      <div className="kpi-value">{value}{suffix ? <span className="kpi-suffix"> {suffix}</span> : null}</div>
    </div>
  )
}

function Card({ title, children }) {
  return (
    <div className="card">
      <h3>{title}</h3>
      {children}
    </div>
  )
}

export default function App() {
  const [kpi, setKpi] = useState(null)
  const [trend, setTrend] = useState([])
  const [cats, setCats] = useState([])
  const [regions, setRegions] = useState([])
  const [fc, setFc] = useState({ category: '', categories: [], rows: [] })
  const [err, setErr] = useState(null)

  useEffect(() => {
    Promise.all([get('kpis'), get('trend'), get('categories'), get('regions'), get('forecast')])
      .then(([k, t, c, r, f]) => {
        if (k.error) throw new Error(k.error)
        setKpi(k[0]); setTrend(t); setCats(c); setRegions(r); setFc(f)
      })
      .catch((e) => setErr(String(e)))
  }, [])

  const pickCategory = (category) => get(`forecast?category=${encodeURIComponent(category)}`).then(setFc)

  return (
    <div className="app">
      <header>
        <div className="brand">Crocevia<span>·</span><em>Phygital Cockpit</em></div>
        <div className="tag">Snowflake · données gouvernées</div>
      </header>

      {err && <div className="error">Proxy non disponible / proxy unavailable — {err}<br />Lancez / run: <code>npm run dev</code> avec un <code>.env</code> valide.</div>}

      <section className="kpis">
        <Kpi label="Chiffre d'affaires" value={kpi ? fmt(kpi.REVENUE) : '—'} suffix="€" />
        <Kpi label="Unités vendues" value={kpi ? fmt(kpi.UNITS) : '—'} />
        <Kpi label="Commandes" value={kpi ? fmt(kpi.ORDERS) : '—'} />
        <Kpi label="Panier moyen" value={kpi ? fmt(kpi.BASKET) : '—'} suffix="€" />
      </section>

      <section className="grid">
        <Card title="Chiffre d'affaires mensuel / Monthly revenue">
          <ResponsiveContainer width="100%" height={240}>
            <AreaChart data={trend}>
              <defs>
                <linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#29b5e8" stopOpacity={0.6} />
                  <stop offset="95%" stopColor="#29b5e8" stopOpacity={0.05} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#eee" />
              <XAxis dataKey="MONTH" tick={{ fontSize: 11 }} />
              <YAxis tick={{ fontSize: 11 }} width={70} />
              <Tooltip formatter={(v) => fmt(v) + ' €'} />
              <Area type="monotone" dataKey="REVENUE" stroke="#29b5e8" fill="url(#g)" />
            </AreaChart>
          </ResponsiveContainer>
        </Card>

        <Card title="Top catégories / Top categories">
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={cats} layout="vertical" margin={{ left: 30 }}>
              <XAxis type="number" tick={{ fontSize: 11 }} />
              <YAxis type="category" dataKey="CATEGORY" width={130} tick={{ fontSize: 10 }} />
              <Tooltip formatter={(v) => fmt(v) + ' €'} />
              <Bar dataKey="REVENUE" fill="#29b5e8" radius={[0, 4, 4, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </Card>

        <Card title="CA par département / Revenue by departement">
          <ResponsiveContainer width="100%" height={240}>
            <BarChart data={regions}>
              <XAxis dataKey="DEP" tick={{ fontSize: 11 }} />
              <YAxis tick={{ fontSize: 11 }} width={70} />
              <Tooltip formatter={(v) => fmt(v) + ' €'} />
              <Bar dataKey="REVENUE" fill="#11567f" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </Card>

        <Card title="Prévision demande 14 j / 14-day demand forecast">
          <select value={fc.category} onChange={(e) => pickCategory(e.target.value)}>
            {fc.categories.map((c) => <option key={c} value={c}>{c}</option>)}
          </select>
          <ResponsiveContainer width="100%" height={200}>
            <LineChart data={fc.rows}>
              <CartesianGrid strokeDasharray="3 3" stroke="#eee" />
              <XAxis dataKey="DATE" tick={{ fontSize: 10 }} />
              <YAxis tick={{ fontSize: 11 }} width={60} />
              <Tooltip />
              <Line type="monotone" dataKey="UPPER" stroke="#cfe9f6" dot={false} />
              <Line type="monotone" dataKey="FORECAST" stroke="#29b5e8" strokeWidth={2} dot={false} />
              <Line type="monotone" dataKey="LOWER" stroke="#cfe9f6" dot={false} />
            </LineChart>
          </ResponsiveContainer>
        </Card>
      </section>

      <footer>Modèle Cortex ML FORECAST · marts dbt · gouvernance Snowflake — une seule copie de la donnée</footer>
    </div>
  )
}
