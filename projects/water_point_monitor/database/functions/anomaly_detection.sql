-- ============================================================================
-- Water Point Usage Monitor - Anomaly Detection Functions
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Functions for detecting usage anomalies and patterns
-- ============================================================================

-- ============================================================================
-- User Sample Query Function (LAG-based comparison)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_daily_usage_comparison(
    p_borehole_id UUID DEFAULT NULL,
    p_days_back INTEGER DEFAULT 30
)
RETURNS TABLE (
    borehole_id UUID,
    date DATE,
    avg_daily NUMERIC,
    prev NUMERIC,
    pct_change NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Implements user's sample query pattern:
    -- SELECT borehole_id, AVG(usage) as avg_daily, 
    --        LAG(AVG(usage)) OVER (PARTITION BY borehole_id ORDER BY date) as prev
    -- FROM logs GROUP BY borehole_id, date;
    
    RETURN QUERY
    WITH daily AS (
        SELECT 
            d.borehole_id,
            d.bucket::DATE as date,
            d.total_usage_liters as avg_daily
        FROM usage_daily_agg d
        WHERE d.bucket >= NOW() - (p_days_back || ' days')::INTERVAL
          AND (p_borehole_id IS NULL OR d.borehole_id = p_borehole_id)
    )
    SELECT 
        daily.borehole_id,
        daily.date,
        ROUND(daily.avg_daily, 2) as avg_daily,
        ROUND(LAG(daily.avg_daily) OVER (
            PARTITION BY daily.borehole_id 
            ORDER BY daily.date
        ), 2) as prev,
        ROUND(100.0 * (daily.avg_daily - LAG(daily.avg_daily) OVER (
            PARTITION BY daily.borehole_id 
            ORDER BY daily.date
        )) / NULLIF(LAG(daily.avg_daily) OVER (
            PARTITION BY daily.borehole_id 
            ORDER BY daily.date
        ), 0), 2) as pct_change
    FROM daily
    ORDER BY daily.borehole_id, daily.date DESC;
END;
$$;

COMMENT ON FUNCTION fn_daily_usage_comparison IS 'Daily usage with LAG comparison (user sample query pattern)';

-- ============================================================================
-- Rolling Statistics Function
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_rolling_statistics(
    p_borehole_id UUID,
    p_bucket_interval TEXT DEFAULT '1 day',
    p_window_size INTEGER DEFAULT 7
)
RETURNS TABLE (
    bucket TIMESTAMPTZ,
    usage_liters NUMERIC,
    rolling_avg NUMERIC,
    rolling_stddev NUMERIC,
    z_score NUMERIC,
    is_anomaly BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH daily_data AS (
        SELECT 
            time_bucket(p_bucket_interval::INTERVAL, d.bucket) as bucket,
            SUM(d.total_usage_liters) as usage_liters
        FROM usage_daily_agg d
        WHERE d.borehole_id = p_borehole_id
          AND d.bucket >= NOW() - INTERVAL '90 days'
        GROUP BY time_bucket(p_bucket_interval::INTERVAL, d.bucket)
    ),
    with_stats AS (
        SELECT 
            dd.bucket,
            dd.usage_liters,
            AVG(dd.usage_liters) OVER w as rolling_avg,
            STDDEV(dd.usage_liters) OVER w as rolling_stddev
        FROM daily_data dd
        WINDOW w AS (
            ORDER BY dd.bucket 
            ROWS BETWEEN (p_window_size - 1) PRECEDING AND CURRENT ROW
        )
    )
    SELECT 
        ws.bucket,
        ROUND(ws.usage_liters, 2),
        ROUND(ws.rolling_avg, 2),
        ROUND(ws.rolling_stddev, 2),
        ROUND((ws.usage_liters - ws.rolling_avg) / NULLIF(ws.rolling_stddev, 0), 2) as z_score,
        ABS((ws.usage_liters - ws.rolling_avg) / NULLIF(ws.rolling_stddev, 0)) > 2 as is_anomaly
    FROM with_stats ws
    ORDER BY ws.bucket DESC;
END;
$$;

COMMENT ON FUNCTION fn_rolling_statistics IS 'Calculate rolling statistics with anomaly detection';

-- ============================================================================
-- Detect Usage Drop
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_detect_usage_drop(
    p_threshold_pct NUMERIC DEFAULT 30.0,
    p_compare_window INTEGER DEFAULT 7
)
RETURNS TABLE (
    borehole_id UUID,
    borehole_name TEXT,
    current_date DATE,
    current_usage NUMERIC,
    avg_usage NUMERIC,
    drop_pct NUMERIC,
    severity TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH recent_stats AS (
        SELECT 
            d.borehole_id,
            d.bucket::DATE as date,
            d.total_usage_liters,
            AVG(d.total_usage_liters) OVER (
                PARTITION BY d.borehole_id 
                ORDER BY d.bucket 
                ROWS BETWEEN p_compare_window PRECEDING AND 1 PRECEDING
            ) as rolling_avg
        FROM usage_daily_agg d
        WHERE d.bucket >= NOW() - INTERVAL '14 days'
    ),
    latest AS (
        SELECT DISTINCT ON (rs.borehole_id)
            rs.borehole_id,
            rs.date,
            rs.total_usage_liters as current_usage,
            rs.rolling_avg
        FROM recent_stats rs
        ORDER BY rs.borehole_id, rs.date DESC
    )
    SELECT 
        l.borehole_id,
        b.name as borehole_name,
        l.date as current_date,
        ROUND(l.current_usage, 2),
        ROUND(l.rolling_avg, 2) as avg_usage,
        ROUND(100.0 * (l.rolling_avg - l.current_usage) / NULLIF(l.rolling_avg, 0), 2) as drop_pct,
        CASE 
            WHEN 100.0 * (l.rolling_avg - l.current_usage) / NULLIF(l.rolling_avg, 0) >= 50 THEN 'critical'
            WHEN 100.0 * (l.rolling_avg - l.current_usage) / NULLIF(l.rolling_avg, 0) >= p_threshold_pct THEN 'warning'
            ELSE 'normal'
        END as severity
    FROM latest l
    JOIN boreholes b ON l.borehole_id = b.borehole_id
    WHERE 100.0 * (l.rolling_avg - l.current_usage) / NULLIF(l.rolling_avg, 0) >= p_threshold_pct
    ORDER BY drop_pct DESC;
END;
$$;

COMMENT ON FUNCTION fn_detect_usage_drop IS 'Detect boreholes with significant usage drops';

-- ============================================================================
-- Detect Flow Rate Degradation
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_detect_flow_degradation(
    p_days_to_analyze INTEGER DEFAULT 14
)
RETURNS TABLE (
    borehole_id UUID,
    borehole_name TEXT,
    design_yield NUMERIC,
    current_flow NUMERIC,
    yield_pct NUMERIC,
    trend TEXT,
    slope NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH flow_data AS (
        SELECT 
            d.borehole_id,
            d.bucket::DATE as date,
            d.avg_flow_rate,
            ROW_NUMBER() OVER (PARTITION BY d.borehole_id ORDER BY d.bucket) as day_num
        FROM usage_daily_agg d
        WHERE d.bucket >= NOW() - (p_days_to_analyze || ' days')::INTERVAL
    ),
    regression AS (
        SELECT 
            fd.borehole_id,
            -- Linear regression slope
            (COUNT(*) * SUM(fd.day_num * fd.avg_flow_rate) - SUM(fd.day_num) * SUM(fd.avg_flow_rate)) /
            NULLIF((COUNT(*) * SUM(fd.day_num * fd.day_num) - SUM(fd.day_num) * SUM(fd.day_num)), 0) as slope,
            -- Latest flow rate
            MAX(fd.avg_flow_rate) FILTER (WHERE fd.day_num = (SELECT MAX(day_num) FROM flow_data WHERE borehole_id = fd.borehole_id)) as latest_flow
        FROM flow_data fd
        GROUP BY fd.borehole_id
    )
    SELECT 
        r.borehole_id,
        b.name as borehole_name,
        ROUND(b.yield_lpm, 2) as design_yield,
        ROUND(r.latest_flow, 2) as current_flow,
        ROUND(100.0 * r.latest_flow / NULLIF(b.yield_lpm, 0), 1) as yield_pct,
        CASE 
            WHEN r.slope < -0.5 THEN 'declining_fast'
            WHEN r.slope < -0.1 THEN 'declining'
            WHEN r.slope > 0.1 THEN 'improving'
            ELSE 'stable'
        END as trend,
        ROUND(r.slope::NUMERIC, 3) as slope
    FROM regression r
    JOIN boreholes b ON r.borehole_id = b.borehole_id
    WHERE r.latest_flow < b.yield_lpm * 0.8  -- Less than 80% of design
    ORDER BY yield_pct ASC;
END;
$$;

COMMENT ON FUNCTION fn_detect_flow_degradation IS 'Detect boreholes with declining flow rates';

-- ============================================================================
-- Detect Pump Cycling Anomaly
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_detect_pump_cycling(
    p_threshold_cycles_per_hour NUMERIC DEFAULT 10.0
)
RETURNS TABLE (
    borehole_id UUID,
    borehole_name TEXT,
    date DATE,
    total_cycles INTEGER,
    runtime_hours NUMERIC,
    cycles_per_hour NUMERIC,
    severity TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.borehole_id,
        b.name as borehole_name,
        d.bucket::DATE as date,
        d.total_pump_cycles::INTEGER,
        ROUND(d.runtime_hours, 2),
        ROUND(d.total_pump_cycles / NULLIF(d.runtime_hours, 0), 2) as cycles_per_hour,
        CASE 
            WHEN d.total_pump_cycles / NULLIF(d.runtime_hours, 0) >= 15 THEN 'critical'
            WHEN d.total_pump_cycles / NULLIF(d.runtime_hours, 0) >= p_threshold_cycles_per_hour THEN 'warning'
            ELSE 'normal'
        END as severity
    FROM usage_daily_agg d
    JOIN boreholes b ON d.borehole_id = b.borehole_id
    WHERE d.bucket >= NOW() - INTERVAL '7 days'
      AND d.total_pump_cycles / NULLIF(d.runtime_hours, 0) >= p_threshold_cycles_per_hour
    ORDER BY cycles_per_hour DESC;
END;
$$;

COMMENT ON FUNCTION fn_detect_pump_cycling IS 'Detect excessive pump on/off cycling';

-- ============================================================================
-- Time-Series Gap Detection
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_detect_data_gaps(
    p_gap_threshold_hours INTEGER DEFAULT 4
)
RETURNS TABLE (
    borehole_id UUID,
    borehole_name TEXT,
    last_reading TIMESTAMPTZ,
    hours_since_reading NUMERIC,
    status TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH last_readings AS (
        SELECT 
            u.borehole_id,
            MAX(u.logged_at) as last_reading
        FROM usage_logs u
        GROUP BY u.borehole_id
    )
    SELECT 
        lr.borehole_id,
        b.name as borehole_name,
        lr.last_reading,
        ROUND(EXTRACT(EPOCH FROM (NOW() - lr.last_reading)) / 3600, 1) as hours_since_reading,
        CASE 
            WHEN EXTRACT(EPOCH FROM (NOW() - lr.last_reading)) / 3600 >= 24 THEN 'offline'
            WHEN EXTRACT(EPOCH FROM (NOW() - lr.last_reading)) / 3600 >= p_gap_threshold_hours THEN 'gap_detected'
            ELSE 'normal'
        END as status
    FROM last_readings lr
    JOIN boreholes b ON lr.borehole_id = b.borehole_id
    WHERE EXTRACT(EPOCH FROM (NOW() - lr.last_reading)) / 3600 >= p_gap_threshold_hours
    ORDER BY hours_since_reading DESC;
END;
$$;

COMMENT ON FUNCTION fn_detect_data_gaps IS 'Detect boreholes with missing data';

-- ============================================================================
-- Seasonal Pattern Analysis
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_analyze_seasonal_pattern(
    p_borehole_id UUID
)
RETURNS TABLE (
    day_of_week INTEGER,
    day_name TEXT,
    hour_of_day INTEGER,
    avg_usage NUMERIC,
    stddev_usage NUMERIC,
    sample_count BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        EXTRACT(DOW FROM h.bucket)::INTEGER as day_of_week,
        TO_CHAR(h.bucket, 'Day') as day_name,
        EXTRACT(HOUR FROM h.bucket)::INTEGER as hour_of_day,
        ROUND(AVG(h.total_usage_liters), 2) as avg_usage,
        ROUND(STDDEV(h.total_usage_liters), 2) as stddev_usage,
        COUNT(*) as sample_count
    FROM usage_hourly_agg h
    WHERE h.borehole_id = p_borehole_id
      AND h.bucket >= NOW() - INTERVAL '90 days'
    GROUP BY EXTRACT(DOW FROM h.bucket), TO_CHAR(h.bucket, 'Day'), EXTRACT(HOUR FROM h.bucket)
    ORDER BY day_of_week, hour_of_day;
END;
$$;

COMMENT ON FUNCTION fn_analyze_seasonal_pattern IS 'Analyze hourly/daily usage patterns for a borehole';
