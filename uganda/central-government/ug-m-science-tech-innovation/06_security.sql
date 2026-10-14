-- Run as trusted DBA; roles are NOLOGIN examples.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='innovation_demo_reader') THEN CREATE ROLE innovation_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='innovation_demo_operator') THEN CREATE ROLE innovation_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA innovation_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA innovation_demo TO innovation_demo_reader,innovation_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA innovation_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA innovation_demo TO innovation_demo_reader,innovation_demo_operator;
GRANT EXECUTE ON FUNCTION innovation_demo.fn_transition_milestone(BIGINT,TEXT,TEXT,TEXT,TEXT) TO innovation_demo_operator;