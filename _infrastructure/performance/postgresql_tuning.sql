-- ============================================================================
-- PostgreSQL Performance Tuning
-- Production Configuration for Raw SQL Vault Projects
-- PostgreSQL 14+
-- ============================================================================
-- These settings should be added to postgresql.conf
-- Adjust values based on your server resources
-- ============================================================================

-- ============================================================================
-- MEMORY SETTINGS
-- ============================================================================
-- Rule of thumb: shared_buffers = 25% of RAM, effective_cache_size = 75% of RAM

-- Shared memory for caching (adjust to ~25% of available RAM)
-- ALTER SYSTEM SET shared_buffers = '4GB';

-- Planner's estimate of available OS cache (adjust to ~75% of RAM)
-- ALTER SYSTEM SET effective_cache_size = '12GB';

-- Memory for sorting and hashing per operation
-- ALTER SYSTEM SET work_mem = '64MB';

-- Memory for maintenance operations (VACUUM, CREATE INDEX, etc.)
-- ALTER SYSTEM SET maintenance_work_mem = '1GB';

-- Memory for WAL buffers
-- ALTER SYSTEM SET wal_buffers = '64MB';

-- ============================================================================
-- CHECKPOINT & WAL SETTINGS
-- ============================================================================

-- Maximum time between checkpoints (reduce for faster crash recovery)
-- ALTER SYSTEM SET checkpoint_timeout = '15min';

-- Target checkpoint completion time as fraction of checkpoint_timeout
-- ALTER SYSTEM SET checkpoint_completion_target = 0.9;

-- Maximum WAL size before checkpoint is triggered
-- ALTER SYSTEM SET max_wal_size = '4GB';

-- Minimum WAL size to retain
-- ALTER SYSTEM SET min_wal_size = '1GB';

-- ============================================================================
-- CONNECTION SETTINGS
-- ============================================================================

-- Maximum concurrent connections (use PgBouncer for more clients)
-- ALTER SYSTEM SET max_connections = 200;

-- Superuser reserved connections
-- ALTER SYSTEM SET superuser_reserved_connections = 3;

-- Connection timeout (milliseconds)
-- ALTER SYSTEM SET tcp_keepalives_idle = 60;
-- ALTER SYSTEM SET tcp_keepalives_interval = 30;
-- ALTER SYSTEM SET tcp_keepalives_count = 3;

-- ============================================================================
-- QUERY PLANNER SETTINGS
-- ============================================================================

-- Cost of random page read (lower for SSD)
-- ALTER SYSTEM SET random_page_cost = 1.1;  -- SSD: 1.1, HDD: 4.0

-- Enable parallel query execution
-- ALTER SYSTEM SET max_parallel_workers_per_gather = 4;
-- ALTER SYSTEM SET max_parallel_workers = 8;
-- ALTER SYSTEM SET max_parallel_maintenance_workers = 4;

-- Planner statistics target (higher = more accurate, slower)
-- ALTER SYSTEM SET default_statistics_target = 100;

-- ============================================================================
-- LOGGING (Production)
-- ============================================================================

-- Log slow queries (adjust threshold as needed)
-- ALTER SYSTEM SET log_min_duration_statement = 1000;  -- 1 second

-- Log DDL statements
-- ALTER SYSTEM SET log_statement = 'ddl';

-- Log connections/disconnections
-- ALTER SYSTEM SET log_connections = on;
-- ALTER SYSTEM SET log_disconnections = on;

-- Log lock waits
-- ALTER SYSTEM SET log_lock_waits = on;
-- ALTER SYSTEM SET deadlock_timeout = '1s';

-- ============================================================================
-- SECURITY SETTINGS
-- ============================================================================

-- Require SSL for all connections (production)
-- ALTER SYSTEM SET ssl = on;
-- ALTER SYSTEM SET ssl_min_protocol_version = 'TLSv1.2';

-- Password encryption method
-- ALTER SYSTEM SET password_encryption = 'scram-sha-256';

-- ============================================================================
-- VACUUM & MAINTENANCE
-- ============================================================================

-- Autovacuum settings (tune based on write activity)
-- ALTER SYSTEM SET autovacuum_vacuum_scale_factor = 0.1;
-- ALTER SYSTEM SET autovacuum_analyze_scale_factor = 0.05;
-- ALTER SYSTEM SET autovacuum_vacuum_cost_limit = 2000;

-- ============================================================================
-- APPLY INDEXES FOR COMMON PATTERNS
-- ============================================================================

-- Function to create optimized indexes on a table
CREATE OR REPLACE FUNCTION performance.create_standard_indexes(
    p_schema TEXT,
    p_table TEXT
)
RETURNS VOID AS $$
DECLARE
    v_pk_columns TEXT[];
    v_table_oid OID;
