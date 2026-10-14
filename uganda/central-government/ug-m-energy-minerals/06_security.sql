-- Apply as trusted DBA; NOLOGIN roles require deployment-specific identity mapping.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='energy_demo_reader') THEN CREATE ROLE energy_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='energy_demo_operator') THEN CREATE ROLE energy_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA energy_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA energy_demo TO energy_demo_reader,energy_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA energy_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA energy_demo TO energy_demo_reader,energy_demo_operator;
GRANT EXECUTE ON FUNCTION energy_demo.fn_transition_action(BIGINT,TEXT,TEXT,TEXT) TO energy_demo_operator;