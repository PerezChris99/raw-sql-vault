-- ============================================================================
-- PRODUCTION SECURITY: Audit Infrastructure
-- PostgreSQL 14+
-- ============================================================================
-- Comprehensive audit logging for compliance, forensics, and security monitoring
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- AUDIT SCHEMA (isolated namespace for security)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS audit;
COMMENT ON SCHEMA audit IS 'Security audit logging and forensics';

-- Grant usage to all application roles
GRANT USAGE ON SCHEMA audit TO PUBLIC;

-- ============================================================================
-- CORE AUDIT LOG TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit.activity_log (
    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Timing
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    transaction_id BIGINT DEFAULT txid_current(),
    
    -- Actor identification
    session_user_name TEXT NOT NULL DEFAULT session_user,
    current_user_name TEXT NOT NULL DEFAULT current_user,
    client_addr INET DEFAULT inet_client_addr(),
    client_port INT DEFAULT inet_client_port(),
    application_name TEXT DEFAULT current_setting('application_name', TRUE),
    
    -- Action details
    schema_name TEXT,
    table_name TEXT,
    operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'SELECT', 'DDL', 'LOGIN', 'LOGOUT', 'ERROR', 'SECURITY')),
    
    -- Data capture (JSONB for flexibility)
    old_data JSONB,
    new_data JSONB,
    changed_fields TEXT[],
    
    -- Query forensics
    query_text TEXT,
    query_params JSONB,
    
    -- Risk assessment
    risk_level TEXT DEFAULT 'LOW' CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    risk_flags TEXT[],
    
    -- Context
    request_id UUID,  -- Correlation ID from application
    additional_context JSONB DEFAULT '{}'::JSONB
);

-- Partitioning by month for scalability
CREATE INDEX idx_audit_timestamp ON audit.activity_log (event_timestamp DESC);
CREATE INDEX idx_audit_user ON audit.activity_log (session_user_name, event_timestamp DESC);
CREATE INDEX idx_audit_table ON audit.activity_log (schema_name, table_name, event_timestamp DESC);
CREATE INDEX idx_audit_operation ON audit.activity_log (operation, event_timestamp DESC);
CREATE INDEX idx_audit_risk ON audit.activity_log (risk_level, event_timestamp DESC) WHERE risk_level IN ('HIGH', 'CRITICAL');

-- ============================================================================
-- SECURITY EVENT LOG (authentication, authorization failures)
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit.security_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    event_type TEXT NOT NULL CHECK (event_type IN (
        'LOGIN_SUCCESS', 'LOGIN_FAILURE', 'LOGOUT',
        'ACCESS_DENIED', 'PRIVILEGE_ESCALATION_ATTEMPT',
        'SQL_INJECTION_DETECTED', 'RATE_LIMIT_EXCEEDED',
        'SUSPICIOUS_QUERY', 'DATA_EXFILTRATION_ATTEMPT',
        'SCHEMA_CHANGE', 'ROLE_CHANGE', 'PERMISSION_CHANGE'
    )),
    
    severity TEXT NOT NULL DEFAULT 'INFO' CHECK (severity IN ('INFO', 'WARNING', 'ERROR', 'CRITICAL')),
    
    user_name TEXT,
    client_addr INET,
    
    description TEXT,
    details JSONB DEFAULT '{}'::JSONB,
    
    -- Incident response
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by TEXT,
    acknowledged_at TIMESTAMPTZ,
    resolution_notes TEXT
);

CREATE INDEX idx_security_events_time ON audit.security_events (event_timestamp DESC);
CREATE INDEX idx_security_events_type ON audit.security_events (event_type, event_timestamp DESC);
CREATE INDEX idx_security_events_severity ON audit.security_events (severity) WHERE severity IN ('ERROR', 'CRITICAL');
CREATE INDEX idx_security_events_unacked ON audit.security_events (event_timestamp DESC) WHERE NOT acknowledged;

-- ============================================================================
-- QUERY ANALYTICS (for performance and security monitoring)
-- ============================================================================

CREATE TABLE IF NOT EXISTS audit.query_analytics (
    query_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    query_hash TEXT NOT NULL,  -- MD5 of normalized query
    query_template TEXT NOT NULL,  -- Parameterized query
    
    first_seen TIMESTAMPTZ DEFAULT NOW(),
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    execution_count BIGINT DEFAULT 1,
    
    -- Performance metrics
    total_time_ms NUMERIC DEFAULT 0,
    avg_time_ms NUMERIC GENERATED ALWAYS AS (total_time_ms / NULLIF(execution_count, 0)) STORED,
    min_time_ms NUMERIC,
    max_time_ms NUMERIC,
    
    -- Risk assessment
    is_suspicious BOOLEAN DEFAULT FALSE,
    suspicion_reasons TEXT[],
    is_whitelisted BOOLEAN DEFAULT FALSE,
    whitelisted_by TEXT,
    whitelisted_at TIMESTAMPTZ
);

CREATE UNIQUE INDEX idx_query_analytics_hash ON audit.query_analytics (query_hash);

-- ============================================================================
-- AUDIT TRIGGER FUNCTION (generic for any table)
-- ============================================================================

CREATE OR REPLACE FUNCTION audit.log_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
    v_changed_fields TEXT[];
    v_risk_level TEXT := 'LOW';
    v_risk_flags TEXT[] := '{}';
