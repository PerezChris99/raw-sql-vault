-- ============================================================================
-- Water Point Usage Monitor - V002 Hypertables
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Convert tables to hypertables with compression and retention
-- ============================================================================

-- ============================================================================
-- Convert usage_logs to Hypertable
-- ============================================================================

-- Create hypertable with daily chunks
SELECT create_hypertable(
    'usage_logs',
    'logged_at',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

-- Add borehole_id index for common query patterns
CREATE INDEX IF NOT EXISTS idx_usage_logs_borehole 
    ON usage_logs(borehole_id, logged_at DESC);

-- Add composite index for time-range + borehole queries
CREATE INDEX IF NOT EXISTS idx_usage_logs_borehole_time 
    ON usage_logs(borehole_id, logged_at DESC);

COMMENT ON TABLE usage_logs IS 'TimescaleDB hypertable for time-series usage data';

-- ============================================================================
-- Enable Compression
-- ============================================================================

-- Configure compression settings
ALTER TABLE usage_logs SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'borehole_id',
    timescaledb.compress_orderby = 'logged_at DESC'
);

-- Add compression policy - compress chunks older than 7 days
SELECT add_compression_policy(
    'usage_logs',
    INTERVAL '7 days',
    if_not_exists => TRUE
);

-- ============================================================================
-- Enable Retention Policy
-- ============================================================================

-- Keep raw data for 365 days, then auto-delete
SELECT add_retention_policy(
    'usage_logs',
    INTERVAL '365 days',
    if_not_exists => TRUE
);

-- ============================================================================
-- Convert health_score_history to Hypertable
-- ============================================================================

SELECT create_hypertable(
    'health_score_history',
    'recorded_at',
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists => TRUE
);

CREATE INDEX IF NOT EXISTS idx_health_history_borehole 
    ON health_score_history(borehole_id, recorded_at DESC);

-- Compression for health history
ALTER TABLE health_score_history SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'borehole_id',
    timescaledb.compress_orderby = 'recorded_at DESC'
);

SELECT add_compression_policy(
    'health_score_history',
    INTERVAL '30 days',
    if_not_exists => TRUE
);

-- Retain 2 years of health history (aggregated data)
SELECT add_retention_policy(
    'health_score_history',
    INTERVAL '730 days',
    if_not_exists => TRUE
);

-- ============================================================================
-- Utility Functions for Hypertable Management
-- ============================================================================

-- Function to get hypertable information
CREATE OR REPLACE FUNCTION fn_get_hypertable_info()
RETURNS TABLE (
    table_name TEXT,
    num_chunks BIGINT,
    total_size TEXT,
    compressed_size TEXT,
    compression_ratio TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ht.hypertable_name::TEXT as table_name,
        (SELECT COUNT(*) FROM timescaledb_information.chunks c 
         WHERE c.hypertable_name = ht.hypertable_name) as num_chunks,
        pg_size_pretty(hypertable_size(format('%I.%I', ht.hypertable_schema, ht.hypertable_name)::regclass)) as total_size,
        pg_size_pretty(hypertable_compression_stats(format('%I.%I', ht.hypertable_schema, ht.hypertable_name)::regclass)) as compressed_size,
        COALESCE(
            ROUND(
                100 - (100.0 * 
                    COALESCE(
                        (SELECT SUM(after_compression_total_bytes)::NUMERIC 
                         FROM hypertable_compression_stats(format('%I.%I', ht.hypertable_schema, ht.hypertable_name)::regclass)),
                        0
                    ) /
                    NULLIF(
                        (SELECT SUM(before_compression_total_bytes)::NUMERIC 
                         FROM hypertable_compression_stats(format('%I.%I', ht.hypertable_schema, ht.hypertable_name)::regclass)),
                        0
                    )
                ),
            1)::TEXT || '%',
            'N/A'
        ) as compression_ratio
    FROM timescaledb_information.hypertables ht;
END;
$$;

COMMENT ON FUNCTION fn_get_hypertable_info IS 'Get hypertable statistics including compression';

-- Function to manually compress old chunks
CREATE OR REPLACE PROCEDURE sp_compress_old_chunks(
    p_table_name TEXT,
    p_older_than INTERVAL DEFAULT INTERVAL '7 days'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_chunk RECORD;
    v_compressed INTEGER := 0;
BEGIN
    FOR v_chunk IN
        SELECT chunk_schema, chunk_name
        FROM timescaledb_information.chunks
        WHERE hypertable_name = p_table_name
          AND is_compressed = FALSE
          AND range_end < NOW() - p_older_than
    LOOP
        EXECUTE format('SELECT compress_chunk(%L)', 
            format('%I.%I', v_chunk.chunk_schema, v_chunk.chunk_name));
        v_compressed := v_compressed + 1;
    END LOOP;
    
    RAISE NOTICE 'Compressed % chunks for %', v_compressed, p_table_name;
END;
$$;

COMMENT ON PROCEDURE sp_compress_old_chunks IS 'Manually compress chunks older than specified interval';

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
DECLARE
    v_hypertable_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_hypertable_count
    FROM timescaledb_information.hypertables;
    
    RAISE NOTICE 'V002 Hypertables configured successfully';
    RAISE NOTICE 'Total hypertables: %', v_hypertable_count;
    RAISE NOTICE 'Compression policy: 7 days for usage_logs, 30 days for health_score_history';
    RAISE NOTICE 'Retention policy: 365 days for usage_logs, 730 days for health_score_history';
END $$;

-- Show hypertable details
SELECT 
    hypertable_name,
    num_dimensions,
    compression_enabled,
    tablespaces
FROM timescaledb_information.hypertables;
