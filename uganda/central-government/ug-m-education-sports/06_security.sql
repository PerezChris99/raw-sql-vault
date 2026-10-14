-- Trusted DBA only; NOLOGIN demonstration roles require approved role mapping.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='education_demo_reader') THEN CREATE ROLE education_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='education_demo_operator') THEN CREATE ROLE education_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA education_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA education_demo TO education_demo_reader,education_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA education_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA education_demo TO education_demo_reader,education_demo_operator;
GRANT EXECUTE ON FUNCTION education_demo.fn_transition_allocation(BIGINT,TEXT,TEXT,TEXT,INTEGER,TEXT) TO education_demo_operator;