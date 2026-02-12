-- ============================================================================
-- Water Point Usage Monitor - TimescaleDB Tests
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Test: Validates hypertables, functions, and time-series features
-- ============================================================================

\echo '=============================================='
\echo 'WATER POINT MONITOR - TIMESCALEDB TESTS'
\echo '=============================================='
\echo ''

-- ============================================================================
-- Test 1: TimescaleDB Extension
-- ============================================================================

\echo '>> TEST 1: TimescaleDB Extension Status'

DO $$
DECLARE
    v_version TEXT;
BEGIN
    SELECT extversion INTO v_version 
    FROM pg_extension 
    WHERE extname = 'timescaledb';
    
    IF v_version IS NOT NULL THEN
        RAISE NOTICE '[PASS] TimescaleDB version: %', v_version;
    ELSE
        RAISE EXCEPTION '[FAIL] TimescaleDB extension not installed';
    END IF;
END $$;

\echo ''

-- ============================================================================
-- Test 2: Hypertables Created
-- ============================================================================

\echo '>> TEST 2: Hypertable Configuration'

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM timescaledb_information.hypertables
    WHERE hypertable_schema = 'public';
    
    IF v_count >= 2 THEN
        RAISE NOTICE '[PASS] Found % hypertables', v_count;
    ELSE
        RAISE EXCEPTION '[FAIL] Expected at least 2 hypertables, found %', v_count;
    END IF;
END $$;

SELECT 
    hypertable_name as "Hypertable",
    num_chunks as "Chunks",
    num_dimensions as "Dimensions",
    COALESCE(compression_enabled::TEXT, 'N/A') as "Compressed"
FROM timescaledb_information.hypertables
WHERE hypertable_schema = 'public';

\echo ''

-- ============================================================================
-- Test 3: Continuous Aggregates
-- ============================================================================

\echo '>> TEST 3: Continuous Aggregates Status'

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM timescaledb_information.continuous_aggregates
    WHERE view_schema = 'public';
    
    IF v_count >= 3 THEN
        RAISE NOTICE '[PASS] Found % continuous aggregates', v_count;
    ELSE
        RAISE WARNING '[WARN] Expected 3+ continuous aggregates, found %', v_count;
    END IF;
END $$;

SELECT 
    view_name as "Aggregate",
    materialization_hypertable_name as "Storage",
    CASE WHEN compression_enabled THEN 'Yes' ELSE 'No' END as "Compressed"
FROM timescaledb_information.continuous_aggregates
WHERE view_schema = 'public';

\echo ''

-- ============================================================================
-- Test 4: User Sample Query - LAG Pattern
-- ============================================================================

\echo '>> TEST 4: User Sample Query (LAG Window Function)'
\echo '   SELECT borehole_id, AVG(usage), LAG(AVG(usage)) OVER ...'

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM fn_daily_usage_comparison(NULL, 7)
    WHERE prev IS NOT NULL;
    
    IF v_count > 0 THEN
        RAISE NOTICE '[PASS] LAG function returned % rows with prev day data', v_count;
    ELSE
        RAISE WARNING '[WARN] No LAG comparison data - need more historical data';
    END IF;
END $$;

SELECT 
    borehole_id as "Borehole ID",
    date as "Date",
    avg_daily as "Avg Daily",
    prev as "Prev Day (LAG)",
    pct_change as "% Change"
FROM fn_daily_usage_comparison(NULL, 3)
LIMIT 5;

\echo ''

-- ============================================================================
-- Test 5: time_bucket Function
-- ============================================================================

\echo '>> TEST 5: time_bucket() Function'

DO $$
DECLARE
    v_hourly INT;
    v_daily INT;
BEGIN
    SELECT COUNT(*) INTO v_hourly FROM usage_hourly_agg;
    SELECT COUNT(*) INTO v_daily FROM usage_daily_agg;
    
    IF v_hourly > 0 AND v_daily > 0 THEN
        RAISE NOTICE '[PASS] time_bucket aggregates: hourly=%, daily=%', v_hourly, v_daily;
    ELSE
        RAISE WARNING '[WARN] Aggregates may be empty - run refresh';
    END IF;