BEGIN
    -- Get table OID
    SELECT c.oid INTO v_table_oid
    FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE n.nspname = p_schema AND c.relname = p_table;
    
    IF v_table_oid IS NULL THEN
        RAISE EXCEPTION 'Table %.% not found', p_schema, p_table;
    END IF;
    
    -- Create index on created_at if exists (common pattern)
    IF EXISTS (
        SELECT 1 FROM pg_attribute 
        WHERE attrelid = v_table_oid AND attname = 'created_at'
    ) THEN
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS idx_%s_created_at ON %I.%I (created_at DESC)',
            p_table, p_schema, p_table
        );
        RAISE NOTICE 'Created index on %.%.created_at', p_schema, p_table;
    END IF;
    
    -- Create index on updated_at if exists
    IF EXISTS (
        SELECT 1 FROM pg_attribute 
        WHERE attrelid = v_table_oid AND attname = 'updated_at'
    ) THEN
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS idx_%s_updated_at ON %I.%I (updated_at DESC)',
            p_table, p_schema, p_table
        );
    END IF;
    
    -- Create index on tenant_id if exists (for RLS)
    IF EXISTS (
        SELECT 1 FROM pg_attribute 
        WHERE attrelid = v_table_oid AND attname = 'tenant_id'
    ) THEN
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS idx_%s_tenant_id ON %I.%I (tenant_id)',
            p_table, p_schema, p_table
        );
        RAISE NOTICE 'Created index on %.%.tenant_id', p_schema, p_table;
    END IF;
    
    -- Create index on status if exists
    IF EXISTS (
        SELECT 1 FROM pg_attribute 
        WHERE attrelid = v_table_oid AND attname = 'status'
    ) THEN
        EXECUTE format(
            'CREATE INDEX IF NOT EXISTS idx_%s_status ON %I.%I (status)',
            p_table, p_schema, p_table
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- QUERY ANALYSIS HELPERS
-- ============================================================================

-- View: Currently running queries
CREATE OR REPLACE VIEW performance.running_queries AS
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    backend_start,
    query_start,
    state,
    EXTRACT(EPOCH FROM (NOW() - query_start)) AS runtime_seconds,
    wait_event_type,
    wait_event,
    LEFT(query, 200) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
AND query NOT LIKE '%pg_stat_activity%'
ORDER BY query_start ASC;

-- View: Table bloat estimation
CREATE OR REPLACE VIEW performance.table_bloat AS
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname || '.' || tablename)) AS table_size,
    pg_size_pretty(pg_indexes_size(schemaname || '.' || tablename)) AS index_size,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_row_pct,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- View: Index usage statistics
CREATE OR REPLACE VIEW performance.index_usage AS
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    CASE WHEN idx_scan = 0 THEN 'UNUSED' ELSE 'USED' END AS status
FROM pg_stat_user_indexes
ORDER BY idx_scan ASC, pg_relation_size(indexrelid) DESC;

-- View: Cache hit ratio (should be > 99%)
CREATE OR REPLACE VIEW performance.cache_stats AS
SELECT
    'index hit rate' AS metric,
    ROUND(100.0 * sum(idx_blks_hit) / NULLIF(sum(idx_blks_hit + idx_blks_read), 0), 2) AS ratio
FROM pg_statio_user_indexes
UNION ALL
SELECT
    'table hit rate',
    ROUND(100.0 * sum(heap_blks_hit) / NULLIF(sum(heap_blks_hit + heap_blks_read), 0), 2)
FROM pg_statio_user_tables;

-- ============================================================================
-- PERFORMANCE MONITORING FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION performance.get_health_report()
RETURNS TABLE (
    category TEXT,
    metric TEXT,
    value TEXT,
    status TEXT
) AS $$
BEGIN
    -- Cache hit ratio
    RETURN QUERY
    SELECT 'Cache'::TEXT, 'Table Hit Ratio'::TEXT, 
           ratio::TEXT, 
           CASE WHEN ratio >= 99 THEN 'OK' WHEN ratio >= 95 THEN 'WARNING' ELSE 'CRITICAL' END
    FROM performance.cache_stats WHERE metric = 'table hit rate';
    
    -- Connection count
    RETURN QUERY
    SELECT 'Connections', 'Active Connections',
           COUNT(*)::TEXT,
           CASE WHEN COUNT(*) < 100 THEN 'OK' WHEN COUNT(*) < 150 THEN 'WARNING' ELSE 'CRITICAL' END
    FROM pg_stat_activity WHERE state != 'idle';
    
    -- Long running queries
    RETURN QUERY
    SELECT 'Queries', 'Long Running (>60s)',
           COUNT(*)::TEXT,
           CASE WHEN COUNT(*) = 0 THEN 'OK' WHEN COUNT(*) < 5 THEN 'WARNING' ELSE 'CRITICAL' END
    FROM pg_stat_activity 
    WHERE state != 'idle' 
    AND EXTRACT(EPOCH FROM (NOW() - query_start)) > 60;
    
    -- Dead rows needing vacuum
    RETURN QUERY
    SELECT 'Maintenance', 'Tables with >10% dead rows',
           COUNT(*)::TEXT,
           CASE WHEN COUNT(*) = 0 THEN 'OK' WHEN COUNT(*) < 5 THEN 'WARNING' ELSE 'CRITICAL' END
    FROM pg_stat_user_tables
    WHERE n_dead_tup > 0.1 * (n_live_tup + n_dead_tup);
    
    -- Database size
    RETURN QUERY
    SELECT 'Storage', 'Database Size',
           pg_size_pretty(pg_database_size(current_database())),
           'INFO';
END;
$$ LANGUAGE plpgsql;

-- Create performance schema if not exists
CREATE SCHEMA IF NOT EXISTS performance;
COMMENT ON SCHEMA performance IS 'Performance monitoring and optimization tools';
