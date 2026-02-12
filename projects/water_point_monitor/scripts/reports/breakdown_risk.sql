-- ============================================================================
-- Water Point Usage Monitor - Breakdown Risk Report
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Report: Boreholes ranked by breakdown probability
-- ============================================================================

\echo '=============================================='
\echo 'WATER POINT MONITOR - BREAKDOWN RISK REPORT'
\echo 'Generated: ' :NOW
\echo '=============================================='
\echo ''

-- ============================================================================
-- Executive Summary
-- ============================================================================

\echo '>> EXECUTIVE SUMMARY'
\echo ''

WITH summary AS (
    SELECT 
        COUNT(*) as total_boreholes,
        COUNT(*) FILTER (WHERE risk_level = 'emergency') as emergency_count,
        COUNT(*) FILTER (WHERE risk_level = 'critical') as critical_count,
        COUNT(*) FILTER (WHERE risk_level = 'warning') as warning_count,
        ROUND(AVG(risk_score), 1) as avg_risk,
        SUM(population_served) FILTER (WHERE risk_level IN ('emergency', 'critical')) as affected_population
    FROM fn_get_breakdown_risk_queue(0)
)
SELECT 
    total_boreholes as "Total Monitored",
    emergency_count as "🔴 Emergency",
    critical_count as "🟠 Critical",
    warning_count as "🟡 Warning",
    avg_risk as "Avg Risk",
    COALESCE(TO_CHAR(affected_population, 'FM999,999'), '0') as "At-Risk Population"
FROM summary;

\echo ''

-- ============================================================================
-- Top Priority - Emergency & Critical Risk
-- ============================================================================

\echo '>> HIGH PRIORITY BOREHOLES (Risk >= 60)'
\echo ''

SELECT 
    priority_rank as "#",
    borehole_name as "Borehole",
    code as "Code",
    region as "Region",
    risk_score as "Risk",
    risk_level as "Level",
    health_score as "Health",
    TO_CHAR(population_served, 'FM999,999') as "Pop Served",
    COALESCE(days_since_maintenance::TEXT || 'd', 'N/A') as "Since Maint"
FROM fn_get_breakdown_risk_queue(60, 20);

\echo ''

-- ============================================================================
-- User Sample Query: Daily Usage Comparison with LAG
-- ============================================================================

\echo '>> USAGE COMPARISON (User Sample Query Pattern)'
\echo '   SELECT borehole_id, AVG(usage), LAG(AVG(usage)) OVER ...'
\echo ''

SELECT 
    b.name as "Borehole",
    dc.date as "Date",
    TO_CHAR(dc.avg_daily, 'FM9,999,999') as "Daily Usage (L)",
    TO_CHAR(dc.prev, 'FM9,999,999') as "Prev Day (L)",
    COALESCE(dc.pct_change::TEXT || '%', 'N/A') as "Change"
FROM fn_daily_usage_comparison(NULL, 7) dc
JOIN boreholes b ON dc.borehole_id = b.borehole_id
WHERE dc.prev IS NOT NULL
ORDER BY dc.borehole_id, dc.date DESC
LIMIT 15;

\echo ''

-- ============================================================================
-- Risk Indicators Breakdown
-- ============================================================================

\echo '>> RISK INDICATORS BREAKDOWN'
\echo ''

SELECT 
    borehole_name as "Borehole",
    risk_score as "Total",
    (usage_indicator * 40)::NUMERIC(4,1) as "Usage (40)",
    (flow_indicator * 30)::NUMERIC(4,1) as "Flow (30)",
    (cycling_indicator * 15)::NUMERIC(4,1) as "Cycling (15)",
    (pressure_indicator * 10)::NUMERIC(4,1) as "Pressure (10)",
    (runtime_indicator * 5)::NUMERIC(4,1) as "Runtime (5)"
FROM boreholes b
CROSS JOIN LATERAL fn_calculate_risk_score(b.borehole_id)
WHERE b.status NOT IN ('decommissioned', 'offline')
ORDER BY risk_score DESC
LIMIT 10;

\echo ''

-- ============================================================================
-- Usage Drop Detection
-- ============================================================================

\echo '>> USAGE DROP ALERTS (>30% below average)'
\echo ''

SELECT 
    borehole_name as "Borehole",
    current_date as "Date",
    TO_CHAR(current_usage, 'FM9,999,999') as "Current (L)",
    TO_CHAR(avg_usage, 'FM9,999,999') as "Avg 7-day (L)",
    drop_pct || '%' as "Drop %",
    severity as "Severity"
FROM fn_detect_usage_drop(30, 7);

\echo ''

-- ============================================================================
-- Flow Rate Degradation
-- ============================================================================

\echo '>> FLOW RATE DEGRADATION'
\echo ''

SELECT 
    borehole_name as "Borehole",
    design_yield as "Design (LPM)",
    current_flow as "Current (LPM)",
    yield_pct || '%' as "Yield %",
    trend as "Trend",
    slope as "Slope"
FROM fn_detect_flow_degradation(14);

\echo ''

-- ============================================================================
-- Pump Cycling Anomalies
-- ============================================================================

\echo '>> EXCESSIVE PUMP CYCLING (>10 cycles/hour)'
\echo ''

SELECT 
    borehole_name as "Borehole",
    date as "Date",
    total_cycles as "Cycles",
    runtime_hours || 'h' as "Runtime",
    cycles_per_hour as "Cycles/Hour",
    severity as "Severity"
FROM fn_detect_pump_cycling(10);

\echo ''

-- ============================================================================
-- Time to Failure Predictions
-- ============================================================================

\echo '>> FAILURE PREDICTIONS (Declining Health)'
\echo ''

SELECT 
    b.name as "Borehole",
    ROUND(p.current_health, 1) as "Current Health",
    p.degradation_rate as "Daily Change",
    COALESCE(p.predicted_days_to_critical::TEXT || ' days', 'N/A') as "To Critical",
    COALESCE(p.predicted_days_to_failure::TEXT || ' days', 'N/A') as "To Failure",
    p.confidence as "Confidence"
FROM boreholes b
CROSS JOIN LATERAL fn_predict_time_to_failure(b.borehole_id) p
WHERE p.degradation_rate < 0
ORDER BY p.predicted_days_to_failure NULLS LAST
LIMIT 10;

\echo ''

-- ============================================================================
-- Active Alerts Summary
-- ============================================================================

\echo '>> ACTIVE ALERTS'
\echo ''

SELECT 
    borehole_name as "Borehole",
    alert_type as "Alert Type",
    severity as "Severity",
    risk_score as "Risk",
    hours_since_detected || 'h' as "Age",
    response_status as "Status"
FROM vw_active_alerts
ORDER BY risk_score DESC
LIMIT 10;

\echo ''
\echo '=============================================='
\echo 'END OF BREAKDOWN RISK REPORT'
\echo '=============================================='
