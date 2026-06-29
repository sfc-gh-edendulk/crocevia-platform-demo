"""
Crocevia Platform Cockpit - Streamlit in Snowflake (bilingual FR/EN).
Snowflake-branded UI over the governed dbt marts + forecast + FinOps views.
Single-file app. Deploy with deploy_streamlit.sql.
"""
import streamlit as st
import pandas as pd
import altair as alt
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="Crocevia Platform Cockpit", page_icon="*", layout="wide")
session = get_active_session()
SCHEMA = "CROCEVIA_DB.PLATFORM_DEMO"

# Brand palette
BLUE, NAVY, AQUA, AMBER = "#29B5E8", "#11567F", "#71D3DC", "#FF9F36"
SEQ = [BLUE, NAVY, AQUA, AMBER, "#7E57C2", "#26A69A"]

# ---- styling -----------------------------------------------------------------
st.markdown(
    """
    <style>
      #MainMenu, footer, header {visibility: hidden;}
      .block-container {padding-top: 1.2rem; padding-bottom: 2rem; max-width: 1300px;}
      .hero {background: linear-gradient(110deg, #11567F 0%, #1B7FB5 55%, #29B5E8 100%);
             border-radius: 16px; padding: 22px 28px; margin-bottom: 18px; color: #fff;
             box-shadow: 0 6px 18px rgba(17,86,127,.25);}
      .hero h1 {margin: 0; font-size: 1.7rem; font-weight: 800; letter-spacing:.3px;}
      .hero p {margin: 6px 0 0; opacity: .92; font-size: .95rem;}
      .hero .pill {display:inline-block; margin-top:10px; background: rgba(255,255,255,.18);
             padding: 4px 12px; border-radius: 20px; font-size: .8rem;}
      div[data-testid="stMetric"] {background:#fff; border:1px solid #E6EEF4;
             border-left:5px solid #29B5E8; border-radius:12px; padding:14px 16px;
             box-shadow:0 1px 4px rgba(17,86,127,.06);}
      div[data-testid="stMetricLabel"] p {font-size:.8rem; color:#5B7488; font-weight:600;
             text-transform:uppercase; letter-spacing:.4px;}
      div[data-testid="stMetricValue"] {color:#11567F; font-weight:800;}
      h2, h3 {color:#11567F;}
      .stTabs [data-baseweb="tab-list"] {gap: 6px;}
      .stTabs [data-baseweb="tab"] {background:#F1F7FB; border-radius:8px 8px 0 0; padding:8px 16px;}
      .stTabs [aria-selected="true"] {background:#29B5E8 !important; color:#fff !important;}
      .card {background:#fff; border:1px solid #E6EEF4; border-radius:12px; padding:16px 18px;
             box-shadow:0 1px 4px rgba(17,86,127,.06); margin-bottom:6px;}
    </style>
    """,
    unsafe_allow_html=True,
)

T = {
    "fr": {"subtitle": "Ventes, prévision, clients et coûts — sur données gouvernées Snowflake",
           "overview": "Vue d'ensemble", "stores": "Magasins", "forecast": "Prévision",
           "segments": "Clients", "finops": "Coûts (FinOps)",
           "revenue": "Chiffre d'affaires", "units": "Unités vendues", "orders": "Commandes",
           "basket": "Panier moyen", "vs": "vs 90j préc.", "rev_trend": "Chiffre d'affaires mensuel",
           "top_cat": "Top catégories", "top_stores": "Top magasins", "by_region": "CA par département",
           "pick_cat": "Catégorie", "fc_title": "Prévision de la demande à 14 jours",
           "seg_title": "Clients par segment RFM", "avg_spend": "Dépense moy. (€)",
           "credits": "Crédits (30 j)", "ai_credits": "Crédits IA (30 j)", "compute_credits": "Crédits calcul (30 j)",
           "cost_cc": "Coûts par centre de coût", "cost_svc": "Coûts par service", "asof": "Données au"},
    "en": {"subtitle": "Sales, forecast, customers and cost — on governed Snowflake data",
           "overview": "Overview", "stores": "Stores", "forecast": "Forecast",
           "segments": "Customers", "finops": "Cost (FinOps)",
           "revenue": "Revenue", "units": "Units sold", "orders": "Orders",
           "basket": "Avg basket", "vs": "vs prev 90d", "rev_trend": "Monthly revenue",
           "top_cat": "Top categories", "top_stores": "Top stores", "by_region": "Revenue by departement",
           "pick_cat": "Category", "fc_title": "14-day demand forecast",
           "seg_title": "Customers per RFM segment", "avg_spend": "Avg spend (€)",
           "credits": "Credits (30d)", "ai_credits": "AI credits (30d)", "compute_credits": "Compute credits (30d)",
           "cost_cc": "Cost by cost-center", "cost_svc": "Cost by service", "asof": "Data as of"},
}


