-- =============================================================================
-- FinOps 02 - Budget (spend tracking + alerting)
-- A SNOWFLAKE.CORE.BUDGET tracks spend for a group of objects and alerts when a
-- monthly limit is projected to be exceeded.
-- Idempotent-ish. Run as ACCOUNTADMIN.
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

-- Instantiate a budget object in the demo schema.
CREATE OR REPLACE SNOWFLAKE.CORE.BUDGET CROCEVIA_DEMO_BUDGET();

-- Configure: monthly spending limit (credits) + the warehouse we want to track.
-- Note: budget resource references require the APPLYBUDGET privilege scope.
CALL CROCEVIA_DEMO_BUDGET!SET_SPENDING_LIMIT(100);
CALL CROCEVIA_DEMO_BUDGET!ADD_RESOURCE(SYSTEM$REFERENCE('WAREHOUSE', 'CR_DEV_WH', 'SESSION', 'APPLYBUDGET'));

-- (Optional) add an email notification integration, then:
-- CALL CROCEVIA_DEMO_BUDGET!SET_EMAIL_NOTIFICATIONS('<notification_integration>', 'you@example.com');

-- Inspect linked resources.
CALL CROCEVIA_DEMO_BUDGET!GET_LINKED_RESOURCES();