END $$;

SELECT 
    'hourly' as "Bucket",
    COUNT(*) as "Records",
    MIN(bucket_hour)::DATE as "From",
    MAX(bucket_hour)::DATE as "To"
FROM usage_hourly_agg
UNION ALL
SELECT 
    'daily',
    COUNT(*),
    MIN(bucket_day),
    MAX(bucket_day)
FROM usage_daily_agg;

\echo ''

-- ============================================================================
-- Test 6: Risk Score Function
-- ============================================================================

\echo '>> TEST 6: Risk Score Calculation'

DO $$
DECLARE
    v_borehole_id INT;
    v_risk RECORD;
BEGIN
    SELECT borehole_id INTO v_borehole_id 
    FROM boreholes 
    WHERE status = 'active' 
    LIMIT 1;
    
    IF v_borehole_id IS NOT NULL THEN
        SELECT * INTO v_risk FROM fn_calculate_risk_score(v_borehole_id);
        
        IF v_risk.risk_score IS NOT NULL THEN
            RAISE NOTICE '[PASS] Risk score for borehole %: %.1f (%)', 
                v_borehole_id, v_risk.risk_score, v_risk.risk_level;
        ELSE
            RAISE WARNING '[WARN] Risk score returned NULL';
        END IF;
    ELSE
        RAISE WARNING '[WARN] No active boreholes found';
    END IF;
END $$;

SELECT 
    borehole_name as "Borehole",
    risk_score as "Risk Score",
    risk_level as "Level"
FROM fn_get_breakdown_risk_queue(0, 5);

\echo ''

-- ============================================================================
-- Test 7: Rolling Statistics
-- ============================================================================

\echo '>> TEST 7: Rolling Statistics (Window Functions)'

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM fn_rolling_statistics(7);
    
    IF v_count > 0 THEN
        RAISE NOTICE '[PASS] Rolling statistics returned % borehole records', v_count;
    ELSE
        RAISE WARNING '[WARN] No rolling statistics data';
    END IF;
END $$;

SELECT 
    borehole_name as "Borehole",
    current_usage as "Today",
    ROUND(rolling_avg, 0) as "7-Day Avg",
    ROUND(rolling_stddev, 0) as "Std Dev",
    z_score as "Z-Score"
FROM fn_rolling_statistics(7)
LIMIT 5;

\echo ''

-- ============================================================================
-- Test 8: Anomaly Detection
-- ============================================================================

\echo '>> TEST 8: Anomaly Detection Functions'

DO $$
BEGIN
    -- Test usage drop detection
    PERFORM 1 FROM fn_detect_usage_drop(30, 7) LIMIT 1;
    RAISE NOTICE '[PASS] fn_detect_usage_drop executed';
    
    -- Test flow degradation
    PERFORM 1 FROM fn_detect_flow_degradation(14) LIMIT 1;
    RAISE NOTICE '[PASS] fn_detect_flow_degradation executed';
    
    -- Test pump cycling
    PERFORM 1 FROM fn_detect_pump_cycling(10) LIMIT 1;
    RAISE NOTICE '[PASS] fn_detect_pump_cycling executed';
    
    -- Test data gaps
    PERFORM 1 FROM fn_detect_data_gaps(3) LIMIT 1;
    RAISE NOTICE '[PASS] fn_detect_data_gaps executed';
    
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[FAIL] Anomaly function error: %', SQLERRM;
END $$;

\echo ''

-- ============================================================================
-- Test 9: Prediction Functions
-- ============================================================================

\echo '>> TEST 9: Prediction Functions'

DO $$
DECLARE
    v_borehole_id INT;
    v_pred RECORD;
BEGIN
    SELECT borehole_id INTO v_borehole_id 
    FROM boreholes 
    WHERE status = 'active' 
    LIMIT 1;
    
    IF v_borehole_id IS NOT NULL THEN
        SELECT * INTO v_pred FROM fn_predict_time_to_failure(v_borehole_id);
        
        RAISE NOTICE '[PASS] Prediction: health=%.1f, trend=%/day, confidence=%', 
            v_pred.current_health, v_pred.degradation_rate, v_pred.confidence;
    END IF;
