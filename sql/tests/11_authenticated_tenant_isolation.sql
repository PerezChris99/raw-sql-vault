-- Run as a trusted PostgreSQL superuser/DBA on a disposable database only.
-- SET SESSION AUTHORIZATION emulates distinct authenticated logins; ordinary
-- application roles cannot set another session authorization. All data rolls back.
\set ON_ERROR_STOP on
BEGIN;
CREATE ROLE rsv_tenant_a_test LOGIN;
CREATE ROLE rsv_tenant_b_test LOGIN;
CREATE SCHEMA rsv_tenant_test;
INSERT INTO security.tenant_login_map (login_role,tenant_id,enabled)
VALUES ('rsv_tenant_a_test','tenant-a',true),('rsv_tenant_b_test','tenant-b',true)
ON CONFLICT (login_role) DO UPDATE SET tenant_id=EXCLUDED.tenant_id, enabled=EXCLUDED.enabled;
CREATE TABLE rsv_tenant_test.records (
  record_id integer PRIMARY KEY, tenant_id text NOT NULL, payload text NOT NULL
);
INSERT INTO rsv_tenant_test.records VALUES (1,'tenant-a','synthetic A'),(2,'tenant-b','synthetic B');
SELECT security.apply_authenticated_tenant_rls('rsv_tenant_test','records','tenant_id');
GRANT USAGE ON SCHEMA security, rsv_tenant_test TO rsv_tenant_a_test, rsv_tenant_b_test;
GRANT EXECUTE ON FUNCTION security.current_authenticated_tenant_id() TO rsv_tenant_a_test, rsv_tenant_b_test;
GRANT SELECT,INSERT,UPDATE,DELETE ON rsv_tenant_test.records TO rsv_tenant_a_test, rsv_tenant_b_test;

SET SESSION AUTHORIZATION rsv_tenant_a_test;
DO $test$
DECLARE actual_count integer;
BEGIN
  SELECT count(*) INTO actual_count FROM rsv_tenant_test.records;
  IF actual_count <> 1 THEN RAISE EXCEPTION 'Tenant A should see one row; observed %',actual_count; END IF;
  PERFORM pg_catalog.set_config('app.current_tenant_id','tenant-b',true);
  SELECT count(*) INTO actual_count FROM rsv_tenant_test.records;
  IF actual_count <> 1 THEN RAISE EXCEPTION 'Changing a custom GUC changed tenant visibility'; END IF;
  BEGIN
    INSERT INTO rsv_tenant_test.records VALUES (3,'tenant-b','must be rejected');
    RAISE EXCEPTION 'Cross-tenant INSERT unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
END
$test$;
RESET SESSION AUTHORIZATION;

SET SESSION AUTHORIZATION rsv_tenant_b_test;
DO $test$
DECLARE actual_count integer;
BEGIN
  SELECT count(*) INTO actual_count FROM rsv_tenant_test.records;
  IF actual_count <> 1 THEN RAISE EXCEPTION 'Tenant B should see one row; observed %',actual_count; END IF;
END
$test$;
RESET SESSION AUTHORIZATION;
ROLLBACK;
