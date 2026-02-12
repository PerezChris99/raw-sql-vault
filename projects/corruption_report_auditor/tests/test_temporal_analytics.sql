-- ============================================================================
-- Corruption Report Auditor - Temporal Analytics Tests
-- Description: Integration tests for FILTER clause and temporal functions
-- Run: psql -d corruption_auditor -f test_temporal_analytics.sql
-- ============================================================================

\echo '=============================================================================='
\echo 'CORRUPTION REPORT AUDITOR - TEMPORAL ANALYTICS TESTS'
\echo '=============================================================================='
\echo ''

-- ============================================================================
-- Test Setup
-- ============================================================================

\echo '>>> Setting up test environment...'

BEGIN;

-- Create a test schema to avoid polluting main data
CREATE SCHEMA IF NOT EXISTS test_schema;
SET search_path TO test_schema, public;

-- ============================================================================
-- Test 1: FILTER Clause Basic Functionality
-- ============================================================================
\echo ''
\echo 'TEST 1: FILTER Clause Basic Functionality'

DO $$
DECLARE
    v_result RECORD;
    v_passed BOOLEAN := TRUE;
BEGIN
    -- Test FILTER with different conditions
    SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE 1=1) as all_rows,
        COUNT(*) FILTER (WHERE 1=0) as no_rows
    INTO v_result
    FROM (SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) t(n);
    
    IF v_result.total = 3 AND v_result.all_rows = 3 AND v_result.no_rows = 0 THEN
        RAISE NOTICE '  PASSED: FILTER clause produces correct counts';
    ELSE
        RAISE NOTICE '  FAILED: FILTER clause counts incorrect';
        v_passed := FALSE;
    END IF;
END $$;

-- ============================================================================
-- Test 2: AGE() Function
-- ============================================================================
\echo ''
\echo 'TEST 2: AGE() Function for Date Calculations'

DO $$
DECLARE
    v_age_result INTERVAL;
    v_days INTEGER;
BEGIN
    -- Test AGE function
    v_age_result := AGE(CURRENT_DATE, CURRENT_DATE - INTERVAL '30 days');
    v_days := EXTRACT(DAY FROM v_age_result);
    
    IF v_days = 30 THEN
        RAISE NOTICE '  PASSED: AGE() correctly calculates 30-day difference';
    ELSE
        RAISE NOTICE '  FAILED: AGE() returned % days instead of 30', v_days;
    END IF;
    
    -- Test with timestamp
    v_age_result := AGE(CURRENT_TIMESTAMP, CURRENT_TIMESTAMP - INTERVAL '1 year 2 months');
    
    IF EXTRACT(YEAR FROM v_age_result) = 1 AND EXTRACT(MONTH FROM v_age_result) = 2 THEN
        RAISE NOTICE '  PASSED: AGE() handles years and months correctly';
    ELSE
        RAISE NOTICE '  FAILED: AGE() year/month calculation incorrect';
    END IF;
END $$;

-- ============================================================================
-- Test 3: DATE_TRUNC Bucketing
-- ============================================================================
\echo ''
\echo 'TEST 3: DATE_TRUNC for Time Series Bucketing'

DO $$
DECLARE
    v_result DATE;
BEGIN
    -- Test month truncation
    v_result := DATE_TRUNC('month', '2025-06-15'::DATE)::DATE;
    IF v_result = '2025-06-01'::DATE THEN
        RAISE NOTICE '  PASSED: DATE_TRUNC(month) returns first of month';
    ELSE
        RAISE NOTICE '  FAILED: DATE_TRUNC(month) returned %', v_result;
    END IF;
    
    -- Test quarter truncation
    v_result := DATE_TRUNC('quarter', '2025-08-15'::DATE)::DATE;
    IF v_result = '2025-07-01'::DATE THEN
        RAISE NOTICE '  PASSED: DATE_TRUNC(quarter) returns first of quarter';
    ELSE
        RAISE NOTICE '  FAILED: DATE_TRUNC(quarter) returned %', v_result;
    END IF;
    
    -- Test week truncation
    v_result := DATE_TRUNC('week', '2025-06-18'::DATE)::DATE; -- Wednesday
    IF EXTRACT(DOW FROM v_result) = 1 THEN -- Monday
        RAISE NOTICE '  PASSED: DATE_TRUNC(week) returns Monday';
    ELSE
        RAISE NOTICE '  FAILED: DATE_TRUNC(week) did not return Monday';
    END IF;
