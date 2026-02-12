-- ============================================================================
-- Water Point Usage Monitor - Maintenance Schedule Report
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Report: Maintenance recommendations based on health and risk scores
-- ============================================================================

\echo '=============================================='
\echo 'WATER POINT MONITOR - MAINTENANCE SCHEDULE'
\echo 'Generated: ' :NOW
\echo '=============================================='
\echo ''

-- ============================================================================
-- Maintenance Priority Queue
-- ============================================================================

\echo '>> MAINTENANCE PRIORITY QUEUE'
\echo '   Based on risk score, health, and time since maintenance'
\echo ''

SELECT 
    priority_rank as "#",
    borehole_name as "Borehole",
    COALESCE(maintenance_type, 'Inspection') as "Type",
    next_maintenance::DATE as "Due Date",
    CASE 
        WHEN days_overdue > 0 THEN '🔴 ' || days_overdue || 'd overdue'
        WHEN days_until_due <= 7 THEN '🟠 ' || days_until_due || 'd'
        ELSE '🟢 ' || days_until_due || 'd'
    END as "Status",
    current_health as "Health",
    risk_level as "Risk Level"
FROM vw_maintenance_schedule
ORDER BY priority_rank
LIMIT 15;

\echo ''

-- ============================================================================
-- Maintenance Recommendations (AI-Driven)
-- ============================================================================

\echo '>> MAINTENANCE RECOMMENDATIONS'
\echo ''

SELECT 
    b.name as "Borehole",
    r.recommendation_type as "Type",
    r.urgency as "Urgency",
    LEFT(r.description, 50) || '...' as "Description",
    r.estimated_cost::TEXT || ' USD' as "Est. Cost"
FROM boreholes b
CROSS JOIN LATERAL fn_get_maintenance_recommendations(b.borehole_id) r
WHERE b.status NOT IN ('decommissioned', 'offline')
ORDER BY 
    CASE r.urgency 
        WHEN 'immediate' THEN 1 
        WHEN 'urgent' THEN 2 
        WHEN 'scheduled' THEN 3 
        ELSE 4 
    END,
    b.name
LIMIT 15;

\echo ''

-- ============================================================================
-- Overdue Maintenance
-- ============================================================================

\echo '>> OVERDUE MAINTENANCE'
\echo ''

SELECT 
    b.name as "Borehole",
    ms.maintenance_type as "Type",
    ms.next_maintenance::DATE as "Was Due",
    ms.days_overdue || ' days' as "Overdue",
    ms.current_health as "Health",
    TO_CHAR(b.population_served, 'FM999,999') as "Pop Served"
FROM vw_maintenance_schedule ms
JOIN boreholes b ON ms.borehole_id = b.borehole_id
WHERE ms.days_overdue > 0
ORDER BY ms.days_overdue DESC;

\echo ''

-- ============================================================================
-- Maintenance History (Last 90 Days)
-- ============================================================================

\echo '>> RECENT MAINTENANCE HISTORY (90 Days)'
\echo ''

SELECT 
    b.name as "Borehole",
    ml.maintenance_type as "Type",
    ml.maintenance_date::DATE as "Date",
    ml.performed_by as "Performed By",
    ml.cost::TEXT || ' USD' as "Cost",
    LEFT(COALESCE(ml.notes, '-'), 40) as "Notes"
FROM maintenance_logs ml
JOIN boreholes b ON ml.borehole_id = b.borehole_id
WHERE ml.maintenance_date >= CURRENT_DATE - INTERVAL '90 days'
ORDER BY ml.maintenance_date DESC
LIMIT 15;

\echo ''

-- ============================================================================
-- Components Requiring Attention
-- ============================================================================

\echo '>> COMPONENT HEALTH INDICATORS'
\echo ''

WITH pump_health AS (
    SELECT 
        b.borehole_id,
        b.name,
        pt.type_name as pump_type,
        b.installed_at,
        EXTRACT(YEAR FROM AGE(NOW(), b.installed_at)) as years_in_service,
        fn_calculate_risk_score(b.borehole_id).cycling_indicator * 100 as cycling_stress,
        fn_calculate_risk_score(b.borehole_id).pressure_indicator * 100 as pressure_stress
    FROM boreholes b
    LEFT JOIN pump_types pt ON b.pump_type_id = pt.pump_type_id
    WHERE b.status NOT IN ('decommissioned', 'offline')
)
SELECT 
    name as "Borehole",
    pump_type as "Pump Type",
    ROUND(years_in_service, 1) || ' yrs' as "Age",
    ROUND(cycling_stress, 0) || '%' as "Cycling Stress",
    ROUND(pressure_stress, 0) || '%' as "Pressure Stress",
    CASE 
        WHEN cycling_stress > 80 OR pressure_stress > 80 THEN '🔴 Replace Soon'
        WHEN cycling_stress > 50 OR pressure_stress > 50 THEN '🟠 Monitor Closely'
        ELSE '🟢 Good Condition'
    END as "Status"
