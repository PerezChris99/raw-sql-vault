-- Trusted DBA only; NOLOGIN example roles require approved identity mapping.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ppda_demo_reader') THEN CREATE ROLE ppda_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ppda_demo_operator') THEN CREATE ROLE ppda_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA ppda_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA ppda_demo TO ppda_demo_reader,ppda_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA ppda_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA ppda_demo TO ppda_demo_reader,ppda_demo_operator;
GRANT EXECUTE ON FUNCTION ppda_demo.fn_transition_milestone(BIGINT,TEXT,TEXT,TEXT,TEXT) TO ppda_demo_operator;