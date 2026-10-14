-- Run as trusted DBA; these are NOLOGIN examples requiring deployment-specific role mapping.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='works_demo_reader') THEN CREATE ROLE works_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='works_demo_operator') THEN CREATE ROLE works_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA works_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA works_demo TO works_demo_reader,works_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA works_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA works_demo TO works_demo_reader,works_demo_operator;
GRANT EXECUTE ON FUNCTION works_demo.fn_transition_work_order(BIGINT,TEXT,TEXT,TEXT,NUMERIC) TO works_demo_operator;
-- Operators intentionally have no direct UPDATE on work_orders or INSERT on events.