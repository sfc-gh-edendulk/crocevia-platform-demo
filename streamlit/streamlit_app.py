"""
Crocevia Platform Cockpit - Streamlit in Snowflake (bilingual FR/EN).
Reads governed marts + forecast + FinOps views from CROCEVIA_DB.PLATFORM_DEMO.
Single-file app. Deploy with deploy_streamlit.sql.
"""
import streamlit as st
import pandas as pd
import altair as alt
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Crocevia Platform Cockpit", layout="wide")
session = get_active_session()
SCHEMA = "CROCEVIA_DB.PLATFORM_DEMO"

# ---- bilingual labels -------------------------------------------------------
T = {
    "fr": {
        "title": "Cockpit Plateforme Crocevia",
        "subtitle": "Ventes, prevision, clients et couts - sur donnees gouvernees",
        "overview": "Vue d'ensemble", "stores": "Magasins", "forecast": "Prevision",
        "segments": "Clients", "finops": "Couts (FinOps)",
        "revenue": "Chiffre d'affaires (EUR)", "units": "Unites vendues",
        "orders": "Commandes", "basket": "Panier moyen (EUR)",
        "rev_trend": "Tendance du chiffre d'affaires", "top_cat": "Top categories",
        "top_stores": "Top magasins par chiffre d'affaires", "by_region": "CA par departement",
        "pick_cat": "Choisir une categorie", "fc_title": "Prevision de la demande a 14 jours",
        "seg_title": "Clients par segment RFM", "avg_spend": "Depense moyenne (EUR)",
        "credits_30d": "Credits (30 j)", "ai_credits": "Credits IA (30 j)",
        "compute_credits": "Credits calcul (30 j)", "cost_by_cc": "Couts par centre de cout",
        "cost_by_svc": "Couts par service",
    },
    "en": {
        "title": "Crocevia Platform Cockpit",
        "subtitle": "Sales, forecast, customers and cost - on governed data",
        "overview": "Overview", "stores": "Stores", "forecast": "Forecast",
        "segments": "Customers", "finops": "Cost (FinOps)",
        "revenue": "Revenue (EUR)", "units": "Units sold",
        "orders": "Orders", "basket": "Avg basket (EUR)",
        "rev_trend": "Revenue trend", "top_cat": "Top categories",
        "top_stores": "Top stores by revenue", "by_region": "Revenue by departement",
        "pick_cat": "Pick a category", "fc_title": "14-day demand forecast",
        "seg_title": "Customers per RFM segment", "avg_spend": "Average spend (EUR)",
        "credits_30d": "Credits (30d)", "ai_credits": "AI credits (30d)",
        "compute_credits": "Compute credits (30d)", "cost_by_cc": "Cost by cost-center",
        "cost_by_svc": "Cost by service",
    },
}

