-- Run as a trusted DBA; NOLOGIN example roles require deployment-specific mapping.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='water_demo_reader') THEN CREATE ROLE water_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='water_demo_operator') THEN CREATE ROLE water_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA water_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA water_demo TO water_demo_reader,water_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA water_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA water_demo TO water_demo_reader,water_demo_operator;
GRANT EXECUTE ON FUNCTION water_demo.fn_transition_job(BIGINT,TEXT,TEXT,TEXT,NUMERIC) TO water_demo_operator;