@st.cache_data(ttl=600)
def q(sql: str) -> pd.DataFrame:
    return session.sql(sql).to_pandas()


lang = st.sidebar.radio("Langue / Language", ["fr", "en"], horizontal=True, key="lang")
t = T[lang]
asof = q(f"SELECT MAX(sale_date)::STRING AS d FROM {SCHEMA}.MART_SALES_DAILY")["D"].iloc[0]

st.markdown(
    f"""<div class="hero">
        <h1>Crocevia &middot; Platform Cockpit</h1>
        <p>{t['subtitle']}</p>
        <span class="pill">{t['asof']} {asof} &nbsp;|&nbsp; dbt &middot; ML &middot; FinOps &middot; gouvernance</span>
    </div>""",
    unsafe_allow_html=True,
)

tabs = st.tabs([t["overview"], t["stores"], t["forecast"], t["segments"], t["finops"]])


def brand_bar(df, x, y, horizontal=False, color=BLUE, height=300):
    enc = (alt.X(f"{x}:N", sort="-y", title=None), alt.Y(f"{y}:Q", title=None)) if not horizontal \
        else (alt.X(f"{y}:Q", title=None), alt.Y(f"{x}:N", sort="-x", title=None))
    return (alt.Chart(df).mark_bar(color=color, cornerRadiusEnd=4)
            .encode(x=enc[0], y=enc[1], tooltip=list(df.columns))
            .properties(height=height).configure_view(strokeOpacity=0)
            .configure_axis(grid=False, labelColor="#5B7488", labelFontSize=11))


# ---- Overview ---------------------------------------------------------------
with tabs[0]:
    cur = q(f"""SELECT ROUND(SUM(revenue_eur)) rev, SUM(units) units, SUM(orders) ord,
                       ROUND(SUM(revenue_eur)/NULLIF(SUM(orders),0),2) basket
                FROM {SCHEMA}.MART_SALES_DAILY
                WHERE sale_date > DATEADD('day',-90,TO_DATE('{asof}'))""").iloc[0]
    prev = q(f"""SELECT ROUND(SUM(revenue_eur)) rev, SUM(units) units, SUM(orders) ord,
                        ROUND(SUM(revenue_eur)/NULLIF(SUM(orders),0),2) basket
                 FROM {SCHEMA}.MART_SALES_DAILY
                 WHERE sale_date BETWEEN DATEADD('day',-180,TO_DATE('{asof}')) AND DATEADD('day',-90,TO_DATE('{asof}'))""").iloc[0]

    def delta(c, p):
        return None if not p else f"{(c-p)/p*100:+.1f}% {t['vs']}"

    c1, c2, c3, c4 = st.columns(4)
    c1.metric(t["revenue"], f"{cur['REV']:,.0f} €", delta(cur["REV"], prev["REV"]))
    c2.metric(t["units"], f"{cur['UNITS']:,.0f}", delta(cur["UNITS"], prev["UNITS"]))
    c3.metric(t["orders"], f"{cur['ORD']:,.0f}", delta(cur["ORD"], prev["ORD"]))
    c4.metric(t["basket"], f"{cur['BASKET']:,.2f} €", delta(cur["BASKET"], prev["BASKET"]))

    st.write("")
    left, right = st.columns([3, 2], gap="medium")
    with left:
        st.subheader(t["rev_trend"])
        trend = q(f"""SELECT DATE_TRUNC('month', sale_date) mois, ROUND(SUM(revenue_eur)) revenue_eur
                      FROM {SCHEMA}.MART_SALES_DAILY
                      WHERE sale_date >= DATEADD('month',-24,(SELECT MAX(sale_date) FROM {SCHEMA}.MART_SALES_DAILY))
                      GROUP BY 1 ORDER BY 1""")
        area = (alt.Chart(trend).mark_area(
                    line={"color": BLUE, "strokeWidth": 2},
                    color=alt.Gradient(gradient="linear",
                        stops=[alt.GradientStop(color="#FFFFFF", offset=0), alt.GradientStop(color=BLUE, offset=1)],
                        x1=1, x2=1, y1=1, y2=0))
                .encode(x=alt.X("MOIS:T", title=None), y=alt.Y("REVENUE_EUR:Q", title="€"),
                        tooltip=["MOIS:T", "REVENUE_EUR:Q"])
                .properties(height=300).configure_view(strokeOpacity=0)
                .configure_axis(grid=False, labelColor="#5B7488"))
        st.altair_chart(area, use_container_width=True)
    with right:
        st.subheader(t["top_cat"])
        cats = q(f"""SELECT product_category cat, ROUND(SUM(revenue_eur)) revenue_eur
                     FROM {SCHEMA}.MART_SALES_DAILY WHERE product_category <> 'UNKNOWN'
                     GROUP BY 1 ORDER BY revenue_eur DESC LIMIT 8""")
        st.altair_chart(brand_bar(cats, "CAT", "REVENUE_EUR", horizontal=True, color=NAVY, height=300),
                        use_container_width=True)

