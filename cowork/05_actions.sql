-- =============================================================================
-- CoWork 05 - Action tools (the "ACT" phase of the demo)
-- -----------------------------------------------------------------------------
-- Gives the Crocevia Analyst agent the ability to DO things, not just answer:
--   1. CREATE_ACTIVATION_AUDIENCE  - write an AI-identified segment back to the
--                                    platform as a real, activatable dataset.
--   2. SEND_BRIEFING_EMAIL         - email a formatted HTML briefing.
--   3. CREATE_REVENUE_ALERT        - stand up proactive monitoring on a metric.
-- These are wired into the agent as custom (generic) tools in cowork/03_agent.sql.
-- Idempotent. Run as ACCOUNTADMIN after the marts + governance exist.
-- Run:  snow sql -f cowork/05_actions.sql -c <connection>
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

-- Email channel for briefings + alerts. Recipients must be VERIFIED user emails
-- in this account (Snowflake guardrail). ENABLED so the agent can send live.
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS CROCEVIA_EMAIL_INT
  TYPE = EMAIL
  ENABLED = TRUE
  COMMENT = 'Email channel for Crocevia Analyst agent briefings and alerts';

-- Write-back target: an AI-identified segment becomes a governed, activatable
-- dataset (the hand-off point to a CDP / DV360 / CRM).
CREATE TABLE IF NOT EXISTS CROCEVIA_DB.PLATFORM_DEMO.ACTIVATION_AUDIENCES (
  AUDIENCE_ID       STRING DEFAULT UUID_STRING(),
  AUDIENCE_NAME     STRING,
  SEGMENT_CRITERIA  STRING,
  ESTIMATED_SIZE    NUMBER,
  DESTINATION       STRING,
  CREATED_BY        STRING,
  CREATED_AT        TIMESTAMP_NTZ
);

-- -----------------------------------------------------------------------------
-- Tool 1: CREATE_ACTIVATION_AUDIENCE
-- Counts customers matching a segment + recency rule and records the audience.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CROCEVIA_DB.PLATFORM_DEMO.CREATE_ACTIVATION_AUDIENCE(
  AUDIENCE_NAME STRING, SEGMENT STRING, MIN_RECENCY_DAYS NUMBER, DESTINATION STRING)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Create an activation audience from the customer RFM mart and record it for downstream activation.'
AS
$$
DECLARE
  n NUMBER;
  crit STRING;
  dest STRING;
BEGIN
  dest := COALESCE(NULLIF(:DESTINATION, ''), 'DV360');
  crit := 'segment=' || COALESCE(NULLIF(:SEGMENT, ''), 'ALL')
          || ', recency_days>=' || :MIN_RECENCY_DAYS;

  SELECT COUNT(*) INTO :n
  FROM CROCEVIA_DB.PLATFORM_DEMO.MART_CUSTOMER_RFM
  WHERE RECENCY_DAYS >= :MIN_RECENCY_DAYS
    AND (:SEGMENT IS NULL OR :SEGMENT = '' OR UPPER(SEGMENT) = UPPER(:SEGMENT));

  INSERT INTO CROCEVIA_DB.PLATFORM_DEMO.ACTIVATION_AUDIENCES
    (AUDIENCE_NAME, SEGMENT_CRITERIA, ESTIMATED_SIZE, DESTINATION, CREATED_BY, CREATED_AT)
  SELECT :AUDIENCE_NAME, :crit, :n, :dest, CURRENT_USER(), CURRENT_TIMESTAMP();

  RETURN 'Audience "' || :AUDIENCE_NAME || '" created with ' || :n
       || ' customers (' || :crit || '), destination=' || :dest
       || '. Written to PLATFORM_DEMO.ACTIVATION_AUDIENCES for activation.';
END;
$$;

-- -----------------------------------------------------------------------------
-- Tool 2: SEND_BRIEFING_EMAIL
-- Sends an HTML briefing via the notification integration. Returns a friendly
-- status (including the error text) so the agent can report gracefully if the
-- recipient is not a verified account user.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CROCEVIA_DB.PLATFORM_DEMO.SEND_BRIEFING_EMAIL(
  RECIPIENT STRING, SUBJECT STRING, HTML_BODY STRING)
RETURNS STRING
LANGUAGE SQL
COMMENT = 'Email an HTML briefing to a verified account user via CROCEVIA_EMAIL_INT.'
AS
$$
BEGIN
  CALL SYSTEM$SEND_EMAIL('CROCEVIA_EMAIL_INT', :RECIPIENT, :SUBJECT, :HTML_BODY, 'text/html');
  RETURN 'Briefing emailed to ' || :RECIPIENT || ' (subject: "' || :SUBJECT || '").';
