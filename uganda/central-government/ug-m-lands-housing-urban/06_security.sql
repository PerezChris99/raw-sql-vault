-- Trusted DBA only; NOLOGIN sample roles.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='urban_demo_reader') THEN CREATE ROLE urban_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='urban_demo_operator') THEN CREATE ROLE urban_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA urban_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA urban_demo TO urban_demo_reader,urban_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA urban_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA urban_demo TO urban_demo_reader,urban_demo_operator;
GRANT EXECUTE ON FUNCTION urban_demo.fn_transition_action(BIGINT,TEXT,TEXT,TEXT) TO urban_demo_operator;