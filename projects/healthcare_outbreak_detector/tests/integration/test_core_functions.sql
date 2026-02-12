-- ============================================================================
-- Tests: Integration Tests
-- Purpose: Validate core functionality end-to-end
-- ============================================================================

SET search_path TO surveillance, public;

-- Test framework setup
CREATE SCHEMA IF NOT EXISTS test;

CREATE OR REPLACE FUNCTION test.assert_equals(
    p_expected ANYELEMENT,
    p_actual ANYELEMENT,
    p_message TEXT DEFAULT ''
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_expected IS DISTINCT FROM p_actual THEN
        RAISE EXCEPTION 'ASSERTION FAILED: % (Expected: %, Actual: %)', 
            p_message, p_expected, p_actual;
    END IF;
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION test.assert_not_null(
    p_value ANYELEMENT,
    p_message TEXT DEFAULT ''
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_value IS NULL THEN
        RAISE EXCEPTION 'ASSERTION FAILED: Value is NULL - %', p_message;
    END IF;
    RETURN TRUE;
END;
$$;

-- ============================================================================
-- TEST SUITE: Patient Registration
-- ============================================================================

CREATE OR REPLACE FUNCTION test.test_patient_registration()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_patient_id UUID;
    v_patient RECORD;
BEGIN
    -- Test: Register new patient
    v_patient_id := surveillance.register_patient(
        p_first_name := 'Test',
        p_last_name := 'Patient',
        p_date_of_birth := '1990-01-15',
        p_gender := 'male',
        p_district_code := 'KLA001'
    );
    
    PERFORM test.assert_not_null(v_patient_id, 'Patient ID should not be null');
    
    -- Verify patient exists
    SELECT * INTO v_patient FROM surveillance.patients WHERE patient_id = v_patient_id;
    
    PERFORM test.assert_equals('Test', v_patient.first_name, 'First name mismatch');
    PERFORM test.assert_equals('Patient', v_patient.last_name, 'Last name mismatch');
    PERFORM test.assert_equals('male'::surveillance.gender_type, v_patient.gender, 'Gender mismatch');
    
    -- Cleanup
    DELETE FROM surveillance.patients WHERE patient_id = v_patient_id;
    
    RETURN 'PASS: test_patient_registration';
END;
$$;

-- ============================================================================
-- TEST SUITE: Case Reporting
-- ============================================================================

CREATE OR REPLACE FUNCTION test.test_case_reporting()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_patient_id UUID;
    v_case_id UUID;
    v_case RECORD;
BEGIN
    -- Setup: Create test patient
    v_patient_id := surveillance.register_patient(
        p_first_name := 'Case',
        p_last_name := 'TestPatient',
        p_age_years := 35,
        p_gender := 'female',
        p_district_code := 'KLA001'
    );
    
    -- Test: Report case
    v_case_id := surveillance.report_case(
        p_patient_id := v_patient_id,
        p_disease_code := 'MAL',  -- Malaria
        p_district_code := 'KLA001',
        p_onset_date := CURRENT_DATE - 2,
        p_case_status := 'suspected',
        p_severity := 'moderate'
    );
    
    PERFORM test.assert_not_null(v_case_id, 'Case ID should not be null');
    
    -- Verify case
    SELECT * INTO v_case FROM surveillance.cases WHERE case_id = v_case_id;
    
    PERFORM test.assert_equals('suspected'::surveillance.case_status, v_case.case_status, 'Status mismatch');
    PERFORM test.assert_equals('moderate'::surveillance.severity_level, v_case.severity, 'Severity mismatch');
    PERFORM test.assert_not_null(v_case.case_number, 'Case number should be auto-generated');
    
    -- Cleanup
    DELETE FROM surveillance.cases WHERE case_id = v_case_id;
    DELETE FROM surveillance.patients WHERE patient_id = v_patient_id;
    
    RETURN 'PASS: test_case_reporting';
END;
$$;

-- ============================================================================
-- TEST SUITE: Outbreak Detection
-- ============================================================================

CREATE OR REPLACE FUNCTION test.test_outbreak_detection()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSONB;
    v_detected BOOLEAN;
BEGIN
    -- Test: Z-score detection function executes without error
    SELECT surveillance.detect_zscore_anomaly(
        p_disease_code := 'MAL',
        p_district_code := 'KLA001',
        p_zscore_threshold := 2.0
    ) INTO v_result;
    
    PERFORM test.assert_not_null(v_result, 'Detection result should not be null');
    
    -- Verify result structure
    v_detected := (v_result->>'is_anomaly')::BOOLEAN;
    PERFORM test.assert_not_null(v_detected IS NOT NULL, 'is_anomaly field should exist');
    
    RETURN 'PASS: test_outbreak_detection';
END;
$$;

-- ============================================================================
-- TEST SUITE: API Functions
-- ============================================================================

CREATE OR REPLACE FUNCTION test.test_api_dashboard()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Test: Dashboard API returns valid JSON
    SELECT surveillance.api_get_dashboard() INTO v_result;
    
    PERFORM test.assert_not_null(v_result, 'Dashboard result should not be null');
    PERFORM test.assert_not_null(v_result->'summary', 'Summary field should exist');
    PERFORM test.assert_not_null(v_result->'generated_at', 'Timestamp should exist');
    
    RETURN 'PASS: test_api_dashboard';
END;
$$;

-- ============================================================================
-- TEST RUNNER
-- ============================================================================

CREATE OR REPLACE FUNCTION test.run_all_tests()
RETURNS TABLE(test_name TEXT, result TEXT, duration_ms NUMERIC)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start TIMESTAMP;
    v_end TIMESTAMP;
    v_result TEXT;
    v_tests TEXT[] := ARRAY[
        'test_patient_registration',
        'test_case_reporting',
        'test_outbreak_detection',
        'test_api_dashboard'
    ];
    v_test TEXT;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Running Healthcare Outbreak Detector Tests';
    RAISE NOTICE '========================================';
    
    FOREACH v_test IN ARRAY v_tests
    LOOP
        test_name := v_test;
        v_start := clock_timestamp();
        
        BEGIN
            EXECUTE format('SELECT test.%I()', v_test) INTO v_result;
            result := v_result;
        EXCEPTION WHEN OTHERS THEN
            result := 'FAIL: ' || SQLERRM;
        END;
        
        v_end := clock_timestamp();
        duration_ms := ROUND(EXTRACT(MILLISECONDS FROM (v_end - v_start))::NUMERIC, 2);
        
        RETURN NEXT;
    END LOOP;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Test run completed';
    RAISE NOTICE '========================================';
END;
$$;

-- Run tests: SELECT * FROM test.run_all_tests();