BEGIN
    -- Capture old/new data
    IF TG_OP = 'DELETE' THEN
        v_old_data := to_jsonb(OLD);
        v_risk_level := 'MEDIUM';  -- Deletes are higher risk
        v_risk_flags := array_append(v_risk_flags, 'DELETE_OPERATION');
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);
        -- Detect changed fields
        SELECT array_agg(key) INTO v_changed_fields
        FROM jsonb_each(v_new_data) n
        WHERE v_old_data->key IS DISTINCT FROM n.value;
        
        -- Check for sensitive field changes
        IF v_changed_fields && ARRAY['password', 'email', 'phone', 'ssn', 'credit_card'] THEN
            v_risk_level := 'HIGH';
            v_risk_flags := array_append(v_risk_flags, 'SENSITIVE_FIELD_CHANGE');
        END IF;
    ELSIF TG_OP = 'INSERT' THEN
        v_new_data := to_jsonb(NEW);
    END IF;
    
    -- Bulk operations are suspicious
    IF (SELECT count(*) FROM audit.activity_log 
        WHERE session_user_name = session_user 
        AND table_name = TG_TABLE_NAME 
        AND event_timestamp > NOW() - INTERVAL '1 minute') > 100 THEN
        v_risk_level := 'HIGH';
        v_risk_flags := array_append(v_risk_flags, 'BULK_OPERATION');
    END IF;
    
    INSERT INTO audit.activity_log (
        schema_name, table_name, operation,
        old_data, new_data, changed_fields,
        risk_level, risk_flags
    ) VALUES (
        TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP,
        v_old_data, v_new_data, v_changed_fields,
        v_risk_level, v_risk_flags
    );
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- HELPER: Enable auditing on a table
-- ============================================================================

CREATE OR REPLACE FUNCTION audit.enable_auditing(
    p_schema_name TEXT,
    p_table_name TEXT
)
RETURNS VOID AS $$
DECLARE
    v_trigger_name TEXT;
BEGIN
    v_trigger_name := 'audit_' || p_table_name || '_trigger';
    
    EXECUTE format(
        'DROP TRIGGER IF EXISTS %I ON %I.%I',
        v_trigger_name, p_schema_name, p_table_name
    );
    
    EXECUTE format(
        'CREATE TRIGGER %I
         AFTER INSERT OR UPDATE OR DELETE ON %I.%I
         FOR EACH ROW EXECUTE FUNCTION audit.log_changes()',
        v_trigger_name, p_schema_name, p_table_name
    );
    
    RAISE NOTICE 'Auditing enabled on %.%', p_schema_name, p_table_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AUDIT LOG RETENTION (auto-cleanup old logs)
-- ============================================================================

CREATE OR REPLACE FUNCTION audit.cleanup_old_logs(
    p_retention_days INT DEFAULT 90
)
RETURNS INT AS $$
DECLARE
    v_deleted INT;
BEGIN
    -- Archive to cold storage first (implement based on your storage)
    -- COPY audit.activity_log TO '/archive/audit_YYYYMMDD.csv' ...
    
    DELETE FROM audit.activity_log 
    WHERE event_timestamp < NOW() - (p_retention_days || ' days')::INTERVAL
    AND risk_level NOT IN ('HIGH', 'CRITICAL');  -- Keep high-risk logs longer
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    
    -- Log the cleanup itself
    INSERT INTO audit.activity_log (
        operation, schema_name, table_name,
        additional_context
    ) VALUES (
        'DDL', 'audit', 'activity_log',
        jsonb_build_object('action', 'cleanup', 'deleted_rows', v_deleted)
    );
    
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AUDIT VIEWS (for dashboards and monitoring)
-- ============================================================================

CREATE OR REPLACE VIEW audit.recent_high_risk AS
SELECT 
    event_timestamp,
    session_user_name,
    client_addr,
    schema_name || '.' || table_name AS target,
    operation,
    risk_level,
    risk_flags,
    query_text
FROM audit.activity_log
WHERE risk_level IN ('HIGH', 'CRITICAL')
AND event_timestamp > NOW() - INTERVAL '24 hours'
ORDER BY event_timestamp DESC;

CREATE OR REPLACE VIEW audit.user_activity_summary AS
SELECT 
    session_user_name,
    COUNT(*) AS total_actions,
    COUNT(*) FILTER (WHERE operation = 'SELECT') AS reads,
    COUNT(*) FILTER (WHERE operation IN ('INSERT', 'UPDATE', 'DELETE')) AS writes,
    COUNT(*) FILTER (WHERE risk_level IN ('HIGH', 'CRITICAL')) AS high_risk_actions,
    MIN(event_timestamp) AS first_action,
    MAX(event_timestamp) AS last_action
FROM audit.activity_log
WHERE event_timestamp > NOW() - INTERVAL '7 days'
GROUP BY session_user_name
ORDER BY high_risk_actions DESC, total_actions DESC;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Restrict direct access to audit tables
REVOKE ALL ON audit.activity_log FROM PUBLIC;
REVOKE ALL ON audit.security_events FROM PUBLIC;

-- Only superusers and security_admin can query audit logs
-- (Create security_admin role in 01_rbac_roles.sql)

COMMENT ON TABLE audit.activity_log IS 'Comprehensive audit trail for all database operations';
COMMENT ON TABLE audit.security_events IS 'Security-specific events requiring attention';
COMMENT ON FUNCTION audit.log_changes() IS 'Trigger function to capture all data changes';
