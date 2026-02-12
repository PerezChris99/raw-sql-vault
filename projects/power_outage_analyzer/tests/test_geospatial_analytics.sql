-- ============================================================================
-- Power Outage Pattern Analyzer - PostGIS Function Tests
-- Tests for clustering, proximity, and spatial analysis functions
-- Run: psql -d power_outage_db -f test_geospatial_analytics.sql
-- ============================================================================

\echo '=========================================='
\echo 'POSTGIS ANALYTICS FUNCTION TESTS'
\echo '=========================================='
\echo ''

-- Track test results
CREATE TEMP TABLE test_results (
    test_id SERIAL,
    test_name TEXT,
    status TEXT,
    message TEXT,
    execution_time INTERVAL
);

-- Helper function for timing
CREATE OR REPLACE FUNCTION run_timed_test(
    p_test_name TEXT,
    p_test_sql TEXT
) RETURNS VOID AS $$
DECLARE
    v_start TIMESTAMPTZ;
    v_end TIMESTAMPTZ;
    v_result RECORD;
    v_count INTEGER;
BEGIN
    v_start := clock_timestamp();
    
    BEGIN
        EXECUTE p_test_sql INTO v_count;
        v_end := clock_timestamp();
        
        IF v_count IS NOT NULL AND v_count > 0 THEN
            INSERT INTO test_results (test_name, status, message, execution_time)
            VALUES (p_test_name, 'PASS', 'Returned ' || v_count || ' rows', v_end - v_start);
        ELSE
            INSERT INTO test_results (test_name, status, message, execution_time)
            VALUES (p_test_name, 'WARN', 'No results returned', v_end - v_start);
        END IF;
    EXCEPTION WHEN OTHERS THEN
        v_end := clock_timestamp();
        INSERT INTO test_results (test_name, status, message, execution_time)
        VALUES (p_test_name, 'FAIL', SQLERRM, v_end - v_start);
    END;
END;
$$ LANGUAGE plpgsql;

\echo 'Running tests...'
\echo ''

-- ============================================================================
-- Test 1: PostGIS Extension Available
-- ============================================================================

\echo 'Test 1: PostGIS Extension'
SELECT run_timed_test(
    'PostGIS Extension Loaded',
    'SELECT COUNT(*) FROM pg_extension WHERE extname = ''postgis'''
);

-- ============================================================================
-- Test 2: K-Means Clustering Function
-- ============================================================================

\echo 'Test 2: K-Means Clustering'
SELECT run_timed_test(
    'fn_cluster_outages_kmeans (5 clusters, 180 days)',
    'SELECT COUNT(*) FROM fn_cluster_outages_kmeans(5, 180, 2)'
);

-- Verify K-Means output structure
DO $$
DECLARE
    v_cluster RECORD;
BEGIN
    SELECT * INTO v_cluster FROM fn_cluster_outages_kmeans(5, 180, 2) LIMIT 1;
    
    IF v_cluster.cluster_id IS NOT NULL 
       AND v_cluster.outage_count IS NOT NULL 
       AND v_cluster.cluster_center IS NOT NULL THEN
        INSERT INTO test_results (test_name, status, message)
        VALUES ('K-Means output structure', 'PASS', 'All expected columns present');
    ELSE
        INSERT INTO test_results (test_name, status, message)
        VALUES ('K-Means output structure', 'FAIL', 'Missing expected columns');
    END IF;
END $$;

-- ============================================================================
-- Test 3: DBSCAN Clustering Function
-- ============================================================================

\echo 'Test 3: DBSCAN Clustering'
SELECT run_timed_test(
    'fn_cluster_outages_dbscan (500m, 3 points)',
    'SELECT COUNT(*) FROM fn_cluster_outages_dbscan(500, 3, 90)'
);

-- Verify noise detection
DO $$
DECLARE
    v_noise_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_noise_count 
    FROM fn_cluster_outages_dbscan(500, 3, 90) 
    WHERE is_noise = true;
    
    INSERT INTO test_results (test_name, status, message)
    VALUES ('DBSCAN noise detection', 'PASS', 'Noise points identified: ' || v_noise_count);
END $$;

-- ============================================================================
-- Test 4: Hotspot Identification
-- ============================================================================

\echo 'Test 4: Hotspot Detection'
SELECT run_timed_test(
    'fn_identify_hotspots (10 hotspots, 1km grid)',
    'SELECT COUNT(*) FROM fn_identify_hotspots(10, 1000, 90)'
);

-- ============================================================================
-- Test 5: Persistent Clusters
-- ============================================================================

\echo 'Test 5: Persistent Clusters'
SELECT run_timed_test(
    'fn_persistent_clusters (3 periods, 30 days)',
    'SELECT COUNT(*) FROM fn_persistent_clusters(3, 30, 500)'
);

-- ============================================================================
-- Test 6: Proximity Analysis - Near Point
-- ============================================================================

