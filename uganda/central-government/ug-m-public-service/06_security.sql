-- Trusted DBA only; NOLOGIN example roles.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='public_service_demo_reader') THEN CREATE ROLE public_service_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='public_service_demo_operator') THEN CREATE ROLE public_service_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA public_service_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA public_service_demo TO public_service_demo_reader,public_service_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA public_service_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA public_service_demo TO public_service_demo_reader,public_service_demo_operator;
GRANT EXECUTE ON FUNCTION public_service_demo.fn_transition_enrolment(BIGINT,TEXT,TEXT,TEXT,NUMERIC) TO public_service_demo_operator;