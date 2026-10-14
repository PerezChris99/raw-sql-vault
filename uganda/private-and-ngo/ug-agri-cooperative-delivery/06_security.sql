-- Run as trusted DBA; NOLOGIN examples require approved identity mapping.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='coop_demo_reader') THEN CREATE ROLE coop_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='coop_demo_operator') THEN CREATE ROLE coop_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA coop_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA coop_demo TO coop_demo_reader,coop_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA coop_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA coop_demo TO coop_demo_reader,coop_demo_operator;
GRANT EXECUTE ON FUNCTION coop_demo.fn_transition_delivery(BIGINT,TEXT,TEXT,TEXT,TEXT) TO coop_demo_operator;
GRANT EXECUTE ON FUNCTION coop_demo.fn_record_payment(TEXT,TEXT,NUMERIC,TEXT,TEXT,TEXT) TO coop_demo_operator;