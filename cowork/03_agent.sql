-- =============================================================================
-- CoWork 03 - Cortex Agent (surfaces in Snowflake CoWork / Intelligence)
-- Wires the semantic view (Analyst), product search, and chart generation.
-- Created in SNOWFLAKE_INTELLIGENCE.AGENTS so it appears in the CoWork UI.
-- Run:  snow sql -f cowork/03_agent.sql -c <connection>
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- Home for CoWork agents
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE;
CREATE SCHEMA IF NOT EXISTS SNOWFLAKE_INTELLIGENCE.AGENTS;

CREATE OR REPLACE AGENT SNOWFLAKE_INTELLIGENCE.AGENTS.CROCEVIA_ANALYST
  WITH PROFILE = '{"display_name": "Crocevia Analyst"}'
  COMMENT = 'Crocevia retail analyst: sales, stores, products, customers (FR/EN)'
  FROM SPECIFICATION $$
models:
  orchestration: auto

instructions:
  response: "Reponds en francais par defaut, de maniere concise et chiffree. Answer in French by default; switch to English if the user writes in English."
  orchestration: "Use sales_analyst for any question about revenue, units, orders, basket, categories, stores or regions. Use product_search to resolve a product name, brand or category mentioned by the user. Prefer a chart when showing trends or comparisons."
  sample_questions:
    - question: "Quelles categories ont le plus progresse sur les 3 derniers mois ?"
    - question: "Montre le chiffre d'affaires par region et fais un graphique."
    - question: "Quels sont les 10 magasins avec le panier moyen le plus eleve ?"

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "sales_analyst"
      description: "Crocevia sales semantic model: revenue, units, orders, average basket, by category, store, region, date; plus store, product and customer metrics."
  - tool_spec:
      type: "cortex_search"
      name: "product_search"
      description: "Search the product catalogue to resolve product names, brands and categories."
  - tool_spec:
      type: "data_to_chart"
      name: "data_to_chart"
      description: "Generate a chart from query results."

tool_resources:
  sales_analyst:
    semantic_view: "CROCEVIA_DB.PLATFORM_DEMO.CROCEVIA_RETAIL_SV"
  product_search:
    name: "CROCEVIA_DB.PLATFORM_DEMO.PRODUCT_SEARCH"
    id_column: "product_id"
    title_column: "product_name"
$$;

SHOW AGENTS LIKE 'CROCEVIA_ANALYST' IN SCHEMA SNOWFLAKE_INTELLIGENCE.AGENTS;
