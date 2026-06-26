-- =============================================================================
-- CoWork 01 - Semantic view over the marts (the "talk to your data" layer)
-- Business metrics + FR/EN synonyms so the Cortex Agent answers in natural language.
-- Inherits governance: MART_SALES_DAILY carries the row-access policy, so the agent
-- respects it automatically.
-- Run:  snow sql -f cowork/01_semantic_view.sql -c <connection>
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

CREATE OR REPLACE SEMANTIC VIEW CROCEVIA_DB.PLATFORM_DEMO.CROCEVIA_RETAIL_SV

  TABLES (
    sales AS CROCEVIA_DB.PLATFORM_DEMO.MART_SALES_DAILY
      PRIMARY KEY (sale_date, store_id, product_category)
      WITH SYNONYMS ('ventes', 'sales', 'chiffre d''affaires')
      COMMENT = 'Daily sales by store and product category',
    stores AS CROCEVIA_DB.PLATFORM_DEMO.MART_STORE_PERFORMANCE
      PRIMARY KEY (store_id)
      WITH SYNONYMS ('magasins', 'points de vente', 'stores')
      COMMENT = 'Store directory and performance',
    products AS CROCEVIA_DB.PLATFORM_DEMO.MART_PRODUCT_PERFORMANCE
      PRIMARY KEY (product_id)
      WITH SYNONYMS ('produits', 'articles', 'products')
      COMMENT = 'Product catalogue and performance',
    customers AS CROCEVIA_DB.PLATFORM_DEMO.MART_CUSTOMER_RFM
      PRIMARY KEY (customer_id)
      WITH SYNONYMS ('clients', 'customers')
      COMMENT = 'Customer RFM segmentation'
  )

  RELATIONSHIPS (
    sales_to_stores AS sales (store_id) REFERENCES stores (store_id)
  )

  DIMENSIONS (
    sales.sale_date AS sale_date
      WITH SYNONYMS = ('date', 'jour') COMMENT = 'Sale date',
    sales.category AS product_category
      WITH SYNONYMS = ('categorie', 'rayon', 'famille') COMMENT = 'Product category',
    sales.departement AS departement_code
      WITH SYNONYMS = ('departement', 'region', 'zone') COMMENT = 'French departement code',
    stores.store_name AS store_name
      WITH SYNONYMS = ('nom du magasin', 'enseigne') COMMENT = 'Store name',
    products.product_name AS product_name
      WITH SYNONYMS = ('nom du produit', 'article') COMMENT = 'Product name',
    products.brand AS brand
      WITH SYNONYMS = ('marque') COMMENT = 'Product brand',
    products.prod_category AS product_category
      WITH SYNONYMS = ('famille de produit') COMMENT = 'Category of the product',
    customers.segment AS segment
      WITH SYNONYMS = ('segment client', 'segment rfm') COMMENT = 'RFM customer segment'
  )

  METRICS (
    sales.total_revenue AS SUM(sales.revenue_eur)
      WITH SYNONYMS = ('chiffre d''affaires', 'CA', 'revenue') COMMENT = 'Total revenue in EUR',
    sales.total_units AS SUM(sales.units)
      WITH SYNONYMS = ('unites vendues', 'volume') COMMENT = 'Total units sold',
    sales.total_orders AS SUM(sales.orders)
      WITH SYNONYMS = ('nombre de commandes', 'transactions') COMMENT = 'Total orders',
    sales.avg_basket_eur AS SUM(sales.revenue_eur) / NULLIF(SUM(sales.orders), 0)
      WITH SYNONYMS = ('panier moyen', 'average basket') COMMENT = 'Average basket value in EUR',
    stores.store_count AS COUNT(stores.store_id)
      WITH SYNONYMS = ('nombre de magasins') COMMENT = 'Number of stores',
    products.product_count AS COUNT(products.product_id)
      WITH SYNONYMS = ('nombre de produits') COMMENT = 'Number of products',
    products.avg_rating AS AVG(products.rating)
      WITH SYNONYMS = ('note moyenne') COMMENT = 'Average product rating',
    customers.customer_count AS COUNT(customers.customer_id)
      WITH SYNONYMS = ('nombre de clients') COMMENT = 'Number of customers',
    customers.avg_customer_spend AS AVG(customers.monetary_eur)
      WITH SYNONYMS = ('depense moyenne client') COMMENT = 'Average customer spend in EUR'
  )

  COMMENT = 'Crocevia retail semantic view (sales, stores, products, customers) for Cortex Analyst / CoWork';

-- Grant for agent / analyst use
GRANT REFERENCES, SELECT ON SEMANTIC VIEW CROCEVIA_DB.PLATFORM_DEMO.CROCEVIA_RETAIL_SV TO ROLE CROCEVIA_DATA_STEWARD;

-- Smoke test
SELECT * FROM SEMANTIC_VIEW(
  CROCEVIA_RETAIL_SV
  DIMENSIONS sales.category
  METRICS sales.total_revenue
) ORDER BY total_revenue DESC LIMIT 5;
