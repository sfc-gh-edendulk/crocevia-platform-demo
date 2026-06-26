-- =============================================================================
-- FinOps 01 - Resource monitor (credit guardrails)
-- Caps credits on the demo warehouse and notifies / suspends at thresholds.
-- Demonstrates "no surprise bill" + per-warehouse cost control.
-- Idempotent. Run as ACCOUNTADMIN.
-- =============================================================================
USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR IF NOT EXISTS CROCEVIA_DEMO_RM
  WITH CREDIT_QUOTA = 100
       FREQUENCY = MONTHLY
       START_TIMESTAMP = IMMEDIATELY
       TRIGGERS
         ON 75 PERCENT DO NOTIFY
         ON 90 PERCENT DO NOTIFY
         ON 100 PERCENT DO SUSPEND
         ON 110 PERCENT DO SUSPEND_IMMEDIATE;

-- Attach to the demo warehouse (guardrail; quota is illustrative).
ALTER WAREHOUSE CR_DEV_WH SET RESOURCE_MONITOR = CROCEVIA_DEMO_RM;

SHOW RESOURCE MONITORS LIKE 'CROCEVIA_DEMO_RM';
