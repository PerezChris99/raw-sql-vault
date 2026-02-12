-- ============================================================================
-- Power Outage Pattern Analyzer - Hotspot Detection Report
-- Identifies clusters and hotspots of power outages using PostGIS
-- Run: psql -d power_outage_db -f hotspot_detection.sql
-- ============================================================================

\echo '=========================================='
\echo 'POWER OUTAGE HOTSPOT DETECTION REPORT'
\echo '=========================================='
\echo ''

\pset format aligned
\pset border 2
\pset linestyle unicode

-- Current timestamp
SELECT CURRENT_TIMESTAMP as "Report Generated At";

\echo ''
\echo '1. K-MEANS CLUSTERING ANALYSIS (Last 6 Months)'
\echo '------------------------------------------------'
\echo 'Identifying top 5 outage clusters using ST_ClusterKMeans...'
\echo ''

SELECT 
    cluster_id as "Cluster",
    outage_count as "Outages",
    total_customers_affected as "Customers Impacted",
    avg_duration_minutes as "Avg Duration (min)",
    ROUND(area_sq_km, 2) as "Area (km²)",
    primary_cause as "Primary Cause",
    ROUND(avg_severity_score, 2) as "Severity Score"
FROM fn_cluster_outages_kmeans(5, 180, 3)
ORDER BY outage_count DESC;

\echo ''
\echo '2. DBSCAN DENSITY CLUSTERING (Last 90 Days)'
\echo '-------------------------------------------'
\echo 'Identifying dense failure zones (500m radius, min 3 points)...'
\echo ''

SELECT 
    COALESCE(cluster_id::TEXT, 'NOISE') as "Cluster/Noise",
    point_count as "Outage Count",
    CASE WHEN is_noise THEN 'Isolated' ELSE 'Dense Zone' END as "Classification",
    ROUND(avg_customers_affected) as "Avg Customers",
    dominant_cause_category as "Cause Category"
FROM fn_cluster_outages_dbscan(500, 3, 90)
ORDER BY 
    CASE WHEN is_noise THEN 1 ELSE 0 END,
    point_count DESC
LIMIT 15;

\echo ''
\echo '3. GRID-BASED HOTSPOT ANALYSIS (1km Grid)'
\echo '-----------------------------------------'
\echo 'Top 10 highest-density grid cells...'
\echo ''

SELECT 
    hotspot_rank as "Rank",
    outage_count as "Outages",
    total_customers_affected as "Total Customers",
    avg_duration_minutes as "Avg Duration (min)",
    density_per_sq_km as "Density (/km²)",
    risk_score as "Risk Score"
FROM fn_identify_hotspots(10, 1000, 90);

\echo ''
\echo '4. PERSISTENT PROBLEM AREAS'
\echo '---------------------------'
\echo 'Areas with recurring outages across multiple 30-day periods...'
\echo ''

SELECT 
    periods_active as "Periods Active",
    total_outages as "Total Outages",
    total_customers_affected as "Customers Affected",
    avg_outages_per_period as "Avg/Period",
    persistence_score as "Persistence Score",
    primary_cause as "Common Cause"
FROM fn_persistent_clusters(3, 30, 500)
ORDER BY persistence_score DESC
LIMIT 10;

\echo ''
\echo '5. DISTRICT-LEVEL HOTSPOT SUMMARY'
\echo '---------------------------------'
\echo 'Outage density by district (last 90 days)...'
\echo ''

SELECT 
    d.name as "District",
    d.code as "Code",
    COUNT(o.outage_id) as "Outages",
    SUM(o.customers_affected) as "Customers Affected",
    ROUND(AVG(o.duration_minutes)) as "Avg Duration (min)",
    ROUND(
        COUNT(o.outage_id)::NUMERIC / NULLIF(ST_Area(d.boundary::geography) / 1000000, 0),
        2
    ) as "Density (/km²)",
    CASE 
        WHEN COUNT(o.outage_id) >= 20 THEN 'CRITICAL'
        WHEN COUNT(o.outage_id) >= 10 THEN 'HIGH'
        WHEN COUNT(o.outage_id) >= 5 THEN 'MEDIUM'
        ELSE 'LOW'
    END as "Risk Level"
FROM districts d
LEFT JOIN outages o ON d.district_id = o.district_id
    AND o.occurred_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY d.district_id, d.name, d.code, d.boundary
ORDER BY COUNT(o.outage_id) DESC;

\echo ''
\echo '6. SAMPLE: User Query (ST_ClusterKMeans)'
\echo '----------------------------------------'
\echo 'Demonstrating the sample query from requirements...'
\echo ''

-- The user's sample query pattern: 
-- SELECT district, COUNT(*) as outages, ST_ClusterKMeans(geom, 5) OVER () as cluster
-- FROM outages GROUP BY district;

SELECT 
    d.name as district,
    COUNT(*) as outages,
    ST_ClusterKMeans(o.location::geometry, 5) OVER () as cluster
FROM outages o
JOIN districts d ON o.district_id = d.district_id
WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '180 days'
GROUP BY d.name, o.location
ORDER BY cluster, outages DESC
LIMIT 20;

\echo ''
\echo '7. CLUSTER CENTER COORDINATES'
\echo '-----------------------------'
\echo 'For mapping/GIS export...'
\echo ''

WITH clusters AS (
    SELECT 
        cluster_id,
        cluster_center,
        outage_count,
        total_customers_affected
    FROM fn_cluster_outages_kmeans(5, 180, 3)
)
SELECT 
    cluster_id as "Cluster",
    ROUND(ST_X(cluster_center)::NUMERIC, 6) as "Longitude",
    ROUND(ST_Y(cluster_center)::NUMERIC, 6) as "Latitude",
    outage_count as "Outages",
    total_customers_affected as "Customers"
FROM clusters;

\echo ''
\echo '========================================'
\echo 'END OF HOTSPOT DETECTION REPORT'
\echo '========================================'
