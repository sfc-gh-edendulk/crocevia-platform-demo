-- =============================================================================
-- CoWork 03 - Cortex Agent (surfaces in Snowflake CoWork / Intelligence)
-- -----------------------------------------------------------------------------
-- Persona: "Responsable de categorie" (Category Manager). The sample questions
-- form ONE realistic, sequential investigation:
--   WHAT  -> category revenue trend (Analyst + chart)
--   WHERE -> which regions drive a dip (Analyst drill-down)
--   WHY   -> market / weather context (Web search)
--   ACT   -> build an activation audience, email a briefing, set a revenue alert
-- Tools: sales_analyst, product_search, data_to_chart, web_search + 3 action tools.
-- Run AFTER cowork/01, 02 and cowork/05_actions.sql.
-- Run:  snow sql -f cowork/03_agent.sql -c <connection>
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- Home for CoWork agents
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS;

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.CROCEVIA_ANALYST
  WITH PROFILE = '{"display_name": "Crocevia Analyst"}'
  COMMENT = 'Crocevia retail analyst: sales, stores, products, customers + actions (FR/EN)'
FROM SPECIFICATION $$
models:
  orchestration: auto

orchestration:
  budget:
    seconds: 60
    tokens: 16000

instructions:
  response: |
    Reponds en francais par defaut; passe a l'anglais si l'utilisateur ecrit en anglais.
    Sois concis et chiffre. Formate les montants en euros avec separateur de milliers (ex: 1 240 500 EUR).
    Quand tu montres une tendance, un classement ou une comparaison, fais d'ABORD un graphique
    (data_to_chart) puis place le tableau en dessous. Indique brievement quel outil tu as utilise.
    Les donnees synthetiques s'arretent au 30/06/2025: pour "recent", "3 derniers mois", "cet ete",
    raisonne par rapport a la DERNIERE date disponible (MAX(sale_date)), jamais par rapport a aujourd'hui.
    La gouvernance s'applique automatiquement (masking PII, row-access par region): ne contourne jamais
    ces politiques et ne revele pas de PII en clair.
  orchestration: |
    Outils de DONNEES:
    - sales_analyst: toute question de CA, unites, commandes, panier moyen, par categorie, magasin,
      region/departement, date; metriques produits/clients. Outil par defaut pour les chiffres.
    - product_search: pour resoudre un nom de produit, une marque ou une categorie mentionnee.
    - web_search: pour du contexte EXTERNE (tendances marche, meteo, actualite, concurrence) afin
      d'expliquer un constat. Cite les sources.
    - data_to_chart: pour visualiser des resultats numeriques.
    Outils d'ACTION (uniquement si l'utilisateur le demande explicitement; confirme et resume ce qui
    a ete fait, ne les declenche jamais de ta propre initiative):
    - create_activation_audience: cree une audience activable depuis le mart RFM. Fournis segment
      (ex: HIGH_SPENDER, LOYAL_HIGH_VALUE, AT_RISK), min_recency_days (ex: 90) et destination (ex: DV360).
    - send_briefing_email: envoie un brief HTML. Le destinataire DOIT etre un utilisateur verifie du
      compte. Construis un corps HTML court: synthese, tableau de chiffres, actions recommandees.
    - create_revenue_alert: cree une alerte hebdomadaire (suspendue) sur la chute de CA d'une categorie.
  sample_questions:
    - question: "Montre le chiffre d'affaires par categorie sur les 3 derniers mois disponibles, avec un graphique."
    - question: "Pour la categorie Boissons, quelles regions sous-performent le plus ?"
    - question: "Y a-t-il des facteurs marche ou meteo qui expliquent la baisse des boissons cet ete en France ?"
    - question: "Cree une audience des gros acheteurs (HIGH_SPENDER) sans achat depuis 90 jours pour une relance, destination DV360."
    - question: "Envoie un brief par email a mon.email@exemple.com avec le constat et les actions recommandees."
    - question: "Mets en place une alerte si le CA d'une categorie chute de plus de 15% d'une semaine sur l'autre."

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "sales_analyst"
      description: "Crocevia sales semantic model: revenue, units, orders, average basket, by category, store, region/departement, date; plus store, product and customer (RFM) metrics. Use for any numeric/metric question."
  - tool_spec:
      type: "cortex_search"
      name: "product_search"
      description: "Search the product catalogue to resolve product names, brands and categories before querying."
  - tool_spec:
      type: "data_to_chart"
      name: "data_to_chart"
      description: "Generate a chart from query results (bars for category comparison, lines for trends)."
  - tool_spec:
      type: "web_search"
      name: "web_search"
      description: "Search the public web for external context (market trends, weather, news, competition) to explain an internal finding."
  - tool_spec:
      type: "generic"
      name: "create_activation_audience"
      description: "ACTION: create an activation audience from the customer RFM data and record it for downstream activation (CDP/DV360/CRM). Use only when the user explicitly asks to build or activate an audience."
      input_schema:
        type: object
        properties:
          audience_name:
            type: string
            description: "Short business name for the audience, e.g. 'Relance gros acheteurs juin 2026'."
          segment:
            type: string
            description: "RFM segment to target: HIGH_SPENDER, LOYAL_HIGH_VALUE, STANDARD, AT_RISK, NEW_CUSTOMER, or empty for all."
          min_recency_days:
            type: number
            description: "Minimum days since last purchase (e.g. 90 for lapsed customers)."
          destination:
            type: string
            description: "Activation destination, e.g. DV360, CRM, CDP."
        required: ["audience_name", "segment", "min_recency_days"]
  - tool_spec:
      type: "generic"
      name: "send_briefing_email"
      description: "ACTION: email a formatted HTML briefing to a VERIFIED account user. Use only when the user explicitly asks to send a report/briefing by email."
      input_schema:
        type: object
        properties:
          recipient:
            type: string
            description: "Recipient email; must be a verified user in this Snowflake account."
          subject:
            type: string
            description: "Email subject line."
          html_body:
            type: string
            description: "HTML body: executive summary, key figures table, recommended actions."
        required: ["recipient", "subject", "html_body"]
  - tool_spec:
      type: "generic"
      name: "create_revenue_alert"
      description: "ACTION: create a suspended weekly alert that emails when a category's revenue drops more than a given percent week-over-week. Use only when the user explicitly asks to set up monitoring/an alert."
      input_schema:
        type: object
        properties:
          category:
            type: string
            description: "Product category to monitor, e.g. Boissons."
          drop_pct:
            type: number
            description: "Week-over-week drop threshold in percent, e.g. 15."
          recipient:
            type: string
            description: "Email to notify; must be a verified user in this account."
        required: ["category", "drop_pct", "recipient"]

tool_resources:
  sales_analyst:
    semantic_view: "CROCEVIA_DB.PLATFORM_DEMO.CROCEVIA_RETAIL_SV"
  product_search:
    name: "CROCEVIA_DB.PLATFORM_DEMO.PRODUCT_SEARCH"
    id_column: "product_id"
    title_column: "product_name"
    max_results: "10"
  web_search:
    max_results: 10
  create_activation_audience:
    identifier: "CROCEVIA_DB.PLATFORM_DEMO.CREATE_ACTIVATION_AUDIENCE"
    type: "procedure"
    execution_environment:
      type: "warehouse"
      warehouse: "CR_DEV_WH"
  send_briefing_email:
    identifier: "CROCEVIA_DB.PLATFORM_DEMO.SEND_BRIEFING_EMAIL"
    type: "procedure"
    execution_environment:
      type: "warehouse"
      warehouse: "CR_DEV_WH"
  create_revenue_alert:
    identifier: "CROCEVIA_DB.PLATFORM_DEMO.CREATE_REVENUE_ALERT"
    type: "procedure"
    execution_environment:
      type: "warehouse"
      warehouse: "CR_DEV_WH"
$$;

SHOW AGENTS LIKE 'CROCEVIA_ANALYST' IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;