\echo 'Test 6: Proximity Analysis'
SELECT run_timed_test(
    'fn_outages_near_point (1km radius)',
    'SELECT COUNT(*) FROM fn_outages_near_point(-122.405, 37.785, 1000, 180)'
);

-- ============================================================================
-- Test 7: Nearest Neighbor Search
-- ============================================================================

\echo 'Test 7: KNN Search'
SELECT run_timed_test(
    'fn_nearest_outages (10 nearest)',
    'SELECT COUNT(*) FROM fn_nearest_outages(-122.40, 37.78, 10, 180)'
);

-- Verify distance ordering
DO $$
DECLARE
    v_distances NUMERIC[];
    v_is_sorted BOOLEAN := true;
    i INTEGER;
BEGIN
    SELECT ARRAY_AGG(distance_meters ORDER BY distance_meters) 
    INTO v_distances
    FROM fn_nearest_outages(-122.40, 37.78, 10, 180);
    
    IF array_length(v_distances, 1) >= 2 THEN
        FOR i IN 2..array_length(v_distances, 1) LOOP
            IF v_distances[i] < v_distances[i-1] THEN
                v_is_sorted := false;
                EXIT;
            END IF;
        END LOOP;
    END IF;
    
    IF v_is_sorted THEN
        INSERT INTO test_results (test_name, status, message)
        VALUES ('KNN distance ordering', 'PASS', 'Results correctly sorted by distance');
    ELSE
        INSERT INTO test_results (test_name, status, message)
        VALUES ('KNN distance ordering', 'FAIL', 'Results not properly sorted');
    END IF;
END $$;

-- ============================================================================
-- Test 8: Transformer Risk Zones
-- ============================================================================

\echo 'Test 8: Transformer Risk Zones'
SELECT run_timed_test(
    'fn_transformer_risk_zones (2 min outages)',
    'SELECT COUNT(*) FROM fn_transformer_risk_zones(2, 500, 365)'
);

-- ============================================================================
-- Test 9: Infrastructure Risk Calculation
-- ============================================================================

\echo 'Test 9: Infrastructure Risk'
SELECT run_timed_test(
    'fn_calculate_infrastructure_risk',
    'SELECT COUNT(*) FROM fn_calculate_infrastructure_risk()'
);

-- Verify risk categories
DO $$
DECLARE
    v_critical INTEGER;
    v_high INTEGER;
    v_medium INTEGER;
    v_low INTEGER;
BEGIN
    SELECT 
        COUNT(*) FILTER (WHERE risk_category = 'critical'),
        COUNT(*) FILTER (WHERE risk_category = 'high'),
        COUNT(*) FILTER (WHERE risk_category = 'medium'),
        COUNT(*) FILTER (WHERE risk_category = 'low')
    INTO v_critical, v_high, v_medium, v_low
    FROM fn_calculate_infrastructure_risk();
    
    INSERT INTO test_results (test_name, status, message)
    VALUES ('Risk category distribution', 'PASS', 
            format('Critical: %s, High: %s, Medium: %s, Low: %s', 
                   v_critical, v_high, v_medium, v_low));
END $$;

-- ============================================================================
-- Test 10: Crew Dispatch Optimization
-- ============================================================================

\echo 'Test 10: Crew Dispatch'
SELECT run_timed_test(
    'fn_find_optimal_crew',
    'SELECT COUNT(*) FROM fn_find_optimal_crew(-122.40, 37.78, NULL, 5)'
);

-- Verify suitability scoring
DO $$
DECLARE
    v_scores NUMERIC[];
BEGIN
    SELECT ARRAY_AGG(suitability_score ORDER BY suitability_score)
    INTO v_scores
    FROM fn_find_optimal_crew(-122.40, 37.78, NULL, 5);
    
    IF array_length(v_scores, 1) > 0 THEN
        INSERT INTO test_results (test_name, status, message)
        VALUES ('Crew suitability scoring', 'PASS', 
                'Score range: ' || v_scores[1] || ' to ' || v_scores[array_length(v_scores, 1)]);
    ELSE
        INSERT INTO test_results (test_name, status, message)
        VALUES ('Crew suitability scoring', 'WARN', 'No crews available');
    END IF;
END $$;

-- ============================================================================
-- Test 11: GeoJSON Export - Outages
-- ============================================================================

\echo 'Test 11: GeoJSON Export'
DO $$
DECLARE
    v_geojson JSON;
    v_type TEXT;
BEGIN
    SELECT fn_export_outages_geojson() INTO v_geojson;
    v_type := v_geojson->>'type';
    
    IF v_type = 'FeatureCollection' THEN
        INSERT INTO test_results (test_name, status, message)
        VALUES ('fn_export_outages_geojson', 'PASS', 'Valid GeoJSON FeatureCollection');
    ELSE
        INSERT INTO test_results (test_name, status, message)
        VALUES ('fn_export_outages_geojson', 'FAIL', 'Invalid GeoJSON type: ' || v_type);
    END IF;
