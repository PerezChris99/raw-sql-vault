-- ============================================================================
-- PRODUCTION SECURITY: Role-Based Access Control (RBAC)
-- PostgreSQL 14+
-- ============================================================================
-- Implements principle of least privilege with defense-in-depth
-- ============================================================================

-- ============================================================================
-- ROLE HIERARCHY
-- ============================================================================
-- 
--                    ┌─────────────────┐
--                    │   superuser     │ (DBA only)
--                    └────────┬────────┘
--                             │
--              ┌──────────────┼──────────────┐
--              ▼              ▼              ▼
--    ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
--    │security_admin│  │ app_admin   │  │backup_admin │
--    └──────┬──────┘  └──────┬──────┘  └─────────────┘
--           │                │
--           │         ┌──────┴──────┐
--           │         ▼             ▼
--           │   ┌──────────┐  ┌──────────┐
--           │   │ app_write│  │ app_read │
--           │   └────┬─────┘  └──────────┘
--           │        │
--           │        ▼
--           │   ┌──────────┐
--           │   │ app_user │ (default application role)
--           │   └──────────┘
--           │
--           ▼
--    ┌─────────────┐
--    │ audit_viewer│ (read-only audit access)
--    └─────────────┘
-- ============================================================================

-- Do not drop/reassign application roles during an idempotent bootstrap.
-- Plain language: dropping ownership or grants during a rerun can unexpectedly break
-- an existing deployment. This script creates missing roles and adjusts intended grants;
-- destructive role migrations require a separately reviewed, explicit migration.

-- ============================================================================
-- CREATE BASE ROLES (NOLOGIN - these are role groups)
-- ============================================================================

-- Security Administrator - manages security policies, views audit logs
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'security_admin') THEN
        CREATE ROLE security_admin NOLOGIN;
    END IF;
END $$;
COMMENT ON ROLE security_admin IS 'Security administration and audit access';

-- Application Administrator - manages application schema and data
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_admin') THEN
        CREATE ROLE app_admin NOLOGIN;
    END IF;
END $$;
COMMENT ON ROLE app_admin IS 'Application schema and data administration';

-- Backup Administrator - read-only access for backups
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'backup_admin') THEN
        CREATE ROLE backup_admin NOLOGIN;
    END IF;
END $$;
COMMENT ON ROLE backup_admin IS 'Read-only backup access';

-- Application Write - can INSERT, UPDATE, DELETE application data
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_write') THEN
        CREATE ROLE app_write NOLOGIN;
    END IF;
END $$;
COMMENT ON ROLE app_write IS 'Application data modification';

-- Application Read - SELECT only on application data
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'app_read') THEN
        CREATE ROLE app_read NOLOGIN;
    END IF;
END $$;
COMMENT ON ROLE app_read IS 'Read-only application access';

-- Audit Viewer - can view audit logs (for compliance)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'audit_viewer') THEN
        CREATE ROLE audit_viewer NOLOGIN;
    END IF;
END $$;
COMMENT ON ROLE audit_viewer IS 'Audit log read access';

-- ============================================================================
-- ROLE INHERITANCE
-- ============================================================================

GRANT app_read TO app_write;        -- Writers can also read
GRANT app_write TO app_admin;       -- Admins can write
GRANT audit_viewer TO security_admin; -- Security admins can view audits

-- ============================================================================
-- CREATE LOGIN ROLES (actual users/services)
-- ============================================================================
-- These roles intentionally have NO embedded/default password. Provision credentials
-- out-of-band using a secret manager or controlled DBA workflow, then rotate them.
-- Plain language: source code is public-readable; a known example password becomes
-- a real vulnerability if someone executes this file unchanged.
-- Technical: LOGIN roles without a password cannot authenticate with password auth
-- until provisioned. Configure SCRAM secrets and TLS in the deployment environment.
-- If an older copy of this script was run, rotate/revoke the previously known password
-- through a planned DBA operation; this idempotent bootstrap does not silently rotate it.
-- Do not store secrets in this SQL file or in Git history.

-- Application service account (used by backend)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_service') THEN
        CREATE ROLE app_service LOGIN;
    END IF;
END $$;
GRANT app_write TO app_service;
ALTER ROLE app_service SET statement_timeout = '30s';
ALTER ROLE app_service SET lock_timeout = '10s';
COMMENT ON ROLE app_service IS 'Backend application service account';

-- Read-only replica/reporting account
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_readonly') THEN
        CREATE ROLE app_readonly LOGIN;
    END IF;
END $$;
GRANT app_read TO app_readonly;
ALTER ROLE app_readonly SET statement_timeout = '60s';  -- Allow longer for reports
COMMENT ON ROLE app_readonly IS 'Read-only reporting and analytics';

-- Security admin account
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'security_user') THEN
        CREATE ROLE security_user LOGIN;
    END IF;
END $$;
GRANT security_admin TO security_user;
COMMENT ON ROLE security_user IS 'Security administration user';

-- Backup service account
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'backup_service') THEN
        CREATE ROLE backup_service LOGIN;
    END IF;
END $$;
GRANT backup_admin TO backup_service;
ALTER ROLE backup_service SET statement_timeout = '0';  -- No timeout for backups
COMMENT ON ROLE backup_service IS 'Backup service account';

-- ============================================================================
-- SCHEMA PERMISSIONS
-- ============================================================================

