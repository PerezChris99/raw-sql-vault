-- Purpose: least-privilege demonstration roles.
-- Engine: PostgreSQL 15+; run as a trusted migration/DBA role.
-- NOLOGIN is intentional: deploy authentication separately.

DO $roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shop_demo_reader') THEN
        CREATE ROLE shop_demo_reader NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shop_demo_checkout') THEN
        CREATE ROLE shop_demo_checkout NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'shop_demo_operator') THEN
        CREATE ROLE shop_demo_operator NOLOGIN;
    END IF;
END;
$roles$;

REVOKE ALL ON SCHEMA shop_demo FROM PUBLIC;
GRANT USAGE ON SCHEMA shop_demo TO shop_demo_reader, shop_demo_checkout, shop_demo_operator;
REVOKE ALL ON ALL TABLES IN SCHEMA shop_demo FROM PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA shop_demo TO shop_demo_reader, shop_demo_checkout, shop_demo_operator;
GRANT EXECUTE ON FUNCTION shop_demo.fn_checkout(BIGINT, CHAR, JSONB, TEXT) TO shop_demo_checkout;
GRANT EXECUTE ON FUNCTION shop_demo.fn_transition_order(BIGINT, TEXT, TEXT) TO shop_demo_operator;

COMMENT ON SCHEMA shop_demo IS
    'Run-time grants are illustrative; production order access needs customer authorization and auditing.';