@st.cache_data(ttl=600)
def q(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()

lang = st.sidebar.radio("Langue / Language", ["fr", "en"], horizontal=True, key="lang")
t = T[lang]
st.title(t["title"])
st.caption(t["subtitle"])

tabs = st.tabs([t["overview"], t["stores"], t["forecast"], t["segments"], t["finops"]])

# ---- Overview ---------------------------------------------------------------
with tabs[0]:
    kpi = q(f"""
        SELECT ROUND(SUM(revenue_eur)) rev, SUM(units) units, SUM(orders) ord,
               ROUND(SUM(revenue_eur)/NULLIF(SUM(orders),0),2) basket
        FROM {SCHEMA}.MART_SALES_DAILY
    """).iloc[0]
    c1, c2, c3, c4 = st.columns(4)
    c1.metric(t["revenue"], f"{kpi['REV']:,.0f}")
    c2.metric(t["units"], f"{kpi['UNITS']:,.0f}")
    c3.metric(t["orders"], f"{kpi['ORD']:,.0f}")
    c4.metric(t["basket"], f"{kpi['BASKET']:,.2f}")

    trend = q(f"""
        SELECT DATE_TRUNC('month', sale_date) mois, ROUND(SUM(revenue_eur)) revenue_eur
        FROM {SCHEMA}.MART_SALES_DAILY
        WHERE sale_date >= DATEADD('month', -24, (SELECT MAX(sale_date) FROM {SCHEMA}.MART_SALES_DAILY))
        GROUP BY 1 ORDER BY 1
    """)
    st.subheader(t["rev_trend"])
    st.altair_chart(
        alt.Chart(trend).mark_line(point=True).encode(
            x=alt.X("MOIS:T", title=None), y=alt.Y("REVENUE_EUR:Q", title="EUR")
        ).properties(height=260), use_container_width=True)

    topcat = q(f"""
        SELECT product_category cat, ROUND(SUM(revenue_eur)) revenue_eur
        FROM {SCHEMA}.MART_SALES_DAILY WHERE product_category <> 'UNKNOWN'
        GROUP BY 1 ORDER BY revenue_eur DESC LIMIT 10
    """)
    st.subheader(t["top_cat"])
    st.altair_chart(
        alt.Chart(topcat).mark_bar().encode(
            x=alt.X("REVENUE_EUR:Q", title="EUR"), y=alt.Y("CAT:N", sort="-x", title=None)
        ).properties(height=300), use_container_width=True)

# ---- Stores -----------------------------------------------------------------
with tabs[1]:
    st.subheader(t["top_stores"])
    stores = q(f"""
        SELECT store_name, departement_code dep, ROUND(revenue_eur) revenue_eur,
               distinct_customers, avg_basket_eur
        FROM {SCHEMA}.MART_STORE_PERFORMANCE
        ORDER BY revenue_eur DESC LIMIT 20
    """)
    st.dataframe(stores, use_container_width=True, hide_index=True)
    st.subheader(t["by_region"])
    region = q(f"""
        SELECT departement_code dep, ROUND(SUM(revenue_eur)) revenue_eur
        FROM {SCHEMA}.MART_STORE_PERFORMANCE GROUP BY 1 ORDER BY revenue_eur DESC LIMIT 15
    """)
    st.altair_chart(
        alt.Chart(region).mark_bar().encode(
            x=alt.X("DEP:N", sort="-y", title="Departement"), y=alt.Y("REVENUE_EUR:Q", title="EUR")
        ).properties(height=280), use_container_width=True)

# ---- Forecast ---------------------------------------------------------------
with tabs[2]:
    st.subheader(t["fc_title"])
    cats = q(f"SELECT DISTINCT product_category FROM {SCHEMA}.FORECAST_DEMAND_CATEGORY ORDER BY 1")
    cat = st.selectbox(t["pick_cat"], cats["PRODUCT_CATEGORY"], key="fc_cat")
    fc = q(f"""
        SELECT forecast_date, forecast_units, lower_units, upper_units
        FROM {SCHEMA}.FORECAST_DEMAND_CATEGORY
        WHERE product_category = '{cat}' ORDER BY forecast_date
    """)
    band = alt.Chart(fc).mark_area(opacity=0.2).encode(
        x="FORECAST_DATE:T", y="LOWER_UNITS:Q", y2="UPPER_UNITS:Q")
    line = alt.Chart(fc).mark_line(point=True).encode(
        x=alt.X("FORECAST_DATE:T", title=None), y=alt.Y("FORECAST_UNITS:Q", title="Units"))
    st.altair_chart((band + line).properties(height=320), use_container_width=True)
    st.dataframe(fc, use_container_width=True, hide_index=True)

# ---- Segments ---------------------------------------------------------------
with tabs[3]:
    st.subheader(t["seg_title"])
    seg = q(f"""
        SELECT segment, COUNT(*) customers, ROUND(AVG(monetary_eur)) avg_spend
        FROM {SCHEMA}.MART_CUSTOMER_RFM GROUP BY 1 ORDER BY customers DESC
    """)
    c1, c2 = st.columns([2, 1])
    c1.altair_chart(
        alt.Chart(seg).mark_bar().encode(
            x=alt.X("CUSTOMERS:Q", title=t["segments"]), y=alt.Y("SEGMENT:N", sort="-x", title=None)
        ).properties(height=280), use_container_width=True)
    c2.dataframe(seg.rename(columns={"AVG_SPEND": t["avg_spend"]}), use_container_width=True, hide_index=True)

# ---- FinOps -----------------------------------------------------------------
with tabs[4]:
    try:
        s = q(f"SELECT * FROM {SCHEMA}.V_FINOPS_SUMMARY_30D").iloc[0]
        c1, c2, c3 = st.columns(3)
        c1.metric(t["credits_30d"], f"{s['TOTAL_CREDITS_30D']:,.1f}")
        c2.metric(t["ai_credits"], f"{s['AI_CREDITS_30D']:,.1f}")
        c3.metric(t["compute_credits"], f"{s['COMPUTE_CREDITS_30D']:,.1f}")
        st.subheader(t["cost_by_cc"])
        cc = q(f"SELECT cost_center, ROUND(SUM(credits),1) credits FROM {SCHEMA}.V_FINOPS_BY_COST_CENTER GROUP BY 1 ORDER BY credits DESC")
        st.altair_chart(
            alt.Chart(cc).mark_bar().encode(
                x=alt.X("CREDITS:Q", title="Credits"), y=alt.Y("COST_CENTER:N", sort="-x", title=None)
            ).properties(height=220), use_container_width=True)
        st.subheader(t["cost_by_svc"])
        svc = q(f"SELECT service_type, ROUND(SUM(credits),1) credits FROM {SCHEMA}.V_FINOPS_BY_SERVICE GROUP BY 1 ORDER BY credits DESC LIMIT 10")
        st.dataframe(svc, use_container_width=True, hide_index=True)
    except Exception as e:
        st.info("FinOps views need ACCOUNT_USAGE access (run as a role with IMPORTED PRIVILEGES). " + str(e))