-- Public schema (application data)
GRANT USAGE ON SCHEMA public TO app_read;
GRANT USAGE ON SCHEMA public TO app_write;
GRANT ALL ON SCHEMA public TO app_admin;

-- Audit schema (restricted)
GRANT USAGE ON SCHEMA audit TO security_admin;
GRANT USAGE ON SCHEMA audit TO audit_viewer;
REVOKE ALL ON SCHEMA audit FROM PUBLIC;

-- ============================================================================
-- DEFAULT PRIVILEGES (for future tables)
-- ============================================================================

-- Set default privileges for app_admin (who creates tables)
ALTER DEFAULT PRIVILEGES FOR ROLE app_admin IN SCHEMA public
    GRANT SELECT ON TABLES TO app_read;

ALTER DEFAULT PRIVILEGES FOR ROLE app_admin IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_write;

ALTER DEFAULT PRIVILEGES FOR ROLE app_admin IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO app_write;

-- ============================================================================
-- FUNCTION TO GRANT STANDARD PERMISSIONS ON EXISTING TABLES
-- ============================================================================

CREATE OR REPLACE FUNCTION security.grant_standard_permissions(
    p_schema_name TEXT DEFAULT 'public'
)
RETURNS VOID AS $$
DECLARE
    r RECORD;
BEGIN
    -- Grant SELECT on all tables to app_read
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = p_schema_name LOOP
        EXECUTE format('GRANT SELECT ON %I.%I TO app_read', p_schema_name, r.tablename);
        EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON %I.%I TO app_write', p_schema_name, r.tablename);
        EXECUTE format('GRANT ALL ON %I.%I TO app_admin', p_schema_name, r.tablename);
    END LOOP;
    
    -- Grant on sequences
    FOR r IN SELECT sequencename FROM pg_sequences WHERE schemaname = p_schema_name LOOP
        EXECUTE format('GRANT USAGE, SELECT ON SEQUENCE %I.%I TO app_write', p_schema_name, r.sequencename);
    END LOOP;
    
    RAISE NOTICE 'Standard permissions granted on schema %', p_schema_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECURITY SCHEMA FOR HELPER FUNCTIONS
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS security;
COMMENT ON SCHEMA security IS 'Security helper functions and utilities';

-- ============================================================================
-- PASSWORD POLICY ENFORCEMENT
-- ============================================================================

CREATE OR REPLACE FUNCTION security.validate_password(
    p_password TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    -- Minimum 12 characters
    IF length(p_password) < 12 THEN
        RAISE EXCEPTION 'Password must be at least 12 characters';
    END IF;
    
    -- Must contain uppercase
    IF p_password !~ '[A-Z]' THEN
        RAISE EXCEPTION 'Password must contain uppercase letter';
    END IF;
    
    -- Must contain lowercase
    IF p_password !~ '[a-z]' THEN
        RAISE EXCEPTION 'Password must contain lowercase letter';
    END IF;
    
    -- Must contain number
    IF p_password !~ '[0-9]' THEN
        RAISE EXCEPTION 'Password must contain number';
    END IF;
    
    -- Must contain special character
    IF p_password !~ '[!@#$%^&*()_+\-=\[\]{};:,.<>?]' THEN
        RAISE EXCEPTION 'Password must contain special character';
    END IF;
    
    -- Check against common passwords (expand this list)
    IF lower(p_password) IN ('password123!', 'admin123!abc', 'changeme123!') THEN
        RAISE EXCEPTION 'Password is too common';
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ROLE MEMBERSHIP CHECK (for application use)
-- ============================================================================

CREATE OR REPLACE FUNCTION security.has_role(
    p_role_name TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM pg_auth_members am
        JOIN pg_roles r ON am.roleid = r.oid
        JOIN pg_roles m ON am.member = m.oid
        WHERE r.rolname = p_role_name
        AND m.rolname = current_user
    ) OR current_user = p_role_name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- GRANT AUDIT PERMISSIONS
-- ============================================================================

GRANT SELECT ON audit.activity_log TO security_admin;
GRANT SELECT ON audit.security_events TO security_admin;
GRANT SELECT ON audit.query_analytics TO security_admin;
GRANT SELECT ON audit.recent_high_risk TO security_admin;
GRANT SELECT ON audit.user_activity_summary TO security_admin;

GRANT SELECT ON audit.activity_log TO audit_viewer;
GRANT SELECT ON audit.security_events TO audit_viewer;

-- Backup can read all for backup purposes
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backup_admin;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO backup_admin;

-- ============================================================================
-- CONNECTION LIMITS (DoS protection)
-- ============================================================================

ALTER ROLE app_service CONNECTION LIMIT 50;
ALTER ROLE app_readonly CONNECTION LIMIT 20;
ALTER ROLE backup_service CONNECTION LIMIT 5;
ALTER ROLE security_user CONNECTION LIMIT 3;

-- ============================================================================
-- SUMMARY
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'RBAC Configuration Complete';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Roles created:';
    RAISE NOTICE '  - app_service (backend application)';
    RAISE NOTICE '  - app_readonly (reporting/analytics)';
    RAISE NOTICE '  - security_user (security admin)';
    RAISE NOTICE '  - backup_service (backup operations)';
    RAISE NOTICE '';
    RAISE NOTICE 'IMPORTANT: provision login credentials out-of-band before enabling applications.';
    RAISE NOTICE '==========================================';
END $$;
