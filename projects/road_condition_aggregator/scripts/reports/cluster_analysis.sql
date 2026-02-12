-- ============================================================================
-- Road Condition Aggregator - Cluster Analysis Report
-- PostgreSQL 14+ with PostGIS 3.x
-- Report: Detailed DBSCAN cluster analysis
-- ============================================================================

\echo '=============================================='
\echo 'ROAD CONDITION AGGREGATOR - CLUSTER ANALYSIS'
\echo 'Generated: ' :NOW
\echo '=============================================='
\echo ''

-- ============================================================================
-- Clustering Parameters
-- ============================================================================

\echo '>> CLUSTERING PARAMETERS'
\echo '   Algorithm: DBSCAN (Density-Based Spatial Clustering)'
\echo '   eps: 0.01 degrees (~1.1km at equator)'
\echo '   min_points: 3 (minimum reports for cluster)'
\echo ''

-- ============================================================================
-- Cluster Summary Statistics
-- ============================================================================

\echo '>> CLUSTER STATISTICS'
\echo ''

WITH stats AS (
    SELECT 
        cs.cluster_id,
        cs.report_count,
        cs.avg_severity,
        cs.max_severity,
        cs.area_sq_m,
        cs.oldest_report,
        cs.newest_report,
        cs.damage_types
    FROM fn_get_cluster_stats(0.01, 3, 30) cs
)
SELECT 
    cluster_id as "ID",
    report_count as "Reports",
    avg_severity as "Avg Sev",
    max_severity as "Max Sev",
    ROUND(area_sq_m::NUMERIC, 2) as "Area (m²)",
    ROUND((report_count / NULLIF(area_sq_m / 1000000.0, 0))::NUMERIC, 1) as "Density/km²",
    ARRAY_TO_STRING(damage_types, ', ') as "Damage Types"
FROM stats
ORDER BY avg_severity DESC;

\echo ''

-- ============================================================================
-- Cluster Size Distribution
-- ============================================================================

\echo '>> CLUSTER SIZE DISTRIBUTION'
\echo ''

WITH size_buckets AS (
    SELECT 
        CASE 
            WHEN report_count >= 10 THEN 'Large (10+)'
            WHEN report_count >= 6 THEN 'Medium (6-9)'
            ELSE 'Small (3-5)'
        END as size_category,
        report_count,
        avg_severity
    FROM fn_get_cluster_stats(0.01, 3, 30)
)
SELECT 
    size_category as "Size Category",
    COUNT(*) as "Clusters",
    ROUND(AVG(report_count), 1) as "Avg Reports",
    ROUND(AVG(avg_severity), 2) as "Avg Severity"
FROM size_buckets
GROUP BY size_category
ORDER BY 
    CASE size_category 
        WHEN 'Large (10+)' THEN 1
        WHEN 'Medium (6-9)' THEN 2
        ELSE 3 
    END;

\echo ''

-- ============================================================================
-- Noise Analysis (Unclustered Reports)
-- ============================================================================

\echo '>> NOISE ANALYSIS (Unclustered Reports)'
\echo ''

WITH all_clustered AS (
    SELECT 
        report_id,
        cluster_id,
        severity,
        location
    FROM fn_cluster_reports(0.01, 3, 30)
)
SELECT 
    CASE WHEN cluster_id IS NULL THEN 'Noise (Unclustered)' ELSE 'Clustered' END as "Category",
    COUNT(*) as "Reports",
    ROUND(AVG(severity), 2) as "Avg Severity",
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) || '%' as "Percentage"
FROM all_clustered
GROUP BY (cluster_id IS NULL)
ORDER BY COUNT(*) DESC;

\echo ''

-- ============================================================================
-- Damage Type Distribution in Clusters
-- ============================================================================

\echo '>> DAMAGE TYPE DISTRIBUTION (In Clusters)'
\echo ''

