-- Trusted DBA only; NOLOGIN sample roles.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='city_ops_demo_reader') THEN CREATE ROLE city_ops_demo_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='city_ops_demo_operator') THEN CREATE ROLE city_ops_demo_operator NOLOGIN; END IF;
END $$;
REVOKE ALL ON SCHEMA city_ops_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA city_ops_demo TO city_ops_demo_reader,city_ops_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA city_ops_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA city_ops_demo TO city_ops_demo_reader,city_ops_demo_operator;
GRANT EXECUTE ON FUNCTION city_ops_demo.fn_transition_work(BIGINT,TEXT,TEXT,TEXT) TO city_ops_demo_operator;