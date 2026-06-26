# CoWork / Cortex Agent — example questions

Open **Snowflake CoWork** (or Snowsight » AI & ML » Agents) and select **Crocevia Analyst**.
The agent answers in French by default, returns the SQL it ran, and draws charts. It
respects the row-access policy on `MART_SALES_DAILY` (a store-manager role sees only its region).

## Questions de démo (FR)
1. « Quelles catégories ont le plus progressé sur les 3 derniers mois ? »
2. « Montre le chiffre d'affaires par région et fais un graphique. »
3. « Quels sont les 10 magasins avec le panier moyen le plus élevé ? »
4. « Combien de clients dans le segment LOYAL_HIGH_VALUE et quelle est leur dépense moyenne ? »
5. « Quelles sont les ventes en unités pour la catégorie Boissons par mois en 2025 ? »
6. « Trouve les produits de la marque Danone et leur chiffre d'affaires. » *(uses product search)*

## Demo questions (EN)
1. "Which product categories grew the most in the last 3 months?"
2. "Show revenue by region as a chart."
3. "Top 10 stores by average basket value."
4. "How many customers are in the HIGH_SPENDER segment and what's their average spend?"

## Talking points
- The agent picks the right tool (Analyst for metrics, Search for product/brand lookup) and
  explains the chart it drew — traceable, governed, no SQL needed by the business user.
- Same governed data as the dbt marts and the apps: one model, many surfaces.
