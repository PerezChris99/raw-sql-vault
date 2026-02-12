-- ============================================================================
-- Water Point Usage Monitor - V004 Views
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Analysis views for breakdown prediction and monitoring
-- ============================================================================

-- ============================================================================
-- Borehole Status Overview
-- ============================================================================

CREATE OR REPLACE VIEW vw_borehole_status AS
SELECT 
    b.borehole_id,
    b.name,
    b.code,
    b.status,
    b.health_score,
    r.name as region,
    bt.name as borehole_type,
    pt.name as pump_type,
    b.depth_m,
    b.yield_lpm as design_yield,
    b.population_served,
    b.installation_date,
    b.last_maintenance_date,
    b.next_maintenance_date,
    -- Days since last maintenance
    EXTRACT(DAY FROM CURRENT_TIMESTAMP - b.last_maintenance_date::TIMESTAMPTZ) as days_since_maintenance,
    -- Days until next maintenance
    EXTRACT(DAY FROM b.next_maintenance_date::TIMESTAMPTZ - CURRENT_TIMESTAMP) as days_until_maintenance,
    -- Recent usage stats (last 24h)
    (SELECT SUM(total_usage_liters) FROM usage_hourly_agg 
     WHERE borehole_id = b.borehole_id 
       AND bucket >= NOW() - INTERVAL '24 hours') as usage_last_24h,
    -- Active alerts count
    (SELECT COUNT(*) FROM breakdown_alerts 
     WHERE borehole_id = b.borehole_id 
       AND resolved = FALSE) as active_alerts
FROM boreholes b
LEFT JOIN regions r ON b.region_id = r.region_id
LEFT JOIN borehole_types bt ON b.type_id = bt.type_id
LEFT JOIN pump_types pt ON b.pump_type_id = pt.pump_type_id
WHERE b.status != 'decommissioned'
ORDER BY b.health_score ASC NULLS LAST;

COMMENT ON VIEW vw_borehole_status IS 'Overview of all active boreholes with current status';

-- ============================================================================
-- Usage Anomaly Detection View
-- ============================================================================

CREATE OR REPLACE VIEW vw_usage_anomalies AS
WITH daily_with_stats AS (
    SELECT 
        borehole_id,
        bucket as date,
        total_usage_liters,
        avg_flow_rate,
        runtime_hours,
        total_pump_cycles,
        avg_pressure,
        -- Rolling statistics
        AVG(total_usage_liters) OVER w7 as avg_7day,
        STDDEV(total_usage_liters) OVER w7 as stddev_7day,
        AVG(total_usage_liters) OVER w30 as avg_30day,
        STDDEV(total_usage_liters) OVER w30 as stddev_30day,
        -- Previous values
        LAG(total_usage_liters) OVER w as prev_day,
        LAG(avg_flow_rate) OVER w as prev_flow_rate,
        LAG(avg_pressure) OVER w as prev_pressure
    FROM usage_daily_agg
    WHERE bucket >= NOW() - INTERVAL '90 days'
    WINDOW 
        w AS (PARTITION BY borehole_id ORDER BY bucket),
        w7 AS (PARTITION BY borehole_id ORDER BY bucket ROWS BETWEEN 6 PRECEDING AND CURRENT ROW),
        w30 AS (PARTITION BY borehole_id ORDER BY bucket ROWS BETWEEN 29 PRECEDING AND CURRENT ROW)
)
SELECT 
    borehole_id,
    date,
    total_usage_liters,
    avg_7day,
    avg_30day,
    -- Anomaly flags
    CASE 
        WHEN total_usage_liters < avg_7day - (2 * stddev_7day) THEN 'low_usage'
        WHEN total_usage_liters > avg_7day + (2 * stddev_7day) THEN 'high_usage'
        ELSE 'normal'
    END as usage_anomaly,
    -- Usage drop percentage
    ROUND(100.0 * (total_usage_liters - avg_7day) / NULLIF(avg_7day, 0), 2) as pct_vs_avg,
    -- Flow rate trend
    CASE 
        WHEN avg_flow_rate < prev_flow_rate * 0.9 THEN 'declining'
        WHEN avg_flow_rate > prev_flow_rate * 1.1 THEN 'increasing'
        ELSE 'stable'
    END as flow_trend,
    -- Z-score for severity
    ROUND((total_usage_liters - avg_30day) / NULLIF(stddev_30day, 1), 2) as z_score
