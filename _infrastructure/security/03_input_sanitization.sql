-- ============================================================================
-- PRODUCTION SECURITY: Input Sanitization & SQL Injection Prevention
-- PostgreSQL 14+
-- ============================================================================
-- Defense-in-depth against injection attacks, both known and unknown
-- ============================================================================

-- ============================================================================
-- SQL INJECTION DETECTION PATTERNS
-- ============================================================================

CREATE TABLE IF NOT EXISTS security.injection_patterns (
    pattern_id SERIAL PRIMARY KEY,
    pattern_name TEXT UNIQUE NOT NULL,
    pattern_regex TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    false_positive_rate NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert known SQL injection patterns
INSERT INTO security.injection_patterns (pattern_name, pattern_regex, severity, description) VALUES
-- Classic SQL injection
('union_select', '(?i)\bunion\b.*\bselect\b', 'CRITICAL', 'UNION-based SQL injection'),
('or_1_equals_1', '(?i)\bor\b\s+[''"]?1[''"]?\s*=\s*[''"]?1', 'CRITICAL', 'OR 1=1 tautology attack'),
('and_1_equals_1', '(?i)\band\b\s+[''"]?1[''"]?\s*=\s*[''"]?1', 'HIGH', 'AND 1=1 tautology attack'),
('comment_injection', '--\s*$|/\*|\*/', 'HIGH', 'SQL comment injection'),
('semicolon_stacking', ';\s*(drop|delete|truncate|update|insert|alter|create)', 'CRITICAL', 'Statement stacking attack'),

-- Time-based blind injection
('sleep_injection', '(?i)\b(sleep|pg_sleep|waitfor|benchmark)\s*\(', 'CRITICAL', 'Time-based blind injection'),
('delay_injection', '(?i)\bdelay\b.*\bfor\b', 'HIGH', 'WAITFOR DELAY injection'),

-- Error-based injection
('extractvalue', '(?i)\b(extractvalue|updatexml|xmltype)\s*\(', 'HIGH', 'XML error-based injection'),
('convert_injection', '(?i)\bconvert\s*\(\s*int', 'MEDIUM', 'Type conversion injection'),

-- PostgreSQL specific
('pg_dump', '(?i)\bpg_(dump|restore|catalog|shadow|user)\b', 'CRITICAL', 'PostgreSQL system access attempt'),
('copy_to', '(?i)\bcopy\b.*\bto\b.*\bprogram\b', 'CRITICAL', 'COPY TO PROGRAM injection'),
('lo_import', '(?i)\blo_(import|export)\s*\(', 'CRITICAL', 'Large object exploitation'),

-- Information schema probing
('info_schema', '(?i)\b(information_schema|pg_catalog)\b', 'MEDIUM', 'Schema enumeration'),
('version_probe', '(?i)\b(version|@@version|pg_version)\b', 'LOW', 'Version detection'),

-- Privilege escalation
('grant_revoke', '(?i)\b(grant|revoke)\b.*\b(all|select|insert|update|delete)\b', 'CRITICAL', 'Privilege modification attempt'),
('create_role', '(?i)\bcreate\s+(role|user)\b', 'CRITICAL', 'Role creation attempt'),
('alter_role', '(?i)\balter\s+(role|user)\b', 'CRITICAL', 'Role modification attempt'),

-- NoSQL/JSON injection
('json_extract', '(?i)->>|#>>|jsonb?_extract', 'LOW', 'JSON extraction (monitor for abuse)'),

-- Hex/encoded attacks
('hex_encoding', '0x[0-9a-fA-F]+', 'MEDIUM', 'Hex-encoded payload'),
('char_encoding', '(?i)\bchar\s*\(\s*\d+\s*\)', 'MEDIUM', 'CHAR() encoding attack'),

-- XSS via SQL (if data displayed in web)
('script_tag', '(?i)<\s*script', 'HIGH', 'Potential XSS payload'),

-- Path traversal
('path_traversal', '\.\./|\.\.\\', 'HIGH', 'Directory traversal attempt')

ON CONFLICT (pattern_name) DO UPDATE SET
    pattern_regex = EXCLUDED.pattern_regex,
    severity = EXCLUDED.severity;

-- ============================================================================
-- INJECTION DETECTION FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION security.detect_injection(
    p_input TEXT,
    p_context TEXT DEFAULT 'query'
)
RETURNS TABLE (
    is_suspicious BOOLEAN,
    threat_level TEXT,
    detected_patterns TEXT[],
    details JSONB
) AS $$
DECLARE
    v_is_suspicious BOOLEAN := FALSE;
    v_threat_level TEXT := 'NONE';
    v_detected_patterns TEXT[] := '{}';
    v_details JSONB := '[]'::JSONB;
    v_pattern RECORD;
    v_severity_order TEXT[] := ARRAY['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'];
BEGIN
    -- Check against all active patterns
    FOR v_pattern IN 
        SELECT * FROM security.injection_patterns WHERE is_active = TRUE
    LOOP
        IF p_input ~* v_pattern.pattern_regex THEN
            v_is_suspicious := TRUE;
            v_detected_patterns := array_append(v_detected_patterns, v_pattern.pattern_name);
            v_details := v_details || jsonb_build_object(
                'pattern', v_pattern.pattern_name,
                'severity', v_pattern.severity,
                'description', v_pattern.description
            );
            
            -- Update threat level to highest detected
            IF array_position(v_severity_order, v_pattern.severity) > 
               COALESCE(array_position(v_severity_order, v_threat_level), 0) THEN
                v_threat_level := v_pattern.severity;
            END IF;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT v_is_suspicious, v_threat_level, v_detected_patterns, v_details;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ============================================================================
-- INPUT SANITIZATION FUNCTIONS
-- ============================================================================

-- Sanitize string input (removes dangerous characters)
CREATE OR REPLACE FUNCTION security.sanitize_string(
    p_input TEXT,
    p_max_length INT DEFAULT 1000,
    p_allow_html BOOLEAN DEFAULT FALSE
)
RETURNS TEXT AS $$
DECLARE
    v_result TEXT;
BEGIN
    IF p_input IS NULL THEN
        RETURN NULL;
    END IF;
    
    v_result := p_input;
    
    -- Truncate to max length
    v_result := left(v_result, p_max_length);
    
    -- Remove null bytes
    v_result := replace(v_result, E'\x00', '');
    
    -- Remove SQL comments
    v_result := regexp_replace(v_result, '--.*$', '', 'gm');
    v_result := regexp_replace(v_result, '/\*.*?\*/', '', 'g');
    
    -- Escape single quotes (double them)
    v_result := replace(v_result, '''', '''''');
    
    -- Remove HTML if not allowed
    IF NOT p_allow_html THEN
        v_result := regexp_replace(v_result, '<[^>]*>', '', 'g');
    END IF;
    
    -- Remove control characters (except newline, tab)
    v_result := regexp_replace(v_result, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '', 'g');
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Sanitize identifier (table/column names)
CREATE OR REPLACE FUNCTION security.sanitize_identifier(
    p_input TEXT
)
RETURNS TEXT AS $$
BEGIN
    IF p_input IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Only allow alphanumeric and underscore
    IF p_input !~ '^[a-zA-Z_][a-zA-Z0-9_]*$' THEN
        RAISE EXCEPTION 'Invalid identifier: %', p_input;
    END IF;
    
    -- Max 63 characters (PostgreSQL limit)
    IF length(p_input) > 63 THEN
        RAISE EXCEPTION 'Identifier too long: %', p_input;
    END IF;
    
    RETURN lower(p_input);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Sanitize numeric input
CREATE OR REPLACE FUNCTION security.sanitize_numeric(
    p_input TEXT,
    p_min NUMERIC DEFAULT NULL,
    p_max NUMERIC DEFAULT NULL
)
RETURNS NUMERIC AS $$
DECLARE
    v_result NUMERIC;
BEGIN
    IF p_input IS NULL OR p_input = '' THEN
        RETURN NULL;
    END IF;
    
    -- Try to convert to numeric
    BEGIN
        v_result := p_input::NUMERIC;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid numeric value: %', p_input;
    END;
    
    -- Check bounds
    IF p_min IS NOT NULL AND v_result < p_min THEN
        RAISE EXCEPTION 'Value % below minimum %', v_result, p_min;
    END IF;
    
    IF p_max IS NOT NULL AND v_result > p_max THEN
        RAISE EXCEPTION 'Value % above maximum %', v_result, p_max;
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Sanitize email
CREATE OR REPLACE FUNCTION security.sanitize_email(
    p_input TEXT
)
RETURNS TEXT AS $$
DECLARE
    v_email TEXT;
BEGIN
    IF p_input IS NULL THEN
        RETURN NULL;
    END IF;
    
    v_email := lower(trim(p_input));
    
    -- Basic email validation
    IF v_email !~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' THEN
        RAISE EXCEPTION 'Invalid email format: %', p_input;
    END IF;
    
    -- Max length
    IF length(v_email) > 254 THEN
        RAISE EXCEPTION 'Email too long';
    END IF;
    
    RETURN v_email;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Sanitize UUID
CREATE OR REPLACE FUNCTION security.sanitize_uuid(
    p_input TEXT
)
RETURNS UUID AS $$
BEGIN
    IF p_input IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Try to convert to UUID
    BEGIN
        RETURN p_input::UUID;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid UUID: %', p_input;
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- QUERY VALIDATION (check before execution)
-- ============================================================================

CREATE OR REPLACE FUNCTION security.validate_query(
    p_query TEXT,
    p_allowed_operations TEXT[] DEFAULT ARRAY['SELECT'],
    p_block_on_suspicious BOOLEAN DEFAULT TRUE
)
RETURNS JSONB AS $$
DECLARE
    v_detection RECORD;
    v_result JSONB;
    v_query_upper TEXT;
BEGIN
    v_query_upper := upper(p_query);
    
    -- Check for injection patterns
    SELECT * INTO v_detection FROM security.detect_injection(p_query, 'query');
    
    -- Build result
    v_result := jsonb_build_object(
        'is_valid', TRUE,
        'query_length', length(p_query),
        'inspection', v_detection
    );
    
    -- Block if suspicious and blocking enabled
    IF v_detection.is_suspicious AND p_block_on_suspicious THEN
        -- Log the attempt
        INSERT INTO audit.security_events (
            event_type, severity, user_name, client_addr,
            description, details
        ) VALUES (
            'SQL_INJECTION_DETECTED', 
            CASE v_detection.threat_level
                WHEN 'CRITICAL' THEN 'CRITICAL'
                WHEN 'HIGH' THEN 'ERROR'
                ELSE 'WARNING'
            END,
            current_user,
            inet_client_addr(),
            'SQL injection attempt detected',
            jsonb_build_object(
                'query_preview', left(p_query, 200),
                'patterns', v_detection.detected_patterns,
                'details', v_detection.details
            )
        );
        
        v_result := v_result || jsonb_build_object('is_valid', FALSE);
        
        IF v_detection.threat_level IN ('HIGH', 'CRITICAL') THEN
            RAISE EXCEPTION 'Query blocked for security reasons';
        END IF;
    END IF;
    
    -- Check allowed operations
    IF NOT (
        (v_query_upper ~ '^\s*SELECT\b' AND 'SELECT' = ANY(p_allowed_operations)) OR
        (v_query_upper ~ '^\s*INSERT\b' AND 'INSERT' = ANY(p_allowed_operations)) OR
        (v_query_upper ~ '^\s*UPDATE\b' AND 'UPDATE' = ANY(p_allowed_operations)) OR
        (v_query_upper ~ '^\s*DELETE\b' AND 'DELETE' = ANY(p_allowed_operations)) OR
        (v_query_upper ~ '^\s*WITH\b' AND 'SELECT' = ANY(p_allowed_operations))
    ) THEN
        v_result := v_result || jsonb_build_object(
            'is_valid', FALSE,
            'error', 'Operation not allowed'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PARAMETERIZED QUERY BUILDER (prevents injection by design)
-- ============================================================================

CREATE OR REPLACE FUNCTION security.build_safe_query(
    p_template TEXT,
    p_params JSONB
)
RETURNS TEXT AS $$
DECLARE
    v_query TEXT := p_template;
    v_key TEXT;
    v_value TEXT;
    v_type TEXT;
BEGIN
    -- Replace placeholders with properly quoted values
    FOR v_key, v_value IN SELECT * FROM jsonb_each_text(p_params)
    LOOP
        -- Determine type and quote appropriately
        IF v_value IS NULL THEN
            v_query := replace(v_query, ':' || v_key, 'NULL');
        ELSIF v_value ~ '^-?[0-9]+\.?[0-9]*$' THEN
            -- Numeric - no quotes but validate
            v_query := replace(v_query, ':' || v_key, security.sanitize_numeric(v_value)::TEXT);
        ELSIF v_value ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
            -- UUID
            v_query := replace(v_query, ':' || v_key, quote_literal(v_value));
        ELSE
            -- String - quote and escape
            v_query := replace(v_query, ':' || v_key, quote_literal(security.sanitize_string(v_value)));
        END IF;
    END LOOP;
    
    RETURN v_query;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- IP-BASED BLOCKING (for repeated attacks)
-- ============================================================================

CREATE TABLE IF NOT EXISTS security.blocked_ips (
    ip_addr INET PRIMARY KEY,
    blocked_at TIMESTAMPTZ DEFAULT NOW(),
    blocked_until TIMESTAMPTZ,
    reason TEXT,
    attack_count INT DEFAULT 1
);

CREATE OR REPLACE FUNCTION security.check_ip_blocked(
    p_ip_addr INET DEFAULT inet_client_addr()
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM security.blocked_ips
        WHERE ip_addr = p_ip_addr
        AND (blocked_until IS NULL OR blocked_until > NOW())
    );
END;
$$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION security.block_ip(
    p_ip_addr INET,
    p_duration INTERVAL DEFAULT '1 hour',
    p_reason TEXT DEFAULT 'Suspicious activity'
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO security.blocked_ips (ip_addr, blocked_until, reason)
    VALUES (p_ip_addr, NOW() + p_duration, p_reason)
    ON CONFLICT (ip_addr) DO UPDATE SET
        blocked_until = NOW() + p_duration,
        reason = p_reason,
        attack_count = security.blocked_ips.attack_count + 1;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AUTO-BLOCK ON REPEATED ATTACKS
-- ============================================================================

CREATE OR REPLACE FUNCTION security.auto_block_on_attack()
RETURNS TRIGGER AS $$
DECLARE
    v_recent_attacks INT;
    v_client_ip INET;
BEGIN
    v_client_ip := (NEW.details->>'client_ip')::INET;
    
    IF v_client_ip IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- Count recent attacks from this IP
    SELECT COUNT(*) INTO v_recent_attacks
    FROM audit.security_events
    WHERE event_type = 'SQL_INJECTION_DETECTED'
    AND details->>'client_ip' = v_client_ip::TEXT
    AND event_timestamp > NOW() - INTERVAL '15 minutes';
    
    -- Block after 3 attempts
    IF v_recent_attacks >= 3 THEN
        PERFORM security.block_ip(v_client_ip, '1 hour', 'Repeated SQL injection attempts');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-blocking
DROP TRIGGER IF EXISTS trg_auto_block_injection ON audit.security_events;
CREATE TRIGGER trg_auto_block_injection
    AFTER INSERT ON audit.security_events
    FOR EACH ROW
    WHEN (NEW.event_type = 'SQL_INJECTION_DETECTED')
    EXECUTE FUNCTION security.auto_block_on_attack();

-- ============================================================================
-- SUMMARY
-- ============================================================================

COMMENT ON FUNCTION security.detect_injection IS 'Detect SQL injection patterns in input';
COMMENT ON FUNCTION security.sanitize_string IS 'Sanitize string input removing dangerous characters';
COMMENT ON FUNCTION security.validate_query IS 'Validate a query for security before execution';
COMMENT ON FUNCTION security.build_safe_query IS 'Build parameterized queries safely';
