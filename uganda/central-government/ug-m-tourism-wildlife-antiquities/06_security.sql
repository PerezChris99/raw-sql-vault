-- Trusted DBA only; NOLOGIN demonstration roles.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='tourism_demo_reader') THEN CREATE ROLE tourism_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='tourism_demo_operator') THEN CREATE ROLE tourism_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA tourism_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA tourism_demo TO tourism_demo_reader,tourism_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA tourism_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA tourism_demo TO tourism_demo_reader,tourism_demo_operator;
GRANT EXECUTE ON FUNCTION tourism_demo.fn_transition_action(BIGINT,TEXT,TEXT,TEXT) TO tourism_demo_operator;