FROM daily_with_stats
WHERE date >= NOW() - INTERVAL '30 days'
ORDER BY borehole_id, date DESC;

COMMENT ON VIEW vw_usage_anomalies IS 'Identifies usage anomalies based on rolling statistics';

-- ============================================================================
-- Breakdown Risk Score View
-- ============================================================================

CREATE OR REPLACE VIEW vw_breakdown_risk AS
WITH recent_daily AS (
    SELECT 
        borehole_id,
        bucket as date,
        total_usage_liters,
        avg_flow_rate,
        runtime_hours,
        total_pump_cycles,
        avg_pressure,
        AVG(total_usage_liters) OVER (
            PARTITION BY borehole_id 
            ORDER BY bucket 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as rolling_7day_avg,
        AVG(avg_flow_rate) OVER (
            PARTITION BY borehole_id 
            ORDER BY bucket 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) as rolling_3day_flow
    FROM usage_daily_agg
    WHERE bucket >= NOW() - INTERVAL '30 days'
),
latest_stats AS (
    SELECT DISTINCT ON (borehole_id)
        borehole_id,
        date,
        total_usage_liters,
        rolling_7day_avg,
        avg_flow_rate,
        rolling_3day_flow,
        runtime_hours,
        total_pump_cycles,
        avg_pressure
    FROM recent_daily
    ORDER BY borehole_id, date DESC
),
risk_indicators AS (
    SELECT 
        ls.*,
        b.name as borehole_name,
        b.code,
        b.yield_lpm as design_yield,
        b.health_score,
        -- Indicator 1: Usage drop (40% weight)
        CASE 
            WHEN ls.total_usage_liters < ls.rolling_7day_avg * 0.7 THEN 1.0
            WHEN ls.total_usage_liters < ls.rolling_7day_avg * 0.85 THEN 0.5
            ELSE 0.0
        END as usage_drop_indicator,
        -- Indicator 2: Flow degradation (30% weight)
        CASE 
            WHEN ls.avg_flow_rate < b.yield_lpm * 0.6 THEN 1.0
            WHEN ls.avg_flow_rate < b.yield_lpm * 0.8 THEN 0.5
            ELSE 0.0
        END as flow_degradation_indicator,
        -- Indicator 3: Pump cycling (15% weight)
        CASE 
            WHEN ls.total_pump_cycles / NULLIF(ls.runtime_hours, 0) > 10 THEN 1.0
            WHEN ls.total_pump_cycles / NULLIF(ls.runtime_hours, 0) > 5 THEN 0.5
            ELSE 0.0
        END as cycling_indicator,
        -- Indicator 4: Pressure anomaly (10% weight)
        CASE 
            WHEN ls.avg_pressure < 1.5 OR ls.avg_pressure > 5 THEN 1.0
            WHEN ls.avg_pressure < 2 OR ls.avg_pressure > 4 THEN 0.3
            ELSE 0.0
        END as pressure_indicator,
        -- Indicator 5: Runtime increase (5% weight)
        CASE 
            WHEN ls.runtime_hours > 20 THEN 1.0
            WHEN ls.runtime_hours > 16 THEN 0.5
            ELSE 0.0
        END as runtime_indicator
    FROM latest_stats ls
    JOIN boreholes b ON ls.borehole_id = b.borehole_id
)
SELECT 
    borehole_id,
    borehole_name,
    code,
    date as last_data_date,
    health_score,
    -- Current metrics
    total_usage_liters as daily_usage,
    rolling_7day_avg,
    avg_flow_rate,
    design_yield,
    ROUND(100.0 * avg_flow_rate / NULLIF(design_yield, 0), 1) as yield_pct,
    runtime_hours,
    total_pump_cycles,
    avg_pressure,
    -- Individual indicators
    usage_drop_indicator,
    flow_degradation_indicator,
    cycling_indicator,
    pressure_indicator,
    runtime_indicator,
    -- Risk Score (0-100)
    ROUND((
        usage_drop_indicator * 40 +
        flow_degradation_indicator * 30 +
        cycling_indicator * 15 +
        pressure_indicator * 10 +
        runtime_indicator * 5
    )::NUMERIC, 1) as risk_score,
    -- Risk Level
    CASE 
        WHEN (usage_drop_indicator * 40 + flow_degradation_indicator * 30 + 
              cycling_indicator * 15 + pressure_indicator * 10 + runtime_indicator * 5) >= 80 
            THEN 'emergency'
        WHEN (usage_drop_indicator * 40 + flow_degradation_indicator * 30 + 
              cycling_indicator * 15 + pressure_indicator * 10 + runtime_indicator * 5) >= 60 
            THEN 'critical'
        WHEN (usage_drop_indicator * 40 + flow_degradation_indicator * 30 + 
              cycling_indicator * 15 + pressure_indicator * 10 + runtime_indicator * 5) >= 40 
            THEN 'warning'
        WHEN (usage_drop_indicator * 40 + flow_degradation_indicator * 30 + 
              cycling_indicator * 15 + pressure_indicator * 10 + runtime_indicator * 5) >= 20 
            THEN 'info'
        ELSE 'normal'
    END as risk_level
FROM risk_indicators
ORDER BY risk_score DESC;

COMMENT ON VIEW vw_breakdown_risk IS 'Calculates breakdown risk score for each borehole';

-- ============================================================================
-- Hourly Pattern View (for detecting usage patterns)
-- ============================================================================

CREATE OR REPLACE VIEW vw_hourly_patterns AS
SELECT 
    borehole_id,
    EXTRACT(HOUR FROM bucket) as hour_of_day,
    EXTRACT(DOW FROM bucket) as day_of_week,
    AVG(total_usage_liters) as avg_usage,
    AVG(avg_flow_rate) as avg_flow_rate,
    AVG(total_pump_cycles) as avg_cycles,
    COUNT(*) as sample_count
FROM usage_hourly_agg
WHERE bucket >= NOW() - INTERVAL '30 days'
GROUP BY borehole_id, EXTRACT(HOUR FROM bucket), EXTRACT(DOW FROM bucket)
ORDER BY borehole_id, day_of_week, hour_of_day;

COMMENT ON VIEW vw_hourly_patterns IS 'Hourly usage patterns by day of week';

-- ============================================================================
-- Maintenance Schedule View
-- ============================================================================

CREATE OR REPLACE VIEW vw_maintenance_schedule AS
SELECT 
    b.borehole_id,
    b.name,
    b.code,
    b.status,
    b.health_score,
    r.name as region,
    b.last_maintenance_date,
    b.next_maintenance_date,
    EXTRACT(DAY FROM CURRENT_TIMESTAMP - b.last_maintenance_date::TIMESTAMPTZ)::INTEGER as days_since_maintenance,
    COALESCE(
        EXTRACT(DAY FROM b.next_maintenance_date::TIMESTAMPTZ - CURRENT_TIMESTAMP)::INTEGER,
        pt.maintenance_interval_days - EXTRACT(DAY FROM CURRENT_TIMESTAMP - b.last_maintenance_date::TIMESTAMPTZ)::INTEGER
    ) as days_until_due,
    pt.maintenance_interval_days as interval_days,
    br.risk_score,
    br.risk_level,
    -- Priority: combines schedule and risk
    CASE 
        WHEN br.risk_score >= 60 THEN 'immediate'
        WHEN COALESCE(
            EXTRACT(DAY FROM b.next_maintenance_date::TIMESTAMPTZ - CURRENT_TIMESTAMP)::INTEGER,
            pt.maintenance_interval_days - EXTRACT(DAY FROM CURRENT_TIMESTAMP - b.last_maintenance_date::TIMESTAMPTZ)::INTEGER
        ) < 0 THEN 'overdue'
        WHEN COALESCE(
            EXTRACT(DAY FROM b.next_maintenance_date::TIMESTAMPTZ - CURRENT_TIMESTAMP)::INTEGER,
            pt.maintenance_interval_days - EXTRACT(DAY FROM CURRENT_TIMESTAMP - b.last_maintenance_date::TIMESTAMPTZ)::INTEGER
        ) <= 7 THEN 'due_soon'
        ELSE 'scheduled'
    END as maintenance_priority
FROM boreholes b
LEFT JOIN regions r ON b.region_id = r.region_id
LEFT JOIN pump_types pt ON b.pump_type_id = pt.pump_type_id
LEFT JOIN vw_breakdown_risk br ON b.borehole_id = br.borehole_id
WHERE b.status != 'decommissioned'
ORDER BY 
    CASE 
        WHEN br.risk_score >= 60 THEN 1
        WHEN COALESCE(
            EXTRACT(DAY FROM b.next_maintenance_date::TIMESTAMPTZ - CURRENT_TIMESTAMP)::INTEGER,
            0
        ) < 0 THEN 2
        ELSE 3
    END,
    br.risk_score DESC NULLS LAST;

COMMENT ON VIEW vw_maintenance_schedule IS 'Maintenance schedule with risk-based prioritization';

-- ============================================================================
-- Active Alerts View
-- ============================================================================

CREATE OR REPLACE VIEW vw_active_alerts AS
SELECT 
    ba.alert_id,
    ba.borehole_id,
    b.name as borehole_name,
    b.code as borehole_code,
    r.name as region,
    at.name as alert_type,
    at.severity as type_severity,
    ba.severity,
    ba.risk_score,
    ba.detected_at,
    EXTRACT(HOUR FROM CURRENT_TIMESTAMP - ba.detected_at) as hours_since_detected,
    ba.indicators,
    ba.acknowledged,
    ba.acknowledged_at,
    at.response_sla_hours,
    CASE 
        WHEN ba.acknowledged THEN 'acknowledged'
        WHEN EXTRACT(HOUR FROM CURRENT_TIMESTAMP - ba.detected_at) > at.response_sla_hours THEN 'overdue'
        ELSE 'pending'
    END as response_status
FROM breakdown_alerts ba
JOIN boreholes b ON ba.borehole_id = b.borehole_id
JOIN regions r ON b.region_id = r.region_id
LEFT JOIN alert_types at ON ba.alert_type_id = at.alert_type_id
WHERE ba.resolved = FALSE
ORDER BY ba.risk_score DESC, ba.detected_at;

COMMENT ON VIEW vw_active_alerts IS 'Currently unresolved breakdown alerts';

-- ============================================================================
-- Region Summary View
-- ============================================================================

CREATE OR REPLACE VIEW vw_region_summary AS
SELECT 
    r.region_id,
    r.name as region,
    r.code,
    r.country,
    r.climate_zone,
    COUNT(b.borehole_id) as total_boreholes,
    COUNT(b.borehole_id) FILTER (WHERE b.status = 'operational') as operational,
    COUNT(b.borehole_id) FILTER (WHERE b.status = 'degraded') as degraded,
    COUNT(b.borehole_id) FILTER (WHERE b.status = 'offline') as offline,
    ROUND(AVG(b.health_score), 1) as avg_health_score,
    SUM(b.population_served) as total_population_served,
    (SELECT COUNT(*) FROM breakdown_alerts ba 
     JOIN boreholes bb ON ba.borehole_id = bb.borehole_id
     WHERE bb.region_id = r.region_id AND ba.resolved = FALSE) as active_alerts
FROM regions r
LEFT JOIN boreholes b ON r.region_id = b.region_id AND b.status != 'decommissioned'
GROUP BY r.region_id, r.name, r.code, r.country, r.climate_zone
ORDER BY active_alerts DESC, avg_health_score;

COMMENT ON VIEW vw_region_summary IS 'Summary statistics by region';

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'V004 Views created successfully';
    RAISE NOTICE 'Views: vw_borehole_status, vw_usage_anomalies, vw_breakdown_risk, vw_hourly_patterns, vw_maintenance_schedule, vw_active_alerts, vw_region_summary';
END $$;
