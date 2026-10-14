-- Trusted DBA only; NOLOGIN examples require deployment role mapping.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ngo_demo_reader') THEN CREATE ROLE ngo_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ngo_demo_operator') THEN CREATE ROLE ngo_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA ngo_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA ngo_demo TO ngo_demo_reader,ngo_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA ngo_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA ngo_demo TO ngo_demo_reader,ngo_demo_operator;
GRANT EXECUTE ON FUNCTION ngo_demo.fn_transition_milestone(TEXT,TEXT,TEXT,TEXT,TEXT) TO ngo_demo_operator;
GRANT EXECUTE ON FUNCTION ngo_demo.fn_record_expenditure(TEXT,TEXT,DATE,NUMERIC,CHAR,TEXT,TEXT,TEXT) TO ngo_demo_operator;