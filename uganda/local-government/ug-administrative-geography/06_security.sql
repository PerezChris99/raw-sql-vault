-- Purpose: least-privilege reference-data roles.
-- Engine: PostgreSQL 15+. Prerequisite: schema owner has role-creation privilege.
-- Safe to re-run in a disposable/admin-controlled environment; creates roles.
DO $roles$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_admin_ref_reader') THEN CREATE ROLE ug_admin_ref_reader NOLOGIN; END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_admin_ref_steward') THEN CREATE ROLE ug_admin_ref_steward NOLOGIN; END IF;
END;
$roles$;
REVOKE ALL ON SCHEMA ug_admin_ref FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_admin_ref TO ug_admin_ref_reader,ug_admin_ref_steward;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_admin_ref FROM PUBLIC;
GRANT SELECT ON ug_admin_ref.admin_units,ug_admin_ref.allowed_parent_levels,
                ug_admin_ref.v_current_units,ug_admin_ref.v_unit_tree
TO ug_admin_ref_reader;
GRANT SELECT ON ug_admin_ref.admin_unit_changes TO ug_admin_ref_steward;
GRANT SELECT,INSERT,UPDATE ON ug_admin_ref.admin_units,ug_admin_ref.admin_unit_changes TO ug_admin_ref_steward;
GRANT SELECT ON ug_admin_ref.allowed_parent_levels TO ug_admin_ref_steward;
REVOKE ALL ON FUNCTION ug_admin_ref.fn_retire_unit(TEXT,DATE,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_admin_ref.fn_get_ancestors(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ug_admin_ref.fn_get_ancestors(BIGINT) TO ug_admin_ref_reader,ug_admin_ref_steward;
GRANT EXECUTE ON FUNCTION ug_admin_ref.fn_retire_unit(TEXT,DATE,TEXT,TEXT,TEXT) TO ug_admin_ref_steward;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_admin_ref FROM PUBLIC;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA ug_admin_ref TO ug_admin_ref_steward;
-- Role creation/ownership is an administrator task. Runtime roles must not own this schema.
