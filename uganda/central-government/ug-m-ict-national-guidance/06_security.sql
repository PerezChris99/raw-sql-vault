-- Apply as trusted DBA. NOLOGIN roles require approved identity mapping.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ict_demo_reader') THEN CREATE ROLE ict_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ict_demo_operator') THEN CREATE ROLE ict_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA ict_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA ict_demo TO ict_demo_reader,ict_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA ict_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA ict_demo TO ict_demo_reader,ict_demo_operator;
GRANT EXECUTE ON FUNCTION ict_demo.fn_transition_work(BIGINT,TEXT,TEXT,TEXT) TO ict_demo_operator;