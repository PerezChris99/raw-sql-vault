-- ============================================================================
-- Water Point Usage Monitor - V003 Continuous Aggregates
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Pre-computed aggregates for efficient time-series queries
-- ============================================================================

-- ============================================================================
-- Hourly Usage Aggregate
-- ============================================================================

CREATE MATERIALIZED VIEW usage_hourly_agg
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', logged_at) AS bucket,
    borehole_id,
    
    -- Usage metrics
    COUNT(*) as reading_count,
    SUM(usage_liters) as total_usage_liters,
    AVG(usage_liters) as avg_usage_liters,
    
    -- Flow rate statistics
    MIN(flow_rate_lpm) as min_flow_rate,
    AVG(flow_rate_lpm) as avg_flow_rate,
    MAX(flow_rate_lpm) as max_flow_rate,
    
    -- Pump metrics
    SUM(pump_runtime_sec) as total_runtime_sec,
    SUM(pump_cycles) as total_pump_cycles,
    
    -- Pressure
    AVG(pressure_bar) as avg_pressure,
    MIN(pressure_bar) as min_pressure,
    MAX(pressure_bar) as max_pressure,
    
    -- Voltage (for solar/electric pumps)
    AVG(voltage) as avg_voltage,
    MIN(voltage) as min_voltage
    
FROM usage_logs
GROUP BY bucket, borehole_id
WITH NO DATA;

-- Create index for common query patterns
CREATE INDEX idx_hourly_agg_borehole ON usage_hourly_agg(borehole_id, bucket DESC);

