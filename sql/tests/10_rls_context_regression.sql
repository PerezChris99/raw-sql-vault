-- RLS context regression test for PostgreSQL 14+.
-- Run only on a disposable database after applying the shared RBAC and RLS setup
-- with a trusted DBA role:
-- psql "$DATABASE_URL" -X -v ON_ERROR_STOP=1 -f sql/tests/10_rls_context_regression.sql
--
-- Plain language: the first assertion makes sure the word "admin" in a custom
-- setting cannot show another tenant's rows. The second assertion deliberately
-- demonstrates the trust boundary: someone who can issue arbitrary SQL as the
-- shared application role can change the tenant setting. Do not expose that role
-- directly to untrusted users.
--
-- Technical: custom GUCs are caller-settable. This test validates the absence of
-- a GUC-based admin bypass, and documents that the shared-role pattern is not an
-- authorization boundary against arbitrary SQL. The whole test rolls back.

\set ON_ERROR_STOP on
BEGIN;

CREATE SCHEMA raw_sql_vault_security_test;
CREATE TABLE raw_sql_vault_security_test.tenant_probe (
    probe_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_id TEXT NOT NULL,
    payload TEXT NOT NULL
);

INSERT INTO raw_sql_vault_security_test.tenant_probe (tenant_id, payload)
VALUES ('tenant-a', 'synthetic-a'), ('tenant-b', 'synthetic-b');

GRANT USAGE ON SCHEMA raw_sql_vault_security_test TO app_service;
GRANT USAGE ON SCHEMA security TO app_service;
GRANT SELECT ON raw_sql_vault_security_test.tenant_probe TO app_service;

SELECT security.enable_tenant_rls('raw_sql_vault_security_test', 'tenant_probe', 'tenant_id');

SET ROLE app_service;
SET app.current_roles = 'admin';
SET app.current_tenant_id = 'tenant-a';

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*) INTO v_count
    FROM raw_sql_vault_security_test.tenant_probe;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'RLS GUC-admin regression: expected 1 tenant-a row, observed %', v_count;
    END IF;
END $$;

-- Deliberate trust-boundary demonstration: the shared role can set a different
-- tenant GUC if it can run arbitrary SQL. This must not be mistaken for isolation
-- from SQL injection or direct database access.
SET app.current_tenant_id = 'tenant-b';
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT count(*) INTO v_count
    FROM raw_sql_vault_security_test.tenant_probe;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Expected demonstration of caller-settable tenant context; observed % rows', v_count;
    END IF;
END $$;

RESET ROLE;
ROLLBACK;