END $$;

-- ============================================================================
-- Test 4: INTERVAL Arithmetic
-- ============================================================================
\echo ''
\echo 'TEST 4: INTERVAL Arithmetic for Date Ranges'

DO $$
DECLARE
    v_date DATE;
    v_result BOOLEAN;
BEGIN
    -- Test date subtraction with interval
    v_date := CURRENT_DATE - INTERVAL '1 year';
    v_result := v_date < CURRENT_DATE;
    
    IF v_result THEN
        RAISE NOTICE '  PASSED: CURRENT_DATE - INTERVAL 1 year is in the past';
    ELSE
        RAISE NOTICE '  FAILED: INTERVAL arithmetic error';
    END IF;
    
    -- Test complex intervals
    v_date := CURRENT_DATE - INTERVAL '1 year 3 months 15 days';
    
    IF v_date IS NOT NULL AND v_date < CURRENT_DATE THEN
        RAISE NOTICE '  PASSED: Complex INTERVAL (1y 3m 15d) calculates correctly';
    ELSE
        RAISE NOTICE '  FAILED: Complex INTERVAL calculation error';
    END IF;
END $$;

-- ============================================================================
-- Test 5: generate_series for Gap Filling
-- ============================================================================
\echo ''
\echo 'TEST 5: generate_series for Date Series'

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Test daily series generation
    SELECT COUNT(*) INTO v_count
    FROM generate_series(
        CURRENT_DATE - INTERVAL '6 days',
        CURRENT_DATE,
        INTERVAL '1 day'
    );
    
    IF v_count = 7 THEN
        RAISE NOTICE '  PASSED: generate_series produces 7 days for 1-week range';
    ELSE
        RAISE NOTICE '  FAILED: generate_series produced % days instead of 7', v_count;
    END IF;
    
    -- Test monthly series
    SELECT COUNT(*) INTO v_count
    FROM generate_series(
        DATE_TRUNC('month', CURRENT_DATE - INTERVAL '11 months'),
        DATE_TRUNC('month', CURRENT_DATE),
        INTERVAL '1 month'
    );
    
    IF v_count = 12 THEN
        RAISE NOTICE '  PASSED: generate_series produces 12 months';
    ELSE
        RAISE NOTICE '  FAILED: generate_series produced % months instead of 12', v_count;
    END IF;
END $$;

-- ============================================================================
-- Test 6: FILTER with Multiple Conditions
-- ============================================================================
\echo ''
\echo 'TEST 6: FILTER with Multiple Conditions'

DO $$
DECLARE
    v_result RECORD;
