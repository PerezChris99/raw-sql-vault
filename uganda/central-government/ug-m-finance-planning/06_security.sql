-- Trusted DBA only; roles are NOLOGIN placeholders.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='finance_demo_reader') THEN CREATE ROLE finance_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='finance_demo_operator') THEN CREATE ROLE finance_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA finance_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA finance_demo TO finance_demo_reader,finance_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA finance_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA finance_demo TO finance_demo_reader,finance_demo_operator;
GRANT EXECUTE ON FUNCTION finance_demo.fn_record_release(TEXT,TEXT,DATE,NUMERIC,TEXT,TEXT) TO finance_demo_operator;
GRANT EXECUTE ON FUNCTION finance_demo.fn_record_expenditure(TEXT,TEXT,DATE,NUMERIC,TEXT,TEXT,TEXT) TO finance_demo_operator;