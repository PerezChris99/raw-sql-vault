-- Purpose: demonstration separation of inventory reporting and movement writes.
-- Engine: PostgreSQL 15+; run as DBA/migration owner. Roles are NOLOGIN placeholders.
DO $roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'medicine_demo_reader') THEN
        CREATE ROLE medicine_demo_reader NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'medicine_demo_operator') THEN
        CREATE ROLE medicine_demo_operator NOLOGIN;
    END IF;
END;
$roles$;

REVOKE ALL ON SCHEMA medicine_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA medicine_demo TO medicine_demo_reader, medicine_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA medicine_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA medicine_demo TO medicine_demo_reader, medicine_demo_operator;
GRANT EXECUTE ON FUNCTION medicine_demo.fn_record_movement(TEXT, TEXT, TEXT, BIGINT, TEXT, TEXT, TEXT, TEXT)
    TO medicine_demo_operator;
-- No direct INSERT/UPDATE/DELETE grants on stock_movements are given to runtime roles.
COMMENT ON SCHEMA medicine_demo IS
    'Synthetic demonstration. In production, map approved authenticated identities to narrowly scoped roles.';