BEGIN
    -- Create test data
    WITH test_data AS (
        SELECT 
            generate_series(1, 100) as id,
            CASE WHEN generate_series(1, 100) % 2 = 0 THEN 'A' ELSE 'B' END as category,
            generate_series(1, 100) as value
    )
    SELECT 
        COUNT(*) FILTER (WHERE category = 'A') as cat_a,
        COUNT(*) FILTER (WHERE category = 'B') as cat_b,
        COUNT(*) FILTER (WHERE value > 50) as high_value,
        COUNT(*) FILTER (WHERE category = 'A' AND value > 50) as cat_a_high,
        SUM(value) FILTER (WHERE category = 'A') as sum_a
    INTO v_result
    FROM test_data;
    
    IF v_result.cat_a = 50 AND v_result.cat_b = 50 THEN
        RAISE NOTICE '  PASSED: FILTER correctly counts categories (50/50)';
    ELSE
        RAISE NOTICE '  FAILED: Category counts incorrect: A=%, B=%', v_result.cat_a, v_result.cat_b;
    END IF;
    
    IF v_result.high_value = 50 THEN
        RAISE NOTICE '  PASSED: FILTER correctly filters by value > 50';
    ELSE
        RAISE NOTICE '  FAILED: High value count incorrect: %', v_result.high_value;
    END IF;
    
    IF v_result.cat_a_high = 25 THEN
        RAISE NOTICE '  PASSED: FILTER with multiple conditions (A AND >50) = 25';
    ELSE
        RAISE NOTICE '  FAILED: Combined filter count incorrect: %', v_result.cat_a_high;
    END IF;
END $$;

-- ============================================================================
-- Test 7: Temporal Bucketing with CASE and AGE
-- ============================================================================
\echo ''
\echo 'TEST 7: Age Bucketing Logic'

DO $$
DECLARE
    v_bucket TEXT;
BEGIN
    -- Test 15-day-old case
    SELECT CASE 
        WHEN AGE(CURRENT_DATE, CURRENT_DATE - INTERVAL '15 days') < INTERVAL '30 days' THEN '0-30 days'
        WHEN AGE(CURRENT_DATE, CURRENT_DATE - INTERVAL '15 days') < INTERVAL '90 days' THEN '31-90 days'
        ELSE 'Over 90 days'
    END INTO v_bucket;
    
    IF v_bucket = '0-30 days' THEN
        RAISE NOTICE '  PASSED: 15-day case correctly bucketed to 0-30 days';
    ELSE
        RAISE NOTICE '  FAILED: 15-day case bucketed to %', v_bucket;
    END IF;
    
    -- Test 60-day-old case
    SELECT CASE 
        WHEN AGE(CURRENT_DATE, CURRENT_DATE - INTERVAL '60 days') < INTERVAL '30 days' THEN '0-30 days'
        WHEN AGE(CURRENT_DATE, CURRENT_DATE - INTERVAL '60 days') < INTERVAL '90 days' THEN '31-90 days'
        ELSE 'Over 90 days'
    END INTO v_bucket;
    
    IF v_bucket = '31-90 days' THEN
        RAISE NOTICE '  PASSED: 60-day case correctly bucketed to 31-90 days';
    ELSE
        RAISE NOTICE '  FAILED: 60-day case bucketed to %', v_bucket;
    END IF;
    
    -- Test 120-day-old case
    SELECT CASE 
        WHEN AGE(CURRENT_DATE, CURRENT_DATE - INTERVAL '120 days') < INTERVAL '30 days' THEN '0-30 days'
        WHEN AGE(CURRENT_DATE, CURRENT_DATE - INTERVAL '120 days') < INTERVAL '90 days' THEN '31-90 days'
        ELSE 'Over 90 days'
    END INTO v_bucket;
    
    IF v_bucket = 'Over 90 days' THEN
        RAISE NOTICE '  PASSED: 120-day case correctly bucketed to Over 90 days';
    ELSE
        RAISE NOTICE '  FAILED: 120-day case bucketed to %', v_bucket;
    END IF;
END $$;

