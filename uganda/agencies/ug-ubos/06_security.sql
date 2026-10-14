-- Trusted DBA only. NOLOGIN roles are illustrative.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ubos_demo_reader') THEN CREATE ROLE ubos_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ubos_demo_operator') THEN CREATE ROLE ubos_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA ubos_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA ubos_demo TO ubos_demo_reader,ubos_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA ubos_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA ubos_demo TO ubos_demo_reader,ubos_demo_operator;
GRANT EXECUTE ON FUNCTION ubos_demo.fn_transition_wave(BIGINT,TEXT,TEXT,TEXT) TO ubos_demo_operator;