-- ============================================================================
-- PRODUCTION SECURITY: Row-Level Security (RLS)
-- PostgreSQL 14+
-- ============================================================================
-- Implements fine-grained access control at the row level
-- Essential for multi-tenant applications and data isolation
-- ============================================================================

-- ============================================================================
-- TENANT ISOLATION PATTERN
-- ============================================================================
-- For multi-tenant applications where each tenant sees only their data

-- REQUEST CONTEXT TRUST BOUNDARY
-- Plain language: trusted application code supplies the tenant for the current request;
-- the connector clears it at transaction end so a pooled connection cannot leak it.
-- If an untrusted person can run arbitrary SQL as the shared application role, they can
-- choose a custom setting themselves. Do not expose this database role directly to users.
-- Technical: custom GUCs are caller-settable, so these helpers are defense in depth,
-- not an identity provider or protection against arbitrary SQL under app_service.

CREATE OR REPLACE FUNCTION security.current_tenant_id()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(
        current_setting('app.current_tenant_id', TRUE),
        ''
    );
END;
$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- USER CONTEXT PATTERN  
-- ============================================================================
-- For user-specific data access

CREATE OR REPLACE FUNCTION security.current_app_user_id()
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(
        current_setting('app.current_user_id', TRUE),
        ''
    );
END;
$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- ROLE-BASED ACCESS PATTERN
-- ============================================================================