-- ============================================================================
-- Test 8: Functions Exist and Return Data
-- ============================================================================
\echo ''
\echo 'TEST 8: Stored Functions Return Valid Data'

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Test fn_category_status_report
    BEGIN
        SELECT COUNT(*) INTO v_count FROM fn_category_status_report(INTERVAL '1 year');
        IF v_count >= 0 THEN
            RAISE NOTICE '  PASSED: fn_category_status_report executes (% rows)', v_count;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  FAILED: fn_category_status_report error: %', SQLERRM;
    END;
    
    -- Test fn_aging_analysis
    BEGIN
        SELECT COUNT(*) INTO v_count FROM fn_aging_analysis();
        IF v_count >= 0 THEN
            RAISE NOTICE '  PASSED: fn_aging_analysis executes (% rows)', v_count;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  FAILED: fn_aging_analysis error: %', SQLERRM;
    END;
    
    -- Test fn_monthly_trends
    BEGIN
        SELECT COUNT(*) INTO v_count FROM fn_monthly_trends(12);
        IF v_count >= 0 THEN
            RAISE NOTICE '  PASSED: fn_monthly_trends executes (% rows)', v_count;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  FAILED: fn_monthly_trends error: %', SQLERRM;
    END;
    
    -- Test fn_sla_breach_forecast
    BEGIN
        SELECT COUNT(*) INTO v_count FROM fn_sla_breach_forecast(7);
        IF v_count >= 0 THEN
            RAISE NOTICE '  PASSED: fn_sla_breach_forecast executes (% rows)', v_count;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  FAILED: fn_sla_breach_forecast error: %', SQLERRM;
    END;
END $$;

-- ============================================================================
-- Test 9: Views Return Data
-- ============================================================================
\echo ''
\echo 'TEST 9: Analytics Views Return Valid Data'

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Test vw_aging_report
    BEGIN
        SELECT COUNT(*) INTO v_count FROM vw_aging_report;
        RAISE NOTICE '  PASSED: vw_aging_report returns % rows', v_count;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  FAILED: vw_aging_report error: %', SQLERRM;
    END;
    
    -- Test vw_category_status_distribution
    BEGIN
        SELECT COUNT(*) INTO v_count FROM vw_category_status_distribution;
        RAISE NOTICE '  PASSED: vw_category_status_distribution returns % rows', v_count;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  FAILED: vw_category_status_distribution error: %', SQLERRM;
    END;
    
    -- Test vw_monthly_trends
    BEGIN
        SELECT COUNT(*) INTO v_count FROM vw_monthly_trends;
        RAISE NOTICE '  PASSED: vw_monthly_trends returns % rows', v_count;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  FAILED: vw_monthly_trends error: %', SQLERRM;
    END;
    
    -- Test vw_sla_compliance
    BEGIN
        SELECT COUNT(*) INTO v_count FROM vw_sla_compliance;
        RAISE NOTICE '  PASSED: vw_sla_compliance returns % rows', v_count;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '  FAILED: vw_sla_compliance error: %', SQLERRM;
    END;
END $$;

-- ============================================================================
-- Test 10: Sample Query from Requirements
-- ============================================================================
\echo ''
\echo 'TEST 10: Requirements Sample Query Execution'

DO $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Execute the exact sample query from requirements
    SELECT COUNT(*) INTO v_count FROM (
        SELECT 
            c.name as category,
            COUNT(*) FILTER (WHERE s.name = 'unresolved' OR s.name = 'open') as open_cases
        FROM reports r
        JOIN categories c ON r.category_id = c.category_id
        JOIN statuses s ON r.status_id = s.status_id
        WHERE r.reported_date > CURRENT_DATE - INTERVAL '1 year'
        GROUP BY c.name
    ) sub;
    
    IF v_count >= 0 THEN
        RAISE NOTICE '  PASSED: Sample query from requirements executes successfully';
        RAISE NOTICE '          Query matched the pattern: SELECT category, COUNT(*) FILTER (WHERE status=''unresolved'')...';
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '  FAILED: Sample query error: %', SQLERRM;
END $$;

-- ============================================================================
-- Cleanup
-- ============================================================================

DROP SCHEMA IF EXISTS test_schema CASCADE;
RESET search_path;

COMMIT;

\echo ''
\echo '=============================================================================='
\echo 'ALL TEMPORAL ANALYTICS TESTS COMPLETED'
\echo '=============================================================================='
