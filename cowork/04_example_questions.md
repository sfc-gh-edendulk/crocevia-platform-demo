# CoWork / Cortex Agent — demo script

Open **Snowflake CoWork** (or Snowsight » AI & ML » Agents) and select **Crocevia Analyst**.
The agent answers in French by default, leads with a chart, shows the SQL it ran, and
respects governance (row-access by region, PII masking) automatically.

## Persona: *Responsable de catégorie* (Category Manager)

The six sample questions are designed to be asked **in order** — one continuous
investigation that walks the **WHAT → WHERE → WHY → ACT** arc. Each builds on the
previous answer, so the agent shows multi-step reasoning across tools, not isolated Q&A.

---

### 1. WHAT — the trend
**Type:** « Montre le chiffre d'affaires par catégorie sur les 3 derniers mois disponibles, avec un graphique. »
**Tools:** `sales_analyst` → `data_to_chart`
**Expect:** bar/line chart of revenue by category, table below. Recency is anchored to the
latest available data (≤ 2025-06-30), not today.
**Talking point:** "One natural-language question, a governed SQL query and a chart — no
dashboard to build, no SQL to write."

### 2. WHERE — drill into the dip
**Type:** « Pour la catégorie Boissons, quelles régions sous-performent le plus ? »
**Tools:** `sales_analyst` → `data_to_chart`
**Expect:** revenue by `departement`/region for Boissons, weakest first.
**Talking point:** "It kept the context from the previous answer and drilled down — the
row-access policy means a regional manager would only see their own zones here."

### 3. WHY — external context
**Type:** « Y a-t-il des facteurs marché ou météo qui expliquent la baisse des boissons cet été en France ? »
**Tools:** `web_search`
**Expect:** synthesized external context (weather/market), with sources cited.
**Talking point:** "It just combined your governed internal data with live external signals
in the same conversation — a generic chatbot has no access to your governed numbers, and a
BI tool has no access to the open web."

### 4. ACT — build an activation audience
**Type:** « Crée une audience des gros acheteurs (HIGH_SPENDER) sans achat depuis 90 jours pour une relance, destination DV360. »
**Tool:** `create_activation_audience` → `CREATE_ACTIVATION_AUDIENCE`
**Expect:** confirmation with the audience size; a row written to `ACTIVATION_AUDIENCES`.
**Talking point:** "The AI-identified segment just became a real, governed dataset ready to
push to DV360 — the agent didn't just answer, it acted on the platform."

### 5. ACT — email the briefing
**Type:** « Envoie un brief par email à mon.email@exemple.com avec le constat et les actions recommandées. »
**Tool:** `send_briefing_email` → `SEND_BRIEFING_EMAIL`
**Expect:** an HTML briefing emailed via the notification integration.
**Note:** the recipient must be a **verified user** in the account, otherwise the agent
reports the error gracefully. Use your own verified address for the live demo.
**Talking point:** "Board-ready briefing, sent from a chat, inside Snowflake."

### 6. ACT — stand up monitoring
**Type:** « Mets en place une alerte si le CA d'une catégorie chute de plus de 15% d'une semaine sur l'autre. »
**Tool:** `create_revenue_alert` → `CREATE_REVENUE_ALERT`
**Expect:** a **suspended** weekly alert is created; the agent returns the `RESUME` command.
**Talking point:** "Not just an answer today — proactive monitoring that emails the team
every Monday if the dip returns. All inside Snowflake, on the same governed data."

---

## Quick English variants (WHAT/WHERE/WHY)
1. "Show revenue by product category over the last 3 available months, as a chart."
2. "For the Beverages category, which regions are underperforming the most?"
3. "Are there market or weather factors that explain the summer dip in beverages in France?"

## Talking points (overall)
- **Cross-source + action in one turn:** Analyst (governed SQL) + Web search (external) +
  write-back (audience/email/alert) — capabilities no single-source BI tool or generic LLM
  combines against governed enterprise data.
- **Governed everywhere:** the same masking + row-access policies from `governance/` apply
  to the agent's answers — switch to `CROCEVIA_STORE_MANAGER_DEMO` in Snowsight to prove it.
- **One model, many surfaces:** same semantic view powers the agent, the dbt marts and the apps.

> The action tools (`create_activation_audience`, `send_briefing_email`, `create_revenue_alert`)
> fire **only** when explicitly requested. Deploy them with `cowork/05_actions.sql`.
