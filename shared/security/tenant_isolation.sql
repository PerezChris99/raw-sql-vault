-- Stronger PostgreSQL tenant-isolation baseline.
-- Plain language: do not trust a session variable that a caller can edit to
-- decide which tenant they are. Map each authenticated login to one tenant.
-- Technical: session_user is the authenticated login and cannot be changed by
-- SET ROLE. Custom GUCs such as app.current_tenant_id are not authorization.
-- Do not map the shared app_service login to tenants. Use a trusted backend that
-- authenticates users and selects a tenant-specific database login.
-- Runtime roles must not own protected tables or have BYPASSRLS/superuser.
-- Review every other permissive policy: PostgreSQL combines permissive policies with OR.

BEGIN;
CREATE SCHEMA IF NOT EXISTS security;
REVOKE ALL ON SCHEMA security FROM PUBLIC;

CREATE TABLE IF NOT EXISTS security.tenant_login_map (
  login_role name PRIMARY KEY,
  tenant_id text NOT NULL CHECK (length(btrim(tenant_id)) > 0),
  enabled boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT tenant_login_map_role_not_shared CHECK (login_role <> 'app_service')
);
COMMENT ON TABLE security.tenant_login_map IS
'Maps one authenticated PostgreSQL LOGIN role to one tenant; never map a shared multi-tenant login.';
REVOKE ALL ON TABLE security.tenant_login_map FROM PUBLIC;

CREATE OR REPLACE FUNCTION security.current_authenticated_tenant_id()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, security
AS $function$
  SELECT m.tenant_id FROM security.tenant_login_map AS m
  WHERE m.login_role = session_user AND m.enabled
$function$;
COMMENT ON FUNCTION security.current_authenticated_tenant_id() IS
'Returns tenant bound to authenticated session_user; ignores caller-settable custom GUCs.';
REVOKE ALL ON FUNCTION security.current_authenticated_tenant_id() FROM PUBLIC;

CREATE OR REPLACE FUNCTION security.apply_authenticated_tenant_rls(
  p_schema name, p_table name, p_tenant_column name
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, security
AS $function$
DECLARE relation_oid oid; column_exists boolean;
BEGIN
  SELECT c.oid INTO relation_oid
  FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname=p_schema AND c.relname=p_table AND c.relkind IN ('r','p');
  IF relation_oid IS NULL THEN
    RAISE EXCEPTION 'Tenant RLS target %.% is not a table or partitioned table', p_schema, p_table;
  END IF;
  SELECT EXISTS (
    SELECT 1 FROM pg_catalog.pg_attribute a
    WHERE a.attrelid=relation_oid AND a.attname=p_tenant_column
      AND a.attnum>0 AND NOT a.attisdropped
  ) INTO column_exists;
  IF NOT column_exists THEN
    RAISE EXCEPTION 'Tenant column % does not exist on %.%', p_tenant_column, p_schema, p_table;
  END IF;
  EXECUTE pg_catalog.format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', p_schema, p_table);
  EXECUTE pg_catalog.format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', p_schema, p_table);
  EXECUTE pg_catalog.format('DROP POLICY IF EXISTS tenant_authenticated_login_isolation ON %I.%I', p_schema, p_table);
  EXECUTE pg_catalog.format(
    'CREATE POLICY tenant_authenticated_login_isolation ON %I.%I '
    'USING (%I::text = security.current_authenticated_tenant_id()) '
    'WITH CHECK (%I::text = security.current_authenticated_tenant_id())',
    p_schema, p_table, p_tenant_column, p_tenant_column
  );
END
$function$;
REVOKE ALL ON FUNCTION security.apply_authenticated_tenant_rls(name,name,name) FROM PUBLIC;
COMMIT;

-- DBA-controlled grants, after review:
-- GRANT USAGE ON SCHEMA security TO tenant_a_login, tenant_b_login;
-- GRANT EXECUTE ON FUNCTION security.current_authenticated_tenant_id() TO tenant_a_login, tenant_b_login;
-- GRANT EXECUTE ON FUNCTION security.apply_authenticated_tenant_rls(name,name,name) TO migration_role;
-- Never grant the policy-creation function to runtime roles.
-- Example: SELECT security.apply_authenticated_tenant_rls('app','orders','tenant_id');
-- Populate the map via a trusted migration. Unmapped/disabled roles return NULL,
-- so USING/WITH CHECK deny rows. Existing permissive policies must be audited.
