-- ============================================================================
-- Water Point Usage Monitor - Usage Trends Report
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Report: Time-series analysis using continuous aggregates
-- ============================================================================

\echo '=============================================='
\echo 'WATER POINT MONITOR - USAGE TRENDS REPORT'
\echo 'Generated: ' :NOW
\echo '=============================================='
\echo ''

-- ============================================================================
-- TimescaleDB Status
-- ============================================================================

\echo '>> TIMESCALEDB HYPERTABLES STATUS'
\echo ''

SELECT 
    hypertable_name as "Table",
    COALESCE(compression_enabled::TEXT, 'N/A') as "Compression",
    num_chunks as "Chunks",
    pg_size_pretty(hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)) as "Size"
FROM timescaledb_information.hypertables
WHERE hypertable_schema = 'public';

\echo ''

-- ============================================================================
-- Continuous Aggregates Status
-- ============================================================================

\echo '>> CONTINUOUS AGGREGATES STATUS'
\echo ''

SELECT 
    view_name as "Aggregate View",
    materialization_hypertable_name as "Storage",
    CASE WHEN compression_enabled THEN 'Yes' ELSE 'No' END as "Compressed"
FROM timescaledb_information.continuous_aggregates
WHERE view_schema = 'public';

\echo ''

-- ============================================================================
-- Overall Usage Statistics (Last 30 Days)
-- ============================================================================

\echo '>> OVERALL USAGE STATISTICS (30-Day Window)'
\echo ''

SELECT 
    COUNT(DISTINCT bucket_day) as "Days Tracked",
    TO_CHAR(SUM(total_volume), 'FM999,999,999') as "Total Volume (L)",
    TO_CHAR(AVG(total_volume), 'FM999,999') as "Avg Daily (L)",
    ROUND(AVG(avg_flow_rate), 1) as "Avg Flow (LPM)",
    TO_CHAR(MAX(max_volume), 'FM9,999,999') as "Peak Day (L)",
    ROUND(MAX(max_flow_rate), 1) as "Peak Flow (LPM)"
FROM usage_daily_agg
WHERE bucket_day >= CURRENT_DATE - INTERVAL '30 days';

\echo ''

-- ============================================================================
-- Weekly Usage Trends
-- ============================================================================

\echo '>> WEEKLY USAGE TRENDS (Last 8 Weeks)'
\echo ''

WITH weekly_stats AS (
    SELECT 
        bucket_week,
        SUM(total_volume) as volume,
        LAG(SUM(total_volume)) OVER (ORDER BY bucket_week) as prev_volume
    FROM usage_weekly_agg
    WHERE bucket_week >= CURRENT_DATE - INTERVAL '8 weeks'
    GROUP BY bucket_week
)
SELECT 
    TO_CHAR(bucket_week, 'YYYY-MM-DD') as "Week Start",
    TO_CHAR(volume, 'FM999,999,999') as "Total Volume (L)",
    COALESCE(
        ROUND(((volume - prev_volume) / NULLIF(prev_volume, 0) * 100)::NUMERIC, 1)::TEXT || '%',
        'N/A'
    ) as "WoW Change"
FROM weekly_stats
ORDER BY bucket_week;

\echo ''

-- ============================================================================
-- Daily Usage Pattern by Borehole (Last 7 Days)
-- ============================================================================

\echo '>> DAILY USAGE BY BOREHOLE (Last 7 Days)'
\echo ''

SELECT 
    b.name as "Borehole",
    TO_CHAR(SUM(d.total_volume), 'FM9,999,999') as "7-Day Total (L)",
    TO_CHAR(AVG(d.total_volume), 'FM9,999,999') as "Daily Avg (L)",
    ROUND(AVG(d.avg_flow_rate), 1) as "Avg Flow (LPM)",
    ROUND(AVG(d.avg_efficiency), 1) || '%' as "Efficiency"
FROM usage_daily_agg d
JOIN boreholes b ON d.borehole_id = b.borehole_id
WHERE d.bucket_day >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY b.borehole_id, b.name
ORDER BY SUM(d.total_volume) DESC;

\echo ''

-- ============================================================================
-- Hourly Usage Patterns (Peak Hours Analysis)
-- ============================================================================

\echo '>> HOURLY USAGE PATTERNS (Average by Hour)'
\echo ''

SELECT 
    EXTRACT(HOUR FROM bucket_hour) as "Hour",
    TO_CHAR(AVG(total_volume), 'FM999,999') as "Avg Volume (L)",
    ROUND(AVG(avg_flow_rate), 1) as "Avg Flow (LPM)",
    CASE 
        WHEN EXTRACT(HOUR FROM bucket_hour) BETWEEN 6 AND 9 THEN 'Morning Peak'
        WHEN EXTRACT(HOUR FROM bucket_hour) BETWEEN 11 AND 14 THEN 'Midday Peak'
        WHEN EXTRACT(HOUR FROM bucket_hour) BETWEEN 17 AND 20 THEN 'Evening Peak'
        ELSE 'Off-Peak'
    END as "Period"
