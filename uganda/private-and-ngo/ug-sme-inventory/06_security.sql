-- Purpose: separate reporting access from stock-changing operations.
-- Engine: PostgreSQL 15+; role-creation privileges required.
-- Run as a trusted migration/owner role. This script's roles are NOLOGIN placeholders.

DO $roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sme_stock_reader') THEN
        CREATE ROLE sme_stock_reader NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sme_stock_operator') THEN
        CREATE ROLE sme_stock_operator NOLOGIN;
    END IF;
END;
$roles$;

REVOKE ALL ON SCHEMA sme_stock_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA sme_stock_demo TO sme_stock_reader, sme_stock_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA sme_stock_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA sme_stock_demo TO sme_stock_reader, sme_stock_operator;
GRANT EXECUTE ON FUNCTION sme_stock_demo.fn_record_stock_movement(TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT)
    TO sme_stock_operator;

COMMENT ON SCHEMA sme_stock_demo IS
    'Keep the function owner trusted; runtime operator should have no direct INSERT/UPDATE/DELETE ledger grants.';