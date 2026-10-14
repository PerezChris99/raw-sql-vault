-- Trusted DBA only; NOLOGIN roles require external identity mapping.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='pos_demo_reader') THEN CREATE ROLE pos_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='pos_demo_operator') THEN CREATE ROLE pos_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA pos_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA pos_demo TO pos_demo_reader,pos_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA pos_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA pos_demo TO pos_demo_reader,pos_demo_operator;
GRANT EXECUTE ON FUNCTION pos_demo.fn_record_return(TEXT,BIGINT,INTEGER,TEXT,TEXT) TO pos_demo_operator;