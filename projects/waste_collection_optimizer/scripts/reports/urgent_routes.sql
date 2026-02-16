-- ============================================================================
-- Waste Collection Optimizer - Urgent Routes Report
-- PostgreSQL 14+
-- Report: User's sample query - CTE for full bins
-- ============================================================================

\echo '=============================================='
\echo 'WASTE COLLECTION OPTIMIZER - URGENT ROUTES'
\echo '=============================================='
\echo ''

-- ============================================================================
-- User's Sample Query Pattern
-- ============================================================================

\echo '>> USER SAMPLE QUERY (Full Bins CTE)'
\echo '   WITH full_bins AS (SELECT * FROM bins WHERE level > 80)'
\echo '   SELECT route_id, COUNT(*) as urgent FROM full_bins GROUP BY route_id'
\echo ''

WITH full_bins AS (
    SELECT * FROM bins WHERE current_level > 80
)
SELECT 
    route_id AS "Route",
    COUNT(*) AS "Urgent Bins"
FROM full_bins 
GROUP BY route_id 
ORDER BY COUNT(*) DESC
LIMIT 10;

\echo ''

-- ============================================================================
-- Route Priority Queue
-- ============================================================================

\echo '>> ROUTE PRIORITY QUEUE'
\echo ''

SELECT 
    priority_rank AS "#",
    route_name AS "Route",
    zone_name AS "Zone",
    full_bins AS "Full (>80%)",
    moderate_bins AS "Moderate (50-80%)",
    avg_fill_pct || '%' AS "Avg Fill",
    urgency_score AS "Score"
FROM vw_route_priority
LIMIT 10;

\echo ''

-- ============================================================================
-- Zone Summary
-- ============================================================================

\echo '>> ZONE SUMMARY'
\echo ''

SELECT * FROM vw_zone_summary;

\echo ''

-- ============================================================================
-- Optimized Route Example
-- ============================================================================

\echo '>> OPTIMIZED ROUTE SEQUENCE (Route 1, >50% full)'
\echo ''

SELECT * FROM fn_get_optimized_route(1, 50) LIMIT 10;

\echo ''
\echo '=============================================='
\echo 'END OF REPORT'
\echo '=============================================='
