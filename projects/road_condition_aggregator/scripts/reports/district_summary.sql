-- ============================================================================
-- Road Condition Aggregator - District Summary Report
-- PostgreSQL 14+ with PostGIS 3.x
-- Report: District-level analysis with geographic aggregation
-- ============================================================================

\echo '=============================================='
\echo 'ROAD CONDITION AGGREGATOR - DISTRICT SUMMARY'
\echo 'Generated: ' :NOW
\echo '=============================================='
\echo ''

-- ============================================================================
-- District Overview
-- ============================================================================

\echo '>> DISTRICT OVERVIEW'
\echo ''

SELECT 
    district_name as "District",
    district_code as "Code",
    ROUND(area_sq_km, 2) as "Area (km²)",
    TO_CHAR(population, 'FM999,999') as "Population",
    total_reports as "Total Reports",
    reports_per_sq_km as "Reports/km²"
FROM vw_district_summary
ORDER BY total_reports DESC;

\echo ''

-- ============================================================================
-- District Report Status
-- ============================================================================

\echo '>> DISTRICT REPORT STATUS (Last 90 Days)'
\echo ''

SELECT 
    district_name as "District",
    new_reports as "New",
    verified_reports as "Verified",
    total_reports as "Total",
    reports_last_7d as "Last 7d",
    ROUND(avg_severity, 2) as "Avg Sev",
    pothole_count as "Potholes"
FROM vw_district_summary
ORDER BY avg_severity DESC NULLS LAST;

\echo ''

-- ============================================================================
-- District Priority Analysis
-- ============================================================================

\echo '>> DISTRICT PRIORITY ANALYSIS'
\echo ''

SELECT 
    district_name as "District",
    total_clusters as "Clusters",
    total_reports as "Reports",
    avg_priority_score as "Avg Priority",
    max_priority_score as "Max Priority",
    high_priority_clusters as "High Priority (70+)",
    '$' || TO_CHAR(estimated_total_cost, 'FM999,999.00') as "Est. Cost"
FROM fn_district_priority_summary()
ORDER BY avg_priority_score DESC;

\echo ''

-- ============================================================================
-- District Clusters Detail
-- ============================================================================

\echo '>> TOP CLUSTERS BY DISTRICT'
\echo ''

WITH ranked_clusters AS (
    SELECT 
        d.name as district_name,
        pq.cluster_id,
        pq.report_count,
        pq.avg_severity,
        pq.priority_score,
        ROW_NUMBER() OVER (PARTITION BY d.name ORDER BY pq.priority_score DESC) as district_rank
    FROM fn_get_priority_queue(0.01, 3, 30) pq
    JOIN districts d ON ST_Contains(d.boundary, pq.work_center::geometry)
)
SELECT 
    district_name as "District",
    cluster_id as "Cluster",
    report_count as "Reports",
    avg_severity as "Avg Sev",
    priority_score as "Priority"
FROM ranked_clusters
WHERE district_rank <= 3
ORDER BY district_name, priority_score DESC;

\echo ''

-- ============================================================================
-- District Repair Capacity
-- ============================================================================

\echo '>> DISTRICT CREW CAPACITY'
\echo ''

WITH district_crews AS (
    SELECT 
        d.name as district_name,
        c.crew_id,
        c.name as crew_name,
        c.status,
        c.crew_type
    FROM districts d
    LEFT JOIN crews c ON ST_Contains(d.boundary, c.current_location::geometry)
),
district_workload AS (
    SELECT 
        d.name as district_name,
        COUNT(rr.report_id) FILTER (WHERE rr.status IN ('new', 'verified')) as pending_reports
    FROM districts d
    LEFT JOIN road_reports rr ON d.district_id = rr.district_id
    GROUP BY d.name
)
SELECT 
    dc.district_name as "District",
    COUNT(DISTINCT dc.crew_id) as "Crews",
    COUNT(DISTINCT dc.crew_id) FILTER (WHERE dc.status = 'available') as "Available",
    STRING_AGG(DISTINCT dc.crew_type, ', ') as "Crew Types",
    dw.pending_reports as "Pending Reports"
FROM district_crews dc
LEFT JOIN district_workload dw ON dc.district_name = dw.district_name
GROUP BY dc.district_name, dw.pending_reports
ORDER BY dw.pending_reports DESC NULLS LAST;

\echo ''

-- ============================================================================
-- Road Network by District
-- ============================================================================

\echo '>> ROAD NETWORK BY DISTRICT'
\echo ''

SELECT 
    d.name as "District",
    COUNT(rs.segment_id) as "Segments",
    ROUND(SUM(rs.length_m) / 1000, 2) as "Total km",
    ROUND(AVG(rs.pavement_condition), 1) as "Avg Condition",
    STRING_AGG(DISTINCT rc.name, ', ') as "Road Types"