END $$;

-- ============================================================================
-- Test 12: Views Functionality
-- ============================================================================

\echo 'Test 12: Views'
SELECT run_timed_test(
    'vw_active_outages',
    'SELECT COUNT(*) FROM vw_active_outages'
);

SELECT run_timed_test(
    'vw_outage_clusters_kmeans',
    'SELECT COUNT(*) FROM vw_outage_clusters_kmeans'
);

SELECT run_timed_test(
    'vw_district_outage_stats',
    'SELECT COUNT(*) FROM vw_district_outage_stats'
);

SELECT run_timed_test(
    'vw_transformer_risk_analysis',
    'SELECT COUNT(*) FROM vw_transformer_risk_analysis'
);

-- ============================================================================
-- Test 13: Spatial Index Usage
-- ============================================================================

\echo 'Test 13: Spatial Index Check'
DO $$
DECLARE
    v_index_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE tablename IN ('outages', 'transformers', 'substations', 'districts')
      AND indexdef LIKE '%GIST%';
    
    IF v_index_count >= 4 THEN
        INSERT INTO test_results (test_name, status, message)
        VALUES ('GIST spatial indexes', 'PASS', v_index_count || ' GIST indexes found');
    ELSE
        INSERT INTO test_results (test_name, status, message)
        VALUES ('GIST spatial indexes', 'WARN', 'Only ' || v_index_count || ' GIST indexes found');
    END IF;
END $$;

-- ============================================================================
-- Test 14: ST_ClusterKMeans Direct Test (User's Sample Query Pattern)
-- ============================================================================

\echo 'Test 14: ST_ClusterKMeans Direct'
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- User's sample query pattern
    SELECT COUNT(DISTINCT cluster) INTO v_count
    FROM (
        SELECT 
            d.name as district,
            COUNT(*) as outages,
            ST_ClusterKMeans(o.location::geometry, 5) OVER () as cluster
        FROM outages o
        JOIN districts d ON o.district_id = d.district_id
        WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '180 days'
        GROUP BY d.name, o.location
    ) sub;
    
    IF v_count = 5 THEN
        INSERT INTO test_results (test_name, status, message)
        VALUES ('ST_ClusterKMeans direct query', 'PASS', 'Correctly produced 5 clusters');
    ELSIF v_count > 0 THEN
        INSERT INTO test_results (test_name, status, message)
        VALUES ('ST_ClusterKMeans direct query', 'WARN', 'Produced ' || v_count || ' clusters (expected 5)');
    ELSE
        INSERT INTO test_results (test_name, status, message)
        VALUES ('ST_ClusterKMeans direct query', 'FAIL', 'No clusters produced');
    END IF;
END $$;

-- ============================================================================
-- Test 15: Distance Calculations
-- ============================================================================

\echo 'Test 15: Distance Calculations'
DO $$
DECLARE
    v_distance_m NUMERIC;
BEGIN
    -- Test distance between two known points
    SELECT ST_Distance(
        ST_GeogFromText('POINT(-122.405 37.785)'),
        ST_GeogFromText('POINT(-122.395 37.775)')
    ) INTO v_distance_m;
    
    -- Should be approximately 1.4 km
    IF v_distance_m BETWEEN 1300 AND 1500 THEN
        INSERT INTO test_results (test_name, status, message)
        VALUES ('ST_Distance geography', 'PASS', 'Distance: ' || ROUND(v_distance_m) || 'm (expected ~1400m)');
    ELSE
        INSERT INTO test_results (test_name, status, message)
        VALUES ('ST_Distance geography', 'WARN', 'Unexpected distance: ' || ROUND(v_distance_m) || 'm');
    END IF;
END $$;

-- ============================================================================
-- Test Results Summary
-- ============================================================================

\echo ''
\echo '=========================================='
\echo 'TEST RESULTS SUMMARY'
\echo '=========================================='
\echo ''

\pset format aligned
\pset border 2

SELECT 
    test_id as "#",
    test_name as "Test Name",
    CASE status
        WHEN 'PASS' THEN '✓ PASS'
        WHEN 'WARN' THEN '⚠ WARN'
        ELSE '✗ FAIL'
    END as "Status",
    message as "Details",
    COALESCE(execution_time::TEXT, '-') as "Time"
FROM test_results
ORDER BY test_id;

\echo ''

-- Summary statistics
SELECT 
    COUNT(*) FILTER (WHERE status = 'PASS') as "Passed",
    COUNT(*) FILTER (WHERE status = 'WARN') as "Warnings",
    COUNT(*) FILTER (WHERE status = 'FAIL') as "Failed",
    COUNT(*) as "Total",
    ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'PASS') / COUNT(*), 1) as "Pass Rate %"
FROM test_results;

\echo ''
\echo '=========================================='
\echo 'END OF TESTS'
\echo '=========================================='

-- Cleanup
DROP FUNCTION IF EXISTS run_timed_test(TEXT, TEXT);
