-- PostgreSQL 15+; apply as a trusted DBA. These are NOLOGIN example roles.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='lgmin_demo_reader') THEN CREATE ROLE lgmin_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='lgmin_demo_operator') THEN CREATE ROLE lgmin_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA lgmin_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA lgmin_demo TO lgmin_demo_reader,lgmin_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA lgmin_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA lgmin_demo TO lgmin_demo_reader,lgmin_demo_operator;
GRANT EXECUTE ON FUNCTION lgmin_demo.fn_transition_programme(BIGINT,TEXT,TEXT,TEXT) TO lgmin_demo_operator;
-- Runtime roles intentionally have no direct UPDATE on programmes or INSERT on programme_events.