FROM districts d
LEFT JOIN road_segments rs ON d.district_id = rs.district_id
LEFT JOIN road_classifications rc ON rs.road_class_id = rc.class_id
GROUP BY d.name
ORDER BY SUM(rs.length_m) DESC NULLS LAST;

\echo ''

-- ============================================================================
-- District Damage Type Breakdown
-- ============================================================================

\echo '>> DAMAGE TYPES BY DISTRICT'
\echo ''

SELECT 
    d.name as "District",
    COUNT(*) FILTER (WHERE dt.name = 'Pothole') as "Potholes",
    COUNT(*) FILTER (WHERE dt.name = 'Crack') as "Cracks",
    COUNT(*) FILTER (WHERE dt.name = 'Alligator Cracking') as "Alligator",
    COUNT(*) FILTER (WHERE dt.name = 'Rutting') as "Rutting",
    COUNT(*) FILTER (WHERE dt.name NOT IN ('Pothole', 'Crack', 'Alligator Cracking', 'Rutting')) as "Other"
FROM districts d
LEFT JOIN road_reports rr ON d.district_id = rr.district_id
    AND rr.reported_at >= CURRENT_DATE - INTERVAL '90 days'
LEFT JOIN damage_types dt ON rr.damage_type_id = dt.damage_id
GROUP BY d.name
ORDER BY COUNT(rr.report_id) DESC;

\echo ''

-- ============================================================================
-- District Heat Map Data (for GIS export)
-- ============================================================================

\echo '>> DISTRICT HEAT MAP DATA'
\echo ''

SELECT 
    d.name as "District",
    d.code as "Code",
    ROUND(ST_X(ST_Centroid(d.boundary))::NUMERIC, 6) as "Center Lon",
    ROUND(ST_Y(ST_Centroid(d.boundary))::NUMERIC, 6) as "Center Lat",
    total_reports as "Reports",
    CASE 
        WHEN avg_severity >= 7 THEN '🔴 High'
        WHEN avg_severity >= 5 THEN '🟡 Medium'
        WHEN avg_severity >= 3 THEN '🟢 Low'
        ELSE '⚪ None'
    END as "Severity Level"
FROM vw_district_summary
JOIN districts d USING (district_id)
ORDER BY avg_severity DESC NULLS LAST;

\echo ''

-- ============================================================================
-- Weekly Trends by District
-- ============================================================================

\echo '>> WEEKLY TRENDS BY DISTRICT (Last 4 Weeks)'
\echo ''

SELECT 
    d.name as "District",
    COUNT(*) FILTER (WHERE rr.reported_at >= CURRENT_DATE - INTERVAL '7 days') as "This Week",
    COUNT(*) FILTER (WHERE rr.reported_at >= CURRENT_DATE - INTERVAL '14 days' 
                       AND rr.reported_at < CURRENT_DATE - INTERVAL '7 days') as "Last Week",
    COUNT(*) FILTER (WHERE rr.reported_at >= CURRENT_DATE - INTERVAL '21 days' 
                       AND rr.reported_at < CURRENT_DATE - INTERVAL '14 days') as "2 Weeks Ago",
    COUNT(*) FILTER (WHERE rr.reported_at >= CURRENT_DATE - INTERVAL '28 days' 
                       AND rr.reported_at < CURRENT_DATE - INTERVAL '21 days') as "3 Weeks Ago",
    CASE 
        WHEN COUNT(*) FILTER (WHERE rr.reported_at >= CURRENT_DATE - INTERVAL '7 days') > 
             COUNT(*) FILTER (WHERE rr.reported_at >= CURRENT_DATE - INTERVAL '14 days' 
                              AND rr.reported_at < CURRENT_DATE - INTERVAL '7 days')
        THEN '📈 Increasing'
        WHEN COUNT(*) FILTER (WHERE rr.reported_at >= CURRENT_DATE - INTERVAL '7 days') < 
             COUNT(*) FILTER (WHERE rr.reported_at >= CURRENT_DATE - INTERVAL '14 days' 
                              AND rr.reported_at < CURRENT_DATE - INTERVAL '7 days')
        THEN '📉 Decreasing'
        ELSE '➡️ Stable'
    END as "Trend"
FROM districts d
LEFT JOIN road_reports rr ON d.district_id = rr.district_id
    AND rr.reported_at >= CURRENT_DATE - INTERVAL '28 days'
GROUP BY d.name
ORDER BY COUNT(*) DESC;

\echo ''
\echo '=============================================='
\echo 'END OF DISTRICT SUMMARY REPORT'
\echo '=============================================='
