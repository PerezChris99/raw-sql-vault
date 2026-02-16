-- ============================================================================
-- PRODUCTION SECURITY: Rate Limiting & DoS Protection
-- PostgreSQL 14+
-- ============================================================================
-- Protects against denial of service, brute force, and resource exhaustion
-- ============================================================================

-- ============================================================================
-- RATE LIMIT CONFIGURATION
-- ============================================================================

CREATE TABLE IF NOT EXISTS security.rate_limits (
    limit_id SERIAL PRIMARY KEY,
    limit_name TEXT UNIQUE NOT NULL,
    limit_description TEXT,
    
    -- Rate limit parameters
    max_requests INT NOT NULL DEFAULT 100,
    window_seconds INT NOT NULL DEFAULT 60,
    
    -- Actions when exceeded
    action_on_exceed TEXT DEFAULT 'BLOCK' CHECK (action_on_exceed IN ('LOG', 'DELAY', 'BLOCK')),
    block_duration_seconds INT DEFAULT 300,
    
    -- Scope
    scope TEXT DEFAULT 'user' CHECK (scope IN ('user', 'ip', 'global', 'endpoint')),
    
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default rate limits
INSERT INTO security.rate_limits (limit_name, limit_description, max_requests, window_seconds, scope) VALUES
('global_queries', 'Global query rate limit', 1000, 60, 'global'),
('user_queries', 'Per-user query limit', 100, 60, 'user'),
('user_writes', 'Per-user write operations', 50, 60, 'user'),
('ip_connections', 'Per-IP connection limit', 20, 60, 'ip'),
('failed_logins', 'Failed login attempts', 5, 300, 'user'),
('api_requests', 'API endpoint requests', 200, 60, 'endpoint'),
('bulk_operations', 'Bulk insert/update limit', 10, 60, 'user'),
('export_requests', 'Data export requests', 5, 3600, 'user')
ON CONFLICT (limit_name) DO NOTHING;

-- ============================================================================
-- RATE LIMIT TRACKING
-- ============================================================================

CREATE TABLE IF NOT EXISTS security.rate_limit_counters (
    counter_id BIGSERIAL PRIMARY KEY,
    limit_name TEXT NOT NULL REFERENCES security.rate_limits(limit_name),
    identifier TEXT NOT NULL,  -- user_id, ip_addr, or 'global'
    window_start TIMESTAMPTZ NOT NULL,
    request_count INT DEFAULT 1,
    
    UNIQUE (limit_name, identifier, window_start)
);

-- Index for fast lookups
CREATE INDEX idx_rate_counters_lookup ON security.rate_limit_counters (limit_name, identifier, window_start DESC);

-- Auto-cleanup old counters
CREATE INDEX idx_rate_counters_cleanup ON security.rate_limit_counters (window_start);

-- ============================================================================
-- RATE LIMIT FUNCTIONS
-- ============================================================================

-- Check if rate limit exceeded and increment counter
CREATE OR REPLACE FUNCTION security.check_rate_limit(
    p_limit_name TEXT,
    p_identifier TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_limit RECORD;
    v_window_start TIMESTAMPTZ;
    v_current_count INT;
    v_result JSONB;
    v_is_exceeded BOOLEAN := FALSE;
    v_actual_identifier TEXT;
BEGIN
    -- Get limit configuration
    SELECT * INTO v_limit FROM security.rate_limits WHERE limit_name = p_limit_name AND is_active;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('allowed', TRUE, 'error', 'Rate limit not found');
    END IF;
    
    -- Determine identifier based on scope
    v_actual_identifier := CASE v_limit.scope
        WHEN 'global' THEN 'global'
        WHEN 'ip' THEN COALESCE(p_identifier, inet_client_addr()::TEXT, 'unknown')
        WHEN 'user' THEN COALESCE(p_identifier, current_user, 'anonymous')
        WHEN 'endpoint' THEN COALESCE(p_identifier, 'default')
        ELSE COALESCE(p_identifier, 'unknown')
    END;
    
    -- Calculate window start (truncate to window boundary)
    v_window_start := date_trunc('second', NOW()) - 
        ((EXTRACT(EPOCH FROM NOW())::INT % v_limit.window_seconds) * INTERVAL '1 second');
    
    -- Upsert counter and get current count
    INSERT INTO security.rate_limit_counters (limit_name, identifier, window_start, request_count)
    VALUES (p_limit_name, v_actual_identifier, v_window_start, 1)
    ON CONFLICT (limit_name, identifier, window_start) 
    DO UPDATE SET request_count = security.rate_limit_counters.request_count + 1
    RETURNING request_count INTO v_current_count;
    
    -- Check if exceeded
    v_is_exceeded := v_current_count > v_limit.max_requests;
    
    -- Build result
    v_result := jsonb_build_object(
        'allowed', NOT v_is_exceeded,
        'current_count', v_current_count,
        'max_requests', v_limit.max_requests,
        'window_seconds', v_limit.window_seconds,
        'remaining', GREATEST(0, v_limit.max_requests - v_current_count),
        'reset_at', v_window_start + (v_limit.window_seconds || ' seconds')::INTERVAL
    );
    
    -- Take action if exceeded
    IF v_is_exceeded THEN
        -- Log the event
        INSERT INTO audit.security_events (
            event_type, severity, user_name, client_addr,
            description, details
        ) VALUES (
            'RATE_LIMIT_EXCEEDED',
            CASE WHEN v_limit.action_on_exceed = 'BLOCK' THEN 'WARNING' ELSE 'INFO' END,
            current_user,
            inet_client_addr(),
            format('Rate limit %s exceeded', p_limit_name),
            v_result || jsonb_build_object('identifier', v_actual_identifier)
        );
        
        -- Block if configured
        IF v_limit.action_on_exceed = 'BLOCK' THEN
            IF v_limit.scope = 'ip' AND inet_client_addr() IS NOT NULL THEN
                PERFORM security.block_ip(
                    inet_client_addr(), 
                    (v_limit.block_duration_seconds || ' seconds')::INTERVAL,
                    'Rate limit exceeded: ' || p_limit_name
                );
            END IF;
            
            v_result := v_result || jsonb_build_object(
                'blocked', TRUE,
                'blocked_until', NOW() + (v_limit.block_duration_seconds || ' seconds')::INTERVAL
            );
        END IF;
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Decorator function for rate-limited queries
CREATE OR REPLACE FUNCTION security.rate_limited_query(
    p_limit_name TEXT,
    p_query TEXT,
    p_identifier TEXT DEFAULT NULL
)
RETURNS SETOF RECORD AS $$
DECLARE
    v_check JSONB;
BEGIN
    -- Check rate limit
    v_check := security.check_rate_limit(p_limit_name, p_identifier);
    
    IF NOT (v_check->>'allowed')::BOOLEAN THEN
        RAISE EXCEPTION 'Rate limit exceeded. Try again after %', v_check->>'reset_at'
            USING ERRCODE = '54001';  -- too_many_connections error code
    END IF;
    
    -- Execute the query
    RETURN QUERY EXECUTE p_query;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CONNECTION THROTTLING
-- ============================================================================

CREATE OR REPLACE FUNCTION security.check_connection_allowed()
RETURNS BOOLEAN AS $$
DECLARE
    v_client_ip INET;
    v_check JSONB;
BEGIN
    v_client_ip := inet_client_addr();
    
    -- Check if IP is blocked
    IF security.check_ip_blocked(v_client_ip) THEN
        RAISE EXCEPTION 'Connection blocked' USING ERRCODE = '28000';
    END IF;
    
    -- Check connection rate limit
    v_check := security.check_rate_limit('ip_connections', v_client_ip::TEXT);
    
    IF NOT (v_check->>'allowed')::BOOLEAN THEN
        RAISE EXCEPTION 'Too many connections' USING ERRCODE = '53300';
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- RESOURCE USAGE MONITORING
-- ============================================================================

CREATE TABLE IF NOT EXISTS security.resource_usage (
    usage_id BIGSERIAL PRIMARY KEY,
    recorded_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Connection stats
    total_connections INT,
    active_connections INT,
    idle_connections INT,
    
    -- Query stats
    active_queries INT,
    waiting_queries INT,
    blocked_queries INT,
    
    -- Resource stats
    db_size_bytes BIGINT,
    cache_hit_ratio NUMERIC,
    
    -- Thresholds exceeded
    alerts TEXT[]
);

CREATE OR REPLACE FUNCTION security.record_resource_usage()
RETURNS VOID AS $$
DECLARE
    v_alerts TEXT[] := '{}';
    v_total_conn INT;
    v_active_conn INT;
    v_active_queries INT;
BEGIN
    -- Get connection stats
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE state = 'active'),
        COUNT(*) FILTER (WHERE state = 'active' AND query NOT LIKE '%pg_stat%')
    INTO v_total_conn, v_active_conn, v_active_queries
    FROM pg_stat_activity
    WHERE datname = current_database();
    
    -- Check thresholds
    IF v_total_conn > 80 THEN
        v_alerts := array_append(v_alerts, 'HIGH_CONNECTIONS');
    END IF;
    
    IF v_active_queries > 20 THEN
        v_alerts := array_append(v_alerts, 'HIGH_ACTIVE_QUERIES');
    END IF;
    
    INSERT INTO security.resource_usage (
        total_connections, active_connections, active_queries, alerts
    ) VALUES (
        v_total_conn, v_active_conn, v_active_queries, v_alerts
    );
    
    -- Alert if thresholds exceeded
    IF array_length(v_alerts, 1) > 0 THEN
        INSERT INTO audit.security_events (
            event_type, severity, description, details
        ) VALUES (
            'RATE_LIMIT_EXCEEDED', 'WARNING',
            'Resource usage alert',
            jsonb_build_object('alerts', v_alerts, 'connections', v_total_conn)
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- LEAKY BUCKET ALGORITHM (for smoother rate limiting)
-- ============================================================================

CREATE TABLE IF NOT EXISTS security.leaky_buckets (
    bucket_id SERIAL PRIMARY KEY,
    bucket_name TEXT NOT NULL,
    identifier TEXT NOT NULL,
    
    -- Bucket parameters
    capacity INT NOT NULL,        -- Max tokens
    tokens NUMERIC NOT NULL,      -- Current tokens
    refill_rate NUMERIC NOT NULL, -- Tokens per second
    
    last_update TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE (bucket_name, identifier)
);

CREATE OR REPLACE FUNCTION security.leaky_bucket_allow(
    p_bucket_name TEXT,
    p_identifier TEXT,
    p_capacity INT DEFAULT 100,
    p_refill_rate NUMERIC DEFAULT 10,  -- tokens per second
    p_tokens_required INT DEFAULT 1
)
RETURNS BOOLEAN AS $$
DECLARE
    v_bucket RECORD;
    v_elapsed NUMERIC;
    v_new_tokens NUMERIC;
    v_allowed BOOLEAN;
BEGIN
    -- Get or create bucket
    INSERT INTO security.leaky_buckets (bucket_name, identifier, capacity, tokens, refill_rate)
    VALUES (p_bucket_name, p_identifier, p_capacity, p_capacity, p_refill_rate)
    ON CONFLICT (bucket_name, identifier) DO UPDATE SET
        -- Refill tokens based on elapsed time
        tokens = LEAST(
            security.leaky_buckets.capacity,
            security.leaky_buckets.tokens + 
            (EXTRACT(EPOCH FROM NOW() - security.leaky_buckets.last_update) * security.leaky_buckets.refill_rate)
        ),
        last_update = NOW()
    RETURNING * INTO v_bucket;
    
    -- Check if enough tokens
    v_allowed := v_bucket.tokens >= p_tokens_required;
    
    -- Consume tokens if allowed
    IF v_allowed THEN
        UPDATE security.leaky_buckets
        SET tokens = tokens - p_tokens_required
        WHERE bucket_name = p_bucket_name AND identifier = p_identifier;
    END IF;
    
    RETURN v_allowed;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- CLEANUP OLD DATA
-- ============================================================================

CREATE OR REPLACE FUNCTION security.cleanup_rate_limit_data(
    p_retention_hours INT DEFAULT 24
)
RETURNS INT AS $$
DECLARE
    v_deleted INT := 0;
    v_temp INT;
BEGIN
    -- Clean old counters
    DELETE FROM security.rate_limit_counters
    WHERE window_start < NOW() - (p_retention_hours || ' hours')::INTERVAL;
    GET DIAGNOSTICS v_temp = ROW_COUNT;
    v_deleted := v_deleted + v_temp;
    
    -- Clean expired IP blocks
    DELETE FROM security.blocked_ips
    WHERE blocked_until IS NOT NULL AND blocked_until < NOW();
    GET DIAGNOSTICS v_temp = ROW_COUNT;
    v_deleted := v_deleted + v_temp;
    
    -- Clean old resource usage
    DELETE FROM security.resource_usage
    WHERE recorded_at < NOW() - (p_retention_hours * 7 || ' hours')::INTERVAL;
    GET DIAGNOSTICS v_temp = ROW_COUNT;
    v_deleted := v_deleted + v_temp;
    
    RETURN v_deleted;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SUMMARY
-- ============================================================================

COMMENT ON TABLE security.rate_limits IS 'Rate limit configuration for different operations';
COMMENT ON FUNCTION security.check_rate_limit IS 'Check and increment rate limit counter';
COMMENT ON FUNCTION security.leaky_bucket_allow IS 'Smoother rate limiting using leaky bucket algorithm';
