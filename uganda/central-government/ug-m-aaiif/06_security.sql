-- Trusted DBA only. NOLOGIN roles need deployment-specific identity mapping.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='agriculture_demo_reader') THEN CREATE ROLE agriculture_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='agriculture_demo_operator') THEN CREATE ROLE agriculture_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA agriculture_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA agriculture_demo TO agriculture_demo_reader,agriculture_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA agriculture_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA agriculture_demo TO agriculture_demo_reader,agriculture_demo_operator;
GRANT EXECUTE ON FUNCTION agriculture_demo.fn_transition_delivery(BIGINT,TEXT,TEXT,TEXT,NUMERIC,TEXT) TO agriculture_demo_operator;