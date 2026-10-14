-- Trusted DBA only; NOLOGIN example roles.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='trade_demo_reader') THEN CREATE ROLE trade_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='trade_demo_operator') THEN CREATE ROLE trade_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA trade_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA trade_demo TO trade_demo_reader,trade_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA trade_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA trade_demo TO trade_demo_reader,trade_demo_operator;
GRANT EXECUTE ON FUNCTION trade_demo.fn_transition_milestone(BIGINT,TEXT,TEXT,TEXT) TO trade_demo_operator;