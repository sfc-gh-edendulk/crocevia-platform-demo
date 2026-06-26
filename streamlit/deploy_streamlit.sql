-- =============================================================================
-- Deploy the Streamlit cockpit to Snowflake (Streamlit in Snowflake).
-- Run:  snow sql -f streamlit/deploy_streamlit.sql -c <connection>
--       (run from the streamlit/ directory so the PUT paths resolve, or adjust paths)
-- =============================================================================
USE ROLE ACCOUNTADMIN;
USE SCHEMA CROCEVIA_DB.PLATFORM_DEMO;

CREATE STAGE IF NOT EXISTS CROCEVIA_DB.PLATFORM_DEMO.STREAMLIT_STAGE
  DIRECTORY = (ENABLE = TRUE);

-- Upload the app + environment (paths are relative to where you run snow sql)
PUT file://streamlit_app.py @CROCEVIA_DB.PLATFORM_DEMO.STREAMLIT_STAGE/crocevia_cockpit
  OVERWRITE = TRUE AUTO_COMPRESS = FALSE;
PUT file://environment.yml  @CROCEVIA_DB.PLATFORM_DEMO.STREAMLIT_STAGE/crocevia_cockpit
  OVERWRITE = TRUE AUTO_COMPRESS = FALSE;

CREATE OR REPLACE STREAMLIT CROCEVIA_DB.PLATFORM_DEMO.CROCEVIA_COCKPIT
  ROOT_LOCATION = '@CROCEVIA_DB.PLATFORM_DEMO.STREAMLIT_STAGE/crocevia_cockpit'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = CR_DEV_WH
  COMMENT = 'Crocevia platform cockpit (bilingual)';

GRANT USAGE ON STREAMLIT CROCEVIA_DB.PLATFORM_DEMO.CROCEVIA_COCKPIT TO ROLE CROCEVIA_DATA_STEWARD;

SHOW STREAMLITS LIKE 'CROCEVIA_COCKPIT' IN SCHEMA CROCEVIA_DB.PLATFORM_DEMO;