EXCEPTION
  WHEN OTHER THEN
    RETURN 'Could not send email to ' || :RECIPIENT
         || '. Recipient must be a verified user in this account. Details: ' || SQLERRM;
END;
$$;

-- -----------------------------------------------------------------------------
-- Tool 3: CREATE_REVENUE_ALERT
-- Stands up a (suspended) weekly alert that emails when a category's revenue
-- drops more than DROP_PCT week-over-week. Python for safe identifier handling.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE CROCEVIA_DB.PLATFORM_DEMO.CREATE_REVENUE_ALERT(
  CATEGORY STRING, DROP_PCT FLOAT, RECIPIENT STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'run'
COMMENT = 'Create a suspended weekly alert emailing when a category revenue drops > drop_pct WoW.'
AS
$$
import re

def run(session, category, drop_pct, recipient):
    safe = re.sub(r'[^A-Za-z0-9]', '_', (category or 'ALL').upper())[:40]
    alert_name = f'CROCEVIA_DB.PLATFORM_DEMO.CROCEVIA_REVENUE_ALERT_{safe}'
    cat_lit = (category or '').replace("'", "''")
    rcpt = (recipient or '').replace("'", "''")
    frac = float(drop_pct) / 100.0 if float(drop_pct) > 1 else float(drop_pct)

    cond = f"""
      WITH w AS (
        SELECT
          SUM(CASE WHEN sale_date >= DATEADD('day',-7,(SELECT MAX(sale_date) FROM CROCEVIA_DB.PLATFORM_DEMO.MART_SALES_DAILY))
                   THEN revenue_eur END) AS cur,
          SUM(CASE WHEN sale_date >= DATEADD('day',-14,(SELECT MAX(sale_date) FROM CROCEVIA_DB.PLATFORM_DEMO.MART_SALES_DAILY))
                    AND sale_date <  DATEADD('day',-7,(SELECT MAX(sale_date) FROM CROCEVIA_DB.PLATFORM_DEMO.MART_SALES_DAILY))
                   THEN revenue_eur END) AS prev
        FROM CROCEVIA_DB.PLATFORM_DEMO.MART_SALES_DAILY
        WHERE product_category = '{cat_lit}'
      )
      SELECT 1 FROM w WHERE prev > 0 AND (prev - cur) / prev > {frac}
    """
    body = (f'Category {cat_lit}: week-over-week revenue dropped more than '
            f'{frac*100:.0f}%. Open Crocevia Analyst in Snowflake CoWork for details.')
    ddl = f"""
      CREATE OR REPLACE ALERT {alert_name}
        WAREHOUSE = CR_DEV_WH
        SCHEDULE = 'USING CRON 0 8 * * MON Europe/Paris'
        IF (EXISTS ({cond}))
        THEN CALL SYSTEM$SEND_EMAIL('CROCEVIA_EMAIL_INT', '{rcpt}',
             'Crocevia alerte CA - {cat_lit}', '{body}')
    """
    session.sql(ddl).collect()
    return (f'Alert {alert_name} created (SUSPENDED) for category "{cat_lit}" at a '
            f'{frac*100:.0f}% WoW drop threshold. Resume with: ALTER ALERT {alert_name} RESUME;')
$$;

-- Allow the demo personas to use the action tools via the agent.
GRANT USAGE ON PROCEDURE CROCEVIA_DB.PLATFORM_DEMO.CREATE_ACTIVATION_AUDIENCE(STRING, STRING, NUMBER, STRING) TO ROLE CROCEVIA_DATA_STEWARD;
GRANT USAGE ON PROCEDURE CROCEVIA_DB.PLATFORM_DEMO.SEND_BRIEFING_EMAIL(STRING, STRING, STRING) TO ROLE CROCEVIA_DATA_STEWARD;
GRANT USAGE ON PROCEDURE CROCEVIA_DB.PLATFORM_DEMO.CREATE_REVENUE_ALERT(STRING, FLOAT, STRING) TO ROLE CROCEVIA_DATA_STEWARD;

-- Smoke test (safe): build a tiny audience and confirm the write-back.
CALL CROCEVIA_DB.PLATFORM_DEMO.CREATE_ACTIVATION_AUDIENCE('TEST_LAPSED_HIGH_VALUE', 'HIGH_SPENDER', 60, 'DV360');
SELECT AUDIENCE_NAME, SEGMENT_CRITERIA, ESTIMATED_SIZE, DESTINATION FROM CROCEVIA_DB.PLATFORM_DEMO.ACTIVATION_AUDIENCES ORDER BY CREATED_AT DESC LIMIT 3;