-- Retained for display/diagnostics only; never use this value to grant privileges.
CREATE OR REPLACE FUNCTION security.current_app_roles()
RETURNS TEXT[] AS $$
BEGIN
    RETURN string_to_array(
        COALESCE(current_setting('app.current_roles', TRUE), ''),
        ','
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION security.has_app_role(p_role TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    -- Privileged decisions use database-authenticated membership only. A caller can
    -- set app.current_roles to any string, so it must never grant administrator access.
    RETURN EXISTS (
        SELECT 1
        FROM pg_catalog.pg_auth_members AS am
        JOIN pg_catalog.pg_roles AS granted_role ON granted_role.oid = am.roleid
        JOIN pg_catalog.pg_roles AS member_role ON member_role.oid = am.member
        WHERE granted_role.rolname = p_role
          AND member_role.rolname = session_user
    ) OR session_user = p_role;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- RLS HELPER: Enable RLS on a table with tenant isolation
-- ============================================================================

CREATE OR REPLACE FUNCTION security.enable_tenant_rls(
    p_schema_name TEXT,
    p_table_name TEXT,
    p_tenant_column TEXT DEFAULT 'tenant_id'
)
RETURNS VOID AS $$
DECLARE
    v_policy_name TEXT;
BEGIN
    -- Enable RLS on the table
    EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', p_schema_name, p_table_name);
    
    -- Force RLS even for table owners
    EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', p_schema_name, p_table_name);
    
    -- Drop existing policy if any
    v_policy_name := p_table_name || '_tenant_isolation';
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', v_policy_name, p_schema_name, p_table_name);
    
    -- Create tenant isolation policy
    EXECUTE format(
        'CREATE POLICY %I ON %I.%I
         FOR ALL
         USING (%I::TEXT = security.current_tenant_id())
         WITH CHECK (%I::TEXT = security.current_tenant_id())',
        v_policy_name, p_schema_name, p_table_name, p_tenant_column, p_tenant_column
    );
    
    RAISE NOTICE 'RLS enabled on %.% with tenant isolation on column %', 
        p_schema_name, p_table_name, p_tenant_column;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- RLS HELPER: Enable user-based RLS
-- ============================================================================

CREATE OR REPLACE FUNCTION security.enable_user_rls(
    p_schema_name TEXT,
    p_table_name TEXT,
    p_user_column TEXT DEFAULT 'user_id',
    p_allow_admin BOOLEAN DEFAULT TRUE
)
RETURNS VOID AS $$
DECLARE
    v_policy_name TEXT;
BEGIN
    -- Enable RLS
    EXECUTE format('ALTER TABLE %I.%I ENABLE ROW LEVEL SECURITY', p_schema_name, p_table_name);
    EXECUTE format('ALTER TABLE %I.%I FORCE ROW LEVEL SECURITY', p_schema_name, p_table_name);
    
    -- p_allow_admin is retained for call-site compatibility only. It is deliberately
    -- not used: generic RLS helpers must not create implicit administrator bypasses.
    -- If an exception is required, add a separate policy for a database-authenticated
    -- role after an explicit review of the data and operational threat model.
    
    -- Drop existing policy
    v_policy_name := p_table_name || '_user_isolation';
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', v_policy_name, p_schema_name, p_table_name);
    
    -- Create user isolation policy
    EXECUTE format(
        'CREATE POLICY %I ON %I.%I
         FOR ALL
         USING (%I::TEXT = security.current_app_user_id())
         WITH CHECK (%I::TEXT = security.current_app_user_id())',
        v_policy_name, p_schema_name, p_table_name,
        p_user_column,
        p_user_column
    );
    
    RAISE NOTICE 'RLS enabled on %.% with user isolation on column %', 
        p_schema_name, p_table_name, p_user_column;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- RLS HELPER: Create read-only policy for specific roles
-- ============================================================================

CREATE OR REPLACE FUNCTION security.add_readonly_policy(
    p_schema_name TEXT,
    p_table_name TEXT,
    p_role_name TEXT
)
RETURNS VOID AS $$
DECLARE
    v_policy_name TEXT;
BEGIN
    v_policy_name := p_table_name || '_readonly_' || p_role_name;
    
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', v_policy_name, p_schema_name, p_table_name);
    
    EXECUTE format(
        'CREATE POLICY %I ON %I.%I
         FOR SELECT
         TO %I
         USING (TRUE)',
        v_policy_name, p_schema_name, p_table_name, p_role_name
    );
    
    RAISE NOTICE 'Read-only policy added for role % on %.%', 
        p_role_name, p_schema_name, p_table_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COLUMN-LEVEL SECURITY (Sensitive Data Masking)
-- ============================================================================

-- Create a view that masks sensitive data based on role
CREATE OR REPLACE FUNCTION security.mask_pii(
    p_value TEXT,
    p_type TEXT DEFAULT 'default'
)
RETURNS TEXT AS $$
BEGIN
    -- Privileged visibility is based on actual database-role membership, never caller-set text.
    IF security.has_app_role('admin') OR security.has_app_role('data_admin') THEN
        RETURN p_value;
    END IF;
    
    -- Mask based on type
    CASE p_type
        WHEN 'email' THEN
            RETURN CASE 
                WHEN p_value IS NULL THEN NULL
                WHEN position('@' in p_value) > 2 THEN
                    left(p_value, 2) || '***@' || split_part(p_value, '@', 2)
                ELSE '***@***'
            END;
        WHEN 'phone' THEN
            RETURN CASE 
                WHEN p_value IS NULL THEN NULL
                ELSE '***-***-' || right(p_value, 4)
            END;
        WHEN 'ssn' THEN
            RETURN '***-**-' || right(COALESCE(p_value, '0000'), 4);
        WHEN 'credit_card' THEN
            RETURN '****-****-****-' || right(COALESCE(p_value, '0000'), 4);
        WHEN 'name' THEN
            RETURN CASE 
                WHEN p_value IS NULL THEN NULL
                ELSE left(p_value, 1) || '***'
            END;
        ELSE
            RETURN '***MASKED***';
    END CASE;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- DATA CLASSIFICATION LABELS
-- ============================================================================

CREATE TABLE IF NOT EXISTS security.data_classification (
    classification_id SERIAL PRIMARY KEY,
    schema_name TEXT NOT NULL,
    table_name TEXT NOT NULL,
    column_name TEXT NOT NULL,
    classification TEXT NOT NULL CHECK (classification IN (
        'public',           -- No restrictions
        'internal',         -- Internal use only
        'confidential',     -- Restricted access
        'pii',             -- Personal Identifiable Information
        'phi',             -- Protected Health Information
        'pci'              -- Payment Card Industry data
    )),
    data_type TEXT,  -- email, phone, ssn, etc.
    requires_encryption BOOLEAN DEFAULT FALSE,
    requires_masking BOOLEAN DEFAULT FALSE,
    retention_days INT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (schema_name, table_name, column_name)
);

-- ============================================================================
-- HELPER: Classify a column
-- ============================================================================

CREATE OR REPLACE FUNCTION security.classify_column(
    p_schema_name TEXT,
    p_table_name TEXT,
    p_column_name TEXT,
    p_classification TEXT,
    p_data_type TEXT DEFAULT NULL,
    p_requires_encryption BOOLEAN DEFAULT FALSE,
    p_requires_masking BOOLEAN DEFAULT FALSE
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO security.data_classification (
        schema_name, table_name, column_name, 
        classification, data_type, 
        requires_encryption, requires_masking
    ) VALUES (
        p_schema_name, p_table_name, p_column_name,
        p_classification, p_data_type,
        p_requires_encryption, p_requires_masking
    )
    ON CONFLICT (schema_name, table_name, column_name) 
    DO UPDATE SET
        classification = EXCLUDED.classification,
        data_type = EXCLUDED.data_type,
        requires_encryption = EXCLUDED.requires_encryption,
        requires_masking = EXCLUDED.requires_masking;
        
    RAISE NOTICE 'Column %.%.% classified as %', 
        p_schema_name, p_table_name, p_column_name, p_classification;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- EXAMPLE: Setting up RLS for a typical application
-- ============================================================================

-- Example: Creating a tenant-isolated orders table
/*
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    tenant_id INT NOT NULL,
    user_id INT NOT NULL,
    order_date TIMESTAMPTZ DEFAULT NOW(),
    total NUMERIC(10,2)
);

-- Enable tenant isolation
SELECT security.enable_tenant_rls('public', 'orders', 'tenant_id');

-- Usage in application:
-- SET app.current_tenant_id = '42';
-- SET app.current_user_id = '123';
-- Do not use app.current_roles for authorization: a caller can set this custom GUC.
-- SELECT * FROM orders;  -- Only sees tenant 42's orders

-- Classify sensitive columns
SELECT security.classify_column('public', 'users', 'email', 'pii', 'email', FALSE, TRUE);
SELECT security.classify_column('public', 'users', 'phone', 'pii', 'phone', FALSE, TRUE);
*/

COMMENT ON FUNCTION security.enable_tenant_rls IS 'Enable row-level security with tenant isolation';
COMMENT ON FUNCTION security.enable_user_rls IS 'Enable row-level security with user isolation';
COMMENT ON FUNCTION security.mask_pii IS 'Mask sensitive data based on user role';