FROM pump_health
ORDER BY (cycling_stress + pressure_stress) DESC
LIMIT 10;

\echo ''

-- ============================================================================
-- Maintenance Forecast (Next 30 Days)
-- ============================================================================

\echo '>> MAINTENANCE FORECAST (Next 30 Days)'
\echo ''

SELECT 
    TO_CHAR(next_maintenance, 'YYYY-MM-DD') as "Date",
    borehole_name as "Borehole",
    COALESCE(maintenance_type, 'Inspection') as "Type",
    risk_level as "Risk Level"
FROM vw_maintenance_schedule
WHERE next_maintenance BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days'
ORDER BY next_maintenance;

\echo ''

-- ============================================================================
-- Maintenance Cost Summary
-- ============================================================================

\echo '>> MAINTENANCE COST SUMMARY (Last 6 Months)'
\echo ''

SELECT 
    TO_CHAR(DATE_TRUNC('month', maintenance_date), 'YYYY-MM') as "Month",
    COUNT(*) as "Jobs",
    STRING_AGG(DISTINCT maintenance_type, ', ') as "Types",
    SUM(cost)::TEXT || ' USD' as "Total Cost",
    ROUND(AVG(cost), 2)::TEXT || ' USD' as "Avg Cost"
FROM maintenance_logs
WHERE maintenance_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY DATE_TRUNC('month', maintenance_date)
ORDER BY 1 DESC;

\echo ''

-- ============================================================================
-- Predictive Maintenance Insights
-- ============================================================================

\echo '>> PREDICTIVE MAINTENANCE INSIGHTS'
\echo '   Based on health score trends and failure predictions'
\echo ''

SELECT 
    b.name as "Borehole",
    ROUND(p.current_health, 1) as "Health",
    p.degradation_rate || '/day' as "Trend",
    COALESCE(p.predicted_days_to_critical::TEXT || ' days', 'N/A') as "To Critical",
    p.confidence as "Confidence",
    CASE 
        WHEN p.predicted_days_to_critical IS NOT NULL AND p.predicted_days_to_critical < 14 THEN 'Schedule Now'
        WHEN p.predicted_days_to_critical IS NOT NULL AND p.predicted_days_to_critical < 30 THEN 'Plan Maintenance'
        WHEN p.degradation_rate < -1 THEN 'Investigate'
        ELSE 'Continue Monitoring'
    END as "Action"
FROM boreholes b
CROSS JOIN LATERAL fn_predict_time_to_failure(b.borehole_id) p
WHERE b.status NOT IN ('decommissioned', 'offline')
ORDER BY p.predicted_days_to_critical NULLS LAST
LIMIT 10;

\echo ''

-- ============================================================================
-- Resource Planning
-- ============================================================================

\echo '>> RESOURCE PLANNING (Monthly Estimate)'
\echo ''

WITH upcoming AS (
    SELECT 
        COUNT(*) as maintenance_count,
        SUM(CASE WHEN urgency = 'immediate' THEN 1 ELSE 0 END) as immediate,
        SUM(CASE WHEN urgency = 'urgent' THEN 1 ELSE 0 END) as urgent,
        SUM(estimated_cost) as total_cost
    FROM (
        SELECT r.*
        FROM boreholes b
        CROSS JOIN LATERAL fn_get_maintenance_recommendations(b.borehole_id) r
        WHERE b.status NOT IN ('decommissioned', 'offline')
    ) sub
)
SELECT 
    maintenance_count as "Total Jobs",
    immediate as "Immediate",
    urgent as "Urgent",
    total_cost::TEXT || ' USD' as "Est. Total Cost",
    ROUND(total_cost / NULLIF(maintenance_count, 0), 2)::TEXT || ' USD' as "Avg Per Job"
FROM upcoming;

\echo ''

-- ============================================================================
-- Maintenance by Region
-- ============================================================================

\echo '>> MAINTENANCE BY REGION'
\echo ''

SELECT 
    r.region_name as "Region",
    COUNT(b.borehole_id) as "Boreholes",
    COUNT(ms.borehole_id) FILTER (WHERE ms.days_overdue > 0) as "Overdue",
    ROUND(AVG(ms.current_health), 1) as "Avg Health",
    SUM(CASE WHEN ms.risk_level IN ('critical', 'emergency') THEN 1 ELSE 0 END) as "High Risk"
FROM regions r
LEFT JOIN boreholes b ON r.region_id = b.region_id AND b.status NOT IN ('decommissioned', 'offline')
LEFT JOIN vw_maintenance_schedule ms ON b.borehole_id = ms.borehole_id
GROUP BY r.region_id, r.region_name
ORDER BY COUNT(ms.borehole_id) FILTER (WHERE ms.days_overdue > 0) DESC;

\echo ''
\echo '=============================================='
\echo 'END OF MAINTENANCE SCHEDULE REPORT'
\echo '=============================================='