END $$;

SELECT 
    b.name as "Borehole",
    ROUND(p.current_health, 1) as "Health",
    p.degradation_rate as "Rate/Day",
    p.predicted_days_to_failure as "To Failure",
    p.confidence as "Confidence"
FROM boreholes b
CROSS JOIN LATERAL fn_predict_time_to_failure(b.borehole_id) p
WHERE b.status = 'active'
LIMIT 3;

\echo ''

-- ============================================================================
-- Test 10: Views
-- ============================================================================

\echo '>> TEST 10: Analysis Views'

DO $$
DECLARE
    v_view TEXT;
    v_count INT;
    v_views TEXT[] := ARRAY[
        'vw_borehole_status',
        'vw_usage_anomalies', 
        'vw_breakdown_risk',
        'vw_maintenance_schedule',
        'vw_daily_usage_comparison'
    ];
BEGIN
    FOREACH v_view IN ARRAY v_views
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM %I', v_view) INTO v_count;
        RAISE NOTICE '[PASS] % - % rows', v_view, v_count;
    END LOOP;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING '[FAIL] View error: %', SQLERRM;
END $$;

\echo ''

-- ============================================================================
-- Test 11: Compression Policy
-- ============================================================================

\echo '>> TEST 11: Compression Policies'

SELECT 
    hypertable_name as "Hypertable",
    pg_size_pretty(before_compression_total_bytes) as "Before",
    pg_size_pretty(after_compression_total_bytes) as "After",
    ROUND(compression_ratio::numeric, 2) as "Ratio"
FROM hypertable_compression_stats('usage_logs')
WHERE before_compression_total_bytes > 0;

\echo ''

-- ============================================================================
-- Test 12: Data Integrity
-- ============================================================================

\echo '>> TEST 12: Data Integrity Checks'

DO $$
DECLARE
    v_logs INT;
    v_boreholes INT;
    v_orphans INT;
BEGIN
    SELECT COUNT(*) INTO v_logs FROM usage_logs;
    SELECT COUNT(*) INTO v_boreholes FROM boreholes WHERE status NOT IN ('decommissioned');
    
    -- Check for orphaned logs
    SELECT COUNT(*) INTO v_orphans
    FROM usage_logs ul
    WHERE NOT EXISTS (SELECT 1 FROM boreholes b WHERE b.borehole_id = ul.borehole_id);
    
    RAISE NOTICE '[INFO] Usage logs: %', v_logs;
    RAISE NOTICE '[INFO] Active boreholes: %', v_boreholes;
    
    IF v_orphans = 0 THEN
        RAISE NOTICE '[PASS] No orphaned usage logs';
    ELSE
        RAISE WARNING '[WARN] Found % orphaned usage logs', v_orphans;
    END IF;
END $$;

\echo ''

-- ============================================================================
-- Test Summary
-- ============================================================================

\echo '=============================================='
\echo 'TEST SUMMARY'
\echo '=============================================='

SELECT 
    'TimescaleDB Features' as "Component",
    CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'timescaledb')
         THEN '✅ Installed' ELSE '❌ Missing' END as "Status"
UNION ALL
SELECT 'Hypertables',
    CASE WHEN (SELECT COUNT(*) FROM timescaledb_information.hypertables WHERE hypertable_schema = 'public') >= 2
         THEN '✅ Configured' ELSE '❌ Missing' END
UNION ALL
SELECT 'Continuous Aggregates',
    CASE WHEN (SELECT COUNT(*) FROM timescaledb_information.continuous_aggregates WHERE view_schema = 'public') >= 3
         THEN '✅ Active' ELSE '⚠️ Check refresh' END
UNION ALL
SELECT 'Risk Functions',
    CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'fn_calculate_risk_score')
         THEN '✅ Available' ELSE '❌ Missing' END
UNION ALL
SELECT 'Usage Data',
    CASE WHEN (SELECT COUNT(*) FROM usage_logs) > 0
         THEN '✅ Populated' ELSE '⚠️ Empty' END;

\echo ''
\echo '=============================================='
\echo 'END OF TESTS'
\echo '=============================================='