-- Refresh policy: refresh every hour, covering last 2 hours
SELECT add_continuous_aggregate_policy('usage_hourly_agg',
    start_offset => INTERVAL '2 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

COMMENT ON MATERIALIZED VIEW usage_hourly_agg IS 'Hourly aggregated usage statistics per borehole';

-- ============================================================================
-- Daily Usage Aggregate
-- ============================================================================

CREATE MATERIALIZED VIEW usage_daily_agg
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', logged_at) AS bucket,
    borehole_id,
    
    -- Usage summary
    COUNT(*) as reading_count,
    SUM(usage_liters) as total_usage_liters,
    AVG(usage_liters) as avg_usage_liters,
    
    -- Flow rate
    MIN(flow_rate_lpm) as min_flow_rate,
    AVG(flow_rate_lpm) as avg_flow_rate,
    MAX(flow_rate_lpm) as max_flow_rate,
    STDDEV(flow_rate_lpm) as stddev_flow_rate,
    
    -- Pump runtime
    SUM(pump_runtime_sec) / 3600.0 as runtime_hours,
    SUM(pump_cycles) as total_pump_cycles,
    
    -- Efficiency indicator (usage per runtime)
    CASE WHEN SUM(pump_runtime_sec) > 0 
        THEN SUM(usage_liters) / (SUM(pump_runtime_sec) / 60.0)
        ELSE NULL 
    END as liters_per_minute_runtime,
    
    -- Pressure
    AVG(pressure_bar) as avg_pressure,
    MIN(pressure_bar) as min_pressure,
    MAX(pressure_bar) as max_pressure,
    STDDEV(pressure_bar) as stddev_pressure,
    
    -- Power
    AVG(voltage) as avg_voltage,
    MIN(voltage) as min_voltage,
    
    -- Temperature
    AVG(temperature_c) as avg_temperature
    
FROM usage_logs
GROUP BY bucket, borehole_id
WITH NO DATA;

CREATE INDEX idx_daily_agg_borehole ON usage_daily_agg(borehole_id, bucket DESC);
CREATE INDEX idx_daily_agg_bucket ON usage_daily_agg(bucket DESC);

-- Refresh policy: refresh every 6 hours, covering last 2 days
SELECT add_continuous_aggregate_policy('usage_daily_agg',
    start_offset => INTERVAL '2 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '6 hours',
    if_not_exists => TRUE
);

COMMENT ON MATERIALIZED VIEW usage_daily_agg IS 'Daily aggregated usage statistics per borehole';

-- ============================================================================
-- Weekly Usage Aggregate
-- ============================================================================

CREATE MATERIALIZED VIEW usage_weekly_agg
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 week', logged_at) AS bucket,
    borehole_id,
    
    -- Weekly totals
    COUNT(*) as reading_count,
    SUM(usage_liters) as total_usage_liters,
    AVG(usage_liters) as avg_usage_liters,
    
    -- Flow summary
    AVG(flow_rate_lpm) as avg_flow_rate,
    MIN(flow_rate_lpm) as min_flow_rate,
    MAX(flow_rate_lpm) as max_flow_rate,
    
    -- Operational hours
    SUM(pump_runtime_sec) / 3600.0 as runtime_hours,
    SUM(pump_cycles) as total_pump_cycles,
    
    -- Average cycles per day
    SUM(pump_cycles) / 7.0 as avg_daily_cycles,
    
    -- Pressure weekly summary
    AVG(pressure_bar) as avg_pressure
    
FROM usage_logs
GROUP BY bucket, borehole_id
WITH NO DATA;

CREATE INDEX idx_weekly_agg_borehole ON usage_weekly_agg(borehole_id, bucket DESC);

-- Refresh policy: refresh daily
SELECT add_continuous_aggregate_policy('usage_weekly_agg',
    start_offset => INTERVAL '2 weeks',
    end_offset => INTERVAL '1 week',
    schedule_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

COMMENT ON MATERIALIZED VIEW usage_weekly_agg IS 'Weekly aggregated usage statistics per borehole';

-- ============================================================================
-- Daily Comparison View (For LAG analysis)
-- ============================================================================

-- This view implements the user's sample query pattern
CREATE OR REPLACE VIEW vw_daily_usage_comparison AS
WITH daily_stats AS (
    SELECT 
        bucket as date,
        borehole_id,
        total_usage_liters as avg_daily,  -- Renamed to match user's sample
        LAG(total_usage_liters) OVER (
            PARTITION BY borehole_id 
            ORDER BY bucket
        ) as prev_day_usage,
        LAG(total_usage_liters, 7) OVER (
            PARTITION BY borehole_id 
            ORDER BY bucket
        ) as same_day_last_week,
        AVG(total_usage_liters) OVER (
            PARTITION BY borehole_id 
            ORDER BY bucket
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as rolling_7day_avg,
        AVG(total_usage_liters) OVER (
            PARTITION BY borehole_id 
            ORDER BY bucket
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) as rolling_30day_avg
    FROM usage_daily_agg
)
SELECT 
    borehole_id,
    date,
    avg_daily,
    prev_day_usage as prev,  -- Matches user's sample column name
    same_day_last_week,
    rolling_7day_avg,
    rolling_30day_avg,
    -- Percentage changes
    ROUND(100.0 * (avg_daily - prev_day_usage) / NULLIF(prev_day_usage, 0), 2) as pct_change_vs_prev,
    ROUND(100.0 * (avg_daily - rolling_7day_avg) / NULLIF(rolling_7day_avg, 0), 2) as pct_change_vs_7day_avg
FROM daily_stats
ORDER BY borehole_id, date DESC;

COMMENT ON VIEW vw_daily_usage_comparison IS 'Daily usage with LAG comparison (matches user sample query pattern)';

-- ============================================================================
-- Manual Refresh Function
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_refresh_all_aggregates(
    p_start_time TIMESTAMPTZ DEFAULT NULL,
    p_end_time TIMESTAMPTZ DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Default to last 7 days if not specified
    p_start_time := COALESCE(p_start_time, NOW() - INTERVAL '7 days');
    p_end_time := COALESCE(p_end_time, NOW());
    
    RAISE NOTICE 'Refreshing continuous aggregates from % to %', p_start_time, p_end_time;
    
    -- Refresh hourly
    CALL refresh_continuous_aggregate('usage_hourly_agg', p_start_time, p_end_time);
    RAISE NOTICE 'Refreshed usage_hourly_agg';
    
    -- Refresh daily
    CALL refresh_continuous_aggregate('usage_daily_agg', p_start_time, p_end_time);
    RAISE NOTICE 'Refreshed usage_daily_agg';
    
    -- Refresh weekly
    CALL refresh_continuous_aggregate('usage_weekly_agg', p_start_time, p_end_time);
    RAISE NOTICE 'Refreshed usage_weekly_agg';
    
    RAISE NOTICE 'All continuous aggregates refreshed successfully';
END;
$$;

COMMENT ON PROCEDURE sp_refresh_all_aggregates IS 'Manually refresh all continuous aggregates';

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
DECLARE
    v_agg_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_agg_count
    FROM timescaledb_information.continuous_aggregates;
    
    RAISE NOTICE 'V003 Continuous aggregates created successfully';
    RAISE NOTICE 'Total continuous aggregates: %', v_agg_count;
END $$;

-- List continuous aggregates
SELECT 
    view_name,
    view_definition IS NOT NULL as has_definition,
    materialization_hypertable_name
FROM timescaledb_information.continuous_aggregates;
