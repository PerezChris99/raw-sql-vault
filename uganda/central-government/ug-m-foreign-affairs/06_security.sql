-- Run as trusted DBA. Roles are NOLOGIN examples, not authentication.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='diplomacy_demo_reader') THEN CREATE ROLE diplomacy_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='diplomacy_demo_operator') THEN CREATE ROLE diplomacy_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA diplomacy_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA diplomacy_demo TO diplomacy_demo_reader,diplomacy_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA diplomacy_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA diplomacy_demo TO diplomacy_demo_reader,diplomacy_demo_operator;
GRANT EXECUTE ON FUNCTION diplomacy_demo.fn_transition_commitment(BIGINT,TEXT,TEXT,TEXT) TO diplomacy_demo_operator;