# ---- Stores -----------------------------------------------------------------
with tabs[1]:
    st.subheader(t["by_region"])
    region = q(f"""SELECT departement_code dep, ROUND(SUM(revenue_eur)) revenue_eur
                   FROM {SCHEMA}.MART_STORE_PERFORMANCE GROUP BY 1 ORDER BY revenue_eur DESC LIMIT 15""")
    st.altair_chart(brand_bar(region, "DEP", "REVENUE_EUR", color=BLUE, height=280), use_container_width=True)
    st.subheader(t["top_stores"])
    stores = q(f"""SELECT store_name, departement_code dep, ROUND(revenue_eur) revenue_eur,
                          distinct_customers, avg_basket_eur
                   FROM {SCHEMA}.MART_STORE_PERFORMANCE ORDER BY revenue_eur DESC LIMIT 20""")
    st.dataframe(stores, use_container_width=True, hide_index=True,
                 column_config={"REVENUE_EUR": st.column_config.NumberColumn("Revenue (€)", format="%d"),
                                "AVG_BASKET_EUR": st.column_config.NumberColumn("Avg basket (€)", format="%.2f")})

# ---- Forecast ---------------------------------------------------------------
with tabs[2]:
    st.subheader(t["fc_title"])
    cats = q(f"SELECT DISTINCT product_category FROM {SCHEMA}.FORECAST_DEMAND_CATEGORY ORDER BY 1")
    cat = st.selectbox(t["pick_cat"], cats["PRODUCT_CATEGORY"], key="fc_cat")
    fc = q(f"""SELECT forecast_date, forecast_units, lower_units, upper_units
               FROM {SCHEMA}.FORECAST_DEMAND_CATEGORY WHERE product_category = '{cat}' ORDER BY forecast_date""")
    band = alt.Chart(fc).mark_area(opacity=0.18, color=BLUE).encode(
        x=alt.X("FORECAST_DATE:T", title=None), y="LOWER_UNITS:Q", y2="UPPER_UNITS:Q")
    line = alt.Chart(fc).mark_line(color=BLUE, strokeWidth=3, point=alt.OverlayMarkDef(color=NAVY)).encode(
        x="FORECAST_DATE:T", y=alt.Y("FORECAST_UNITS:Q", title="Units"),
        tooltip=["FORECAST_DATE:T", "FORECAST_UNITS:Q"])
    st.altair_chart((band + line).properties(height=340).configure_view(strokeOpacity=0)
                    .configure_axis(grid=False, labelColor="#5B7488"), use_container_width=True)
    st.caption("Cortex ML FORECAST entraîné dans Snowflake — précision ~76% (MAPE ~0.24).")

# ---- Segments ---------------------------------------------------------------
with tabs[3]:
    st.subheader(t["seg_title"])
    seg = q(f"""SELECT segment, COUNT(*) customers, ROUND(AVG(monetary_eur)) avg_spend
                FROM {SCHEMA}.MART_CUSTOMER_RFM GROUP BY 1 ORDER BY customers DESC""")
    c1, c2 = st.columns([3, 2], gap="medium")
    c1.altair_chart(brand_bar(seg, "SEGMENT", "CUSTOMERS", horizontal=True, color=NAVY, height=300),
                    use_container_width=True)
    c2.dataframe(seg.rename(columns={"AVG_SPEND": t["avg_spend"]}), use_container_width=True, hide_index=True)

# ---- FinOps -----------------------------------------------------------------
with tabs[4]:
    try:
        s = q(f"SELECT * FROM {SCHEMA}.V_FINOPS_SUMMARY_30D").iloc[0]
        c1, c2, c3 = st.columns(3)
        c1.metric(t["credits"], f"{s['TOTAL_CREDITS_30D']:,.1f}")
        c2.metric(t["ai_credits"], f"{s['AI_CREDITS_30D']:,.1f}")
        c3.metric(t["compute_credits"], f"{s['COMPUTE_CREDITS_30D']:,.1f}")
        st.write("")
        st.subheader(t["cost_cc"])
        cc = q(f"SELECT cost_center, ROUND(SUM(credits),1) credits FROM {SCHEMA}.V_FINOPS_BY_COST_CENTER GROUP BY 1 ORDER BY credits DESC")
        st.altair_chart(brand_bar(cc, "COST_CENTER", "CREDITS", horizontal=True, color=AQUA, height=240),
                        use_container_width=True)
        st.subheader(t["cost_svc"])
        svc = q(f"SELECT service_type, ROUND(SUM(credits),1) credits FROM {SCHEMA}.V_FINOPS_BY_SERVICE GROUP BY 1 ORDER BY credits DESC LIMIT 10")
        st.dataframe(svc, use_container_width=True, hide_index=True)
    except Exception as e:
        st.info("FinOps views need ACCOUNT_USAGE access (role with IMPORTED PRIVILEGES). " + str(e))