FROM usage_hourly_agg
WHERE bucket_hour >= NOW() - INTERVAL '7 days'
GROUP BY EXTRACT(HOUR FROM bucket_hour)
ORDER BY 1;

\echo ''

-- ============================================================================
-- Day-over-Day Comparison (TimescaleDB LAG Pattern)
-- ============================================================================

\echo '>> DAY-OVER-DAY USAGE COMPARISON'
\echo '   Using LAG() window function per user sample query'
\echo ''

SELECT 
    borehole as "Borehole",
    TO_CHAR(date, 'YYYY-MM-DD') as "Date",
    TO_CHAR(avg_daily, 'FM999,999') as "Daily Total (L)",
    TO_CHAR(prev, 'FM999,999') as "Previous Day (L)",
    COALESCE(pct_change::TEXT || '%', 'N/A') as "Change",
    CASE 
        WHEN pct_change > 20 THEN '📈 Surge'
        WHEN pct_change < -20 THEN '📉 Drop'
        ELSE '➖ Stable'
    END as "Trend"
FROM vw_daily_usage_comparison
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date DESC, borehole
LIMIT 20;

\echo ''

-- ============================================================================
-- Rolling Statistics (Time-Series Analysis)
-- ============================================================================

\echo '>> ROLLING STATISTICS (7-Day Window)'
\echo ''

SELECT 
    borehole_name as "Borehole",
    current_usage as "Today (L)",
    ROUND(rolling_avg, 0) as "7-Day Avg",
    ROUND(rolling_stddev, 0) as "Std Dev",
    z_score as "Z-Score",
    CASE 
        WHEN ABS(z_score) > 3 THEN '🚨 Extreme'
        WHEN ABS(z_score) > 2 THEN '⚠️ Unusual'
        ELSE '✅ Normal'
    END as "Status"
FROM fn_rolling_statistics(7)
ORDER BY ABS(z_score) DESC;

\echo ''

-- ============================================================================
-- Regional Usage Summary
-- ============================================================================

\echo '>> REGIONAL USAGE SUMMARY (Last 30 Days)'
\echo ''

SELECT 
    region_name as "Region",
    borehole_count as "Boreholes",
    active_count as "Active",
    TO_CHAR(total_population, 'FM999,999') as "Population",
    latest_avg_health as "Avg Health"
FROM vw_region_summary
ORDER BY total_population DESC;

\echo ''

-- ============================================================================
-- Seasonal Pattern Analysis
-- ============================================================================

\echo '>> SEASONAL PATTERN ANALYSIS'
\echo ''

SELECT 
    borehole_name as "Borehole",
    day_type as "Day Type",
    dow_name as "Peak Day",
    ROUND(dow_avg_volume::NUMERIC, 0) as "Peak Day Vol (L)",
    peak_hour || ':00' as "Peak Hour",
    ROUND(peak_avg_volume::NUMERIC, 0) as "Peak Hour Vol (L)"
FROM fn_analyze_seasonal_pattern(NULL, 30);

\echo ''

-- ============================================================================
-- Data Gaps Detection
-- ============================================================================

\echo '>> DATA GAPS (Missing Records)'
\echo ''

SELECT 
    borehole_name as "Borehole",
    TO_CHAR(gap_start, 'YYYY-MM-DD HH24:MI') as "Gap Start",
    TO_CHAR(gap_end, 'YYYY-MM-DD HH24:MI') as "Gap End",
    gap_hours || 'h' as "Duration",
    CASE 
        WHEN gap_hours > 24 THEN '🔴 Critical'
        WHEN gap_hours > 12 THEN '🟠 Major'
        ELSE '🟡 Minor'
    END as "Severity"
FROM fn_detect_data_gaps(3)
ORDER BY gap_hours DESC
LIMIT 10;

\echo ''

-- ============================================================================
-- Usage Anomalies
-- ============================================================================

\echo '>> USAGE ANOMALIES DETECTED'
\echo ''

SELECT 
    borehole_name as "Borehole",
    anomaly_hour as "Time",
    anomaly_type as "Type",
    TO_CHAR(hourly_volume, 'FM999,999') as "Volume (L)",
    ROUND(z_score, 2) as "Z-Score",
    severity as "Severity"
FROM vw_usage_anomalies
ORDER BY anomaly_hour DESC
LIMIT 10;

\echo ''
\echo '=============================================='
\echo 'END OF USAGE TRENDS REPORT'
\echo '=============================================='
