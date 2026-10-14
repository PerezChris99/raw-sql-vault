-- Trusted DBA only; NOLOGIN examples, not user authentication.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='social_demo_reader') THEN CREATE ROLE social_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='social_demo_operator') THEN CREATE ROLE social_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA social_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA social_demo TO social_demo_reader,social_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA social_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA social_demo TO social_demo_reader,social_demo_operator;
GRANT EXECUTE ON FUNCTION social_demo.fn_transition_milestone(BIGINT,TEXT,TEXT,TEXT) TO social_demo_operator;