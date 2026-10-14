-- Trusted DBA only; NOLOGIN demonstration roles.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ura_demo_reader') THEN CREATE ROLE ura_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ura_demo_operator') THEN CREATE ROLE ura_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA ura_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA ura_demo TO ura_demo_reader,ura_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA ura_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA ura_demo TO ura_demo_reader,ura_demo_operator;
GRANT EXECUTE ON FUNCTION ura_demo.fn_transition_filing(TEXT,TEXT,TEXT,TEXT) TO ura_demo_operator;
GRANT EXECUTE ON FUNCTION ura_demo.fn_record_payment(TEXT,TEXT,DATE,NUMERIC,CHAR,TEXT,TEXT,TEXT) TO ura_demo_operator;