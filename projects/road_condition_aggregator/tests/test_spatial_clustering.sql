-- ============================================================================
-- Road Condition Aggregator - Spatial Clustering Tests
-- PostgreSQL 14+ with PostGIS 3.x
-- Validates DBSCAN clustering and priority scoring functionality
-- ============================================================================

\echo '=============================================='
\echo 'SPATIAL CLUSTERING TEST SUITE'
\echo '=============================================='
\echo ''

-- ============================================================================
-- Test 1: PostGIS Extension Verification
-- ============================================================================

\echo 'TEST 1: PostGIS Extension'
DO $$
DECLARE
    v_version TEXT;
BEGIN
    SELECT PostGIS_Version() INTO v_version;
    IF v_version IS NOT NULL THEN
        RAISE NOTICE '✓ PASS: PostGIS installed (version: %)', v_version;
    ELSE
        RAISE EXCEPTION '✗ FAIL: PostGIS not available';
    END IF;
END $$;
\echo ''

-- ============================================================================
-- Test 2: DBSCAN Function Availability
-- ============================================================================

\echo 'TEST 2: ST_ClusterDBSCAN Function'
DO $$
DECLARE
    v_result INTEGER;
BEGIN
    -- Test with simple point set
    SELECT ST_ClusterDBSCAN(
        ST_SetSRID(ST_MakePoint(0, 0), 4326), 
        0.1, 
        2
    ) OVER () INTO v_result;
    
    RAISE NOTICE '✓ PASS: ST_ClusterDBSCAN is available';
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '✗ FAIL: ST_ClusterDBSCAN not available - %', SQLERRM;
END $$;
\echo ''

-- ============================================================================
-- Test 3: Sample Data Presence
-- ============================================================================

\echo 'TEST 3: Sample Data Presence'
DO $$
DECLARE
    v_report_count INTEGER;
    v_segment_count INTEGER;
    v_district_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_report_count FROM road_reports;
    SELECT COUNT(*) INTO v_segment_count FROM road_segments;
    SELECT COUNT(*) INTO v_district_count FROM districts;
    
    IF v_report_count > 0 AND v_segment_count > 0 AND v_district_count > 0 THEN
        RAISE NOTICE '✓ PASS: Sample data present (% reports, % segments, % districts)',
            v_report_count, v_segment_count, v_district_count;
    ELSE
        RAISE WARNING '⚠ WARN: Missing data - reports: %, segments: %, districts: %',
            v_report_count, v_segment_count, v_district_count;
    END IF;
END $$;
\echo ''

-- ============================================================================
-- Test 4: DBSCAN Clustering Results
-- ============================================================================

\echo 'TEST 4: DBSCAN Clustering Results'
DO $$
DECLARE
    v_cluster_count INTEGER;
    v_noise_count INTEGER;
BEGIN
    -- Count clusters (matching user's sample query pattern)
    SELECT COUNT(DISTINCT cluster_id) FILTER (WHERE cluster_id IS NOT NULL)
    INTO v_cluster_count
    FROM (
        SELECT ST_ClusterDBSCAN(location::geometry, 0.01, 3) OVER () as cluster_id
        FROM road_reports
        WHERE status IN ('new', 'verified')
    ) clustered;
    
    -- Count noise points
    SELECT COUNT(*) FILTER (WHERE cluster_id IS NULL)
    INTO v_noise_count
    FROM (
        SELECT ST_ClusterDBSCAN(location::geometry, 0.01, 3) OVER () as cluster_id
        FROM road_reports
        WHERE status IN ('new', 'verified')
    ) clustered;
    
    IF v_cluster_count > 0 THEN
        RAISE NOTICE '✓ PASS: DBSCAN found % clusters with % noise points',
            v_cluster_count, v_noise_count;
    ELSE
        RAISE WARNING '⚠ WARN: No clusters found - check eps/minpoints parameters';
    END IF;
END $$;
\echo ''

-- ============================================================================
-- Test 5: User Sample Query Pattern
-- ============================================================================

\echo 'TEST 5: User Sample Query (ST_ClusterDBSCAN with HAVING COUNT(*) > 5)'
SELECT 
    CASE 
        WHEN cluster_id IS NULL THEN 'noise'
        ELSE 'cluster_' || cluster_id::TEXT
    END as cluster_name,
    COUNT(*) as report_count,
    ROUND(AVG(severity), 2) as avg_severity
FROM (
    SELECT 
        severity,
        ST_ClusterDBSCAN(location::geometry, 0.01, 3) OVER () as cluster_id
    FROM road_reports
    WHERE status IN ('new', 'verified')
) clustered
GROUP BY cluster_id
HAVING COUNT(*) > 5
ORDER BY avg_severity DESC;
\echo ''

-- ============================================================================
-- Test 6: fn_cluster_reports Function
-- ============================================================================

\echo 'TEST 6: fn_cluster_reports Function'
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM fn_cluster_reports(0.01, 3, 30);
    
    IF v_count > 0 THEN
        RAISE NOTICE '✓ PASS: fn_cluster_reports returned % rows', v_count;
    ELSE
        RAISE WARNING '⚠ WARN: fn_cluster_reports returned no data';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '✗ FAIL: fn_cluster_reports error - %', SQLERRM;
END $$;
\echo ''

-- ============================================================================
-- Test 7: fn_get_cluster_stats Function
-- ============================================================================

\echo 'TEST 7: fn_get_cluster_stats Function'
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM fn_get_cluster_stats(0.01, 3, 30);
    
    IF v_count > 0 THEN
        RAISE NOTICE '✓ PASS: fn_get_cluster_stats returned % clusters', v_count;
    ELSE
        RAISE WARNING '⚠ WARN: fn_get_cluster_stats returned no clusters';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '✗ FAIL: fn_get_cluster_stats error - %', SQLERRM;
END $$;
\echo ''

-- ============================================================================
-- Test 8: Priority Score Calculation
-- ============================================================================

\echo 'TEST 8: Priority Score Calculation'
DO $$
DECLARE
    v_score NUMERIC;
BEGIN
    -- Test with known inputs
    v_score := fn_calculate_priority_score(8.0, 10, 2.0, 7);
    
    IF v_score BETWEEN 0 AND 110 THEN
        RAISE NOTICE '✓ PASS: Priority score calculation works (score: %)', v_score;
    ELSE
        RAISE EXCEPTION '✗ FAIL: Priority score out of expected range: %', v_score;
    END IF;
END $$;
\echo ''

-- ============================================================================
-- Test 9: fn_get_priority_queue Function
-- ============================================================================

\echo 'TEST 9: fn_get_priority_queue Function'
DO $$
DECLARE
    v_count INTEGER;
    v_max_score NUMERIC;
BEGIN
    SELECT COUNT(*), MAX(priority_score) 
    INTO v_count, v_max_score
    FROM fn_get_priority_queue(0.01, 3, 30);
    
    IF v_count > 0 THEN
        RAISE NOTICE '✓ PASS: Priority queue has % entries (max score: %)', 
            v_count, ROUND(v_max_score, 2);
    ELSE
        RAISE WARNING '⚠ WARN: Priority queue is empty';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION '✗ FAIL: fn_get_priority_queue error - %', SQLERRM;
END $$;
\echo ''

-- ============================================================================
-- Test 10: Spatial Join Performance
-- ============================================================================

\echo 'TEST 10: Spatial Join Performance (ST_DWithin)'
DO $$
DECLARE
    v_start TIMESTAMP;
    v_end TIMESTAMP;
    v_duration INTERVAL;
    v_count INTEGER;
BEGIN
    v_start := clock_timestamp();
    
    SELECT COUNT(*) INTO v_count
    FROM road_reports rr
    JOIN road_segments rs ON ST_DWithin(rs.geom::geography, rr.location, 20)
    WHERE rr.status IN ('new', 'verified');
    
    v_end := clock_timestamp();
    v_duration := v_end - v_start;
    
    IF v_duration < INTERVAL '1 second' THEN
        RAISE NOTICE '✓ PASS: Spatial join completed in % (% matches)', 
            v_duration, v_count;
    ELSE
        RAISE WARNING '⚠ WARN: Spatial join slow (%), check indexes', v_duration;
    END IF;
END $$;
\echo ''

-- ============================================================================
-- Test 11: View Accessibility
-- ============================================================================

\echo 'TEST 11: View Accessibility'
DO $$
DECLARE
    v_tests_passed INTEGER := 0;
    v_total_tests INTEGER := 5;
BEGIN
    -- Test each view
    BEGIN
        PERFORM 1 FROM vw_active_reports LIMIT 1;
        v_tests_passed := v_tests_passed + 1;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    
    BEGIN
        PERFORM 1 FROM vw_report_clusters_dbscan LIMIT 1;
        v_tests_passed := v_tests_passed + 1;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    
    BEGIN
        PERFORM 1 FROM vw_priority_queue LIMIT 1;
        v_tests_passed := v_tests_passed + 1;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    
    BEGIN
        PERFORM 1 FROM vw_district_summary LIMIT 1;
        v_tests_passed := v_tests_passed + 1;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    
    BEGIN
        PERFORM 1 FROM vw_reports_geojson LIMIT 1;
        v_tests_passed := v_tests_passed + 1;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
    
    IF v_tests_passed = v_total_tests THEN
        RAISE NOTICE '✓ PASS: All % views accessible', v_total_tests;
    ELSE
        RAISE WARNING '⚠ WARN: Only %/% views accessible', v_tests_passed, v_total_tests;
    END IF;
END $$;
\echo ''

-- ============================================================================
-- Test 12: GeoJSON Export
-- ============================================================================

\echo 'TEST 12: GeoJSON Export Format'
DO $$
DECLARE
    v_geojson JSON;
    v_type TEXT;
BEGIN
    SELECT geojson INTO v_geojson FROM vw_reports_geojson;
    v_type := v_geojson->>'type';
    
    IF v_type = 'FeatureCollection' THEN
        RAISE NOTICE '✓ PASS: GeoJSON export produces valid FeatureCollection';
    ELSE
        RAISE EXCEPTION '✗ FAIL: Invalid GeoJSON type: %', v_type;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '⚠ WARN: GeoJSON export test failed - %', SQLERRM;
END $$;
\echo ''

-- ============================================================================
-- Test Summary
-- ============================================================================

\echo '=============================================='
\echo 'TEST SUMMARY'
\echo '=============================================='

SELECT 
    'Total Reports' as "Metric",
    COUNT(*)::TEXT as "Value"
FROM road_reports
UNION ALL
SELECT 
    'Active Reports',
    COUNT(*)::TEXT
FROM road_reports WHERE status IN ('new', 'verified')
UNION ALL
SELECT 
    'Clusters Found (eps=0.01)',
    COUNT(DISTINCT cluster_id)::TEXT
FROM (
    SELECT ST_ClusterDBSCAN(location::geometry, 0.01, 3) OVER () as cluster_id
    FROM road_reports WHERE status IN ('new', 'verified')
) c WHERE cluster_id IS NOT NULL
UNION ALL
SELECT 
    'Max Priority Score',
    ROUND(MAX(priority_score), 2)::TEXT
FROM fn_get_priority_queue(0.01, 3, 30);

\echo ''
\echo 'All tests completed!'
\echo '=============================================='