SELECT 
    dt.name as "Damage Type",
    COUNT(*) as "Reports",
    ROUND(AVG(cr.severity), 2) as "Avg Severity",
    COUNT(DISTINCT cr.cluster_id) as "Clusters"
FROM fn_cluster_reports(0.01, 3, 30) cr
JOIN damage_types dt ON cr.damage_type_id = dt.damage_id
WHERE cr.cluster_id IS NOT NULL
GROUP BY dt.name
ORDER BY COUNT(*) DESC;

\echo ''

-- ============================================================================
-- Cluster Age Analysis
-- ============================================================================

\echo '>> CLUSTER AGE ANALYSIS'
\echo ''

WITH cluster_ages AS (
    SELECT 
        cluster_id,
        report_count,
        avg_severity,
        EXTRACT(DAY FROM CURRENT_TIMESTAMP - oldest_report) as days_old,
        EXTRACT(DAY FROM newest_report - oldest_report) as report_span_days
    FROM fn_get_cluster_stats(0.01, 3, 30)
)
SELECT 
    CASE 
        WHEN days_old <= 7 THEN 'New (<7 days)'
        WHEN days_old <= 14 THEN 'Recent (7-14 days)'
        WHEN days_old <= 21 THEN 'Moderate (14-21 days)'
        ELSE 'Old (21+ days)'
    END as "Age Category",
    COUNT(*) as "Clusters",
    SUM(report_count) as "Total Reports",
    ROUND(AVG(report_span_days), 1) as "Avg Report Span (days)"
FROM cluster_ages
GROUP BY 
    CASE 
        WHEN days_old <= 7 THEN 'New (<7 days)'
        WHEN days_old <= 14 THEN 'Recent (7-14 days)'
        WHEN days_old <= 21 THEN 'Moderate (14-21 days)'
        ELSE 'Old (21+ days)'
    END
ORDER BY MIN(days_old);

\echo ''

-- ============================================================================
-- Affected Road Segments
-- ============================================================================

\echo '>> TOP AFFECTED ROAD SEGMENTS'
\echo ''

SELECT 
    rs.road_name as "Road Name",
    rc.name as "Road Class",
    COUNT(DISTINCT cr.cluster_id) as "Nearby Clusters",
    COUNT(cr.report_id) as "Reports Within 20m",
    ROUND(AVG(cr.severity), 2) as "Avg Severity"
FROM fn_cluster_reports(0.01, 3, 30) cr
JOIN road_segments rs ON ST_DWithin(rs.geom::geography, cr.location, 20)
LEFT JOIN road_classifications rc ON rs.road_class_id = rc.class_id
WHERE cr.cluster_id IS NOT NULL
GROUP BY rs.road_name, rc.name
ORDER BY COUNT(cr.report_id) DESC
LIMIT 10;

\echo ''

-- ============================================================================
-- Spatial Spread Analysis
-- ============================================================================

\echo '>> SPATIAL SPREAD ANALYSIS'
\echo ''

WITH cluster_geometry AS (
    SELECT 
        cs.cluster_id,
        cs.report_count,
        cs.area_sq_m,
        cs.avg_severity,
        -- Approximate diameter from area (assuming roughly circular)
        2 * SQRT(cs.area_sq_m / PI()) as diameter_m
    FROM fn_get_cluster_stats(0.01, 3, 30) cs
)
SELECT 
    cluster_id as "Cluster",
    report_count as "Reports",
    ROUND(diameter_m::NUMERIC, 1) as "Approx Diameter (m)",
    ROUND(area_sq_m::NUMERIC, 2) as "Area (m²)",
    ROUND((report_count / NULLIF(diameter_m / 10, 0))::NUMERIC, 2) as "Linear Density"
FROM cluster_geometry
WHERE area_sq_m > 0
ORDER BY area_sq_m DESC;

\echo ''
\echo '=============================================='
\echo 'END OF CLUSTER ANALYSIS REPORT'
\echo '=============================================='
