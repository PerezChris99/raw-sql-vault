-- Purpose: minimum demonstration grants.
-- Engine: PostgreSQL 15+; requires permission to create roles.
-- Roles are NOLOGIN placeholders. Configure authentication separately.
-- The invoker-rights function requires operators to have its underlying table rights.

DO $roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'opm_demo_reader') THEN
        CREATE ROLE opm_demo_reader NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'opm_demo_operator') THEN
        CREATE ROLE opm_demo_operator NOLOGIN;
    END IF;
END;
$roles$;

REVOKE ALL ON SCHEMA opm_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA opm_demo TO opm_demo_reader, opm_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA opm_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA opm_demo TO opm_demo_reader;
GRANT SELECT, INSERT ON opm_demo.programme_actions TO opm_demo_operator;
GRANT SELECT ON opm_demo.action_events TO opm_demo_operator;
GRANT SELECT ON opm_demo.departments TO opm_demo_operator;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA opm_demo TO opm_demo_operator;
GRANT EXECUTE ON FUNCTION opm_demo.fn_transition_action(BIGINT, TEXT, TEXT, TEXT)
    TO opm_demo_operator;

COMMENT ON SCHEMA opm_demo IS
    'Demonstration schema. Replace these illustrative roles with approved identity/role mappings before deployment.';