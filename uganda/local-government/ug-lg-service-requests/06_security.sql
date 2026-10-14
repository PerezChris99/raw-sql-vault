-- Purpose: demonstration least-privilege roles for an isolated training database.
-- Engine: PostgreSQL 15+; requires role-creation rights.
-- NOLOGIN roles require separate deployment authentication and membership setup.

DO $roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_demo_reader') THEN
        CREATE ROLE service_demo_reader NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_demo_operator') THEN
        CREATE ROLE service_demo_operator NOLOGIN;
    END IF;
END;
$roles$;

REVOKE ALL ON SCHEMA service_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA service_demo TO service_demo_reader, service_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA service_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA service_demo TO service_demo_reader;
GRANT SELECT, INSERT ON service_demo.service_requests TO service_demo_operator;
GRANT SELECT ON service_demo.request_events TO service_demo_operator;
GRANT SELECT ON service_demo.localities TO service_demo_operator;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA service_demo TO service_demo_operator;
GRANT EXECUTE ON FUNCTION service_demo.fn_transition_request(BIGINT, TEXT, TEXT, TEXT)
    TO service_demo_operator;

COMMENT ON SCHEMA service_demo IS
    'Synthetic workflow examples. Production user-to-role mapping must be reviewed.';