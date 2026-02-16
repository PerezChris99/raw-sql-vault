-- ============================================================================
-- Boda Accident Hotspot Mapper - Risk Quartiles Report
-- PostgreSQL 14+ with PostGIS
-- Report: User's sample query - NTILE(4) for risk quartiles
-- ============================================================================

\echo '=============================================='
\echo 'BODA ACCIDENT MAPPER - RISK QUARTILES'
\echo '=============================================='
\echo ''

-- ============================================================================
-- User's Sample Query
-- ============================================================================

\echo '>> USER SAMPLE QUERY'
\echo '   SELECT district, COUNT(*) as accidents,'
\echo '   NTILE(4) OVER (ORDER BY COUNT(*)) as risk_quartile'
\echo ''

SELECT 
    d.district_name AS district,
    COUNT(*) AS accidents,
    NTILE(4) OVER (ORDER BY COUNT(*)) AS risk_quartile
FROM accidents a
JOIN districts d ON a.district_id = d.district_id
GROUP BY d.district_name
ORDER BY accidents DESC;

\echo ''

-- ============================================================================
-- Full Risk Analysis
-- ============================================================================

\echo '>> DISTRICT RISK QUARTILES (Full Analysis)'
\echo ''

SELECT 
    district_name AS "District",
    region AS "Region",
    accidents AS "Accidents",
    total_fatalities AS "Fatalities",
    risk_quartile AS "Quartile",
    risk_level AS "Risk Level",
    accidents_per_100k AS "Per 100K"
FROM vw_district_risk_quartiles;

\echo ''

-- ============================================================================
-- Accident Hotspots (Spatial Clusters)
-- ============================================================================

\echo '>> ACCIDENT HOTSPOTS (Spatial Clusters)'
\echo ''

SELECT 
    cluster_id AS "Cluster",
    accident_count AS "Accidents",
    total_fatalities AS "Fatalities",
    risk_quartile AS "Risk Q",
    ST_AsText(ST_SnapToGrid(center_point, 0.001)) AS "Center (approx)"
FROM fn_get_hotspots(3)
LIMIT 10;

\echo ''
\echo '=============================================='
\echo 'END OF REPORT'
\echo '=============================================='
