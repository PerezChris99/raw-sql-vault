-- ============================================================================
-- 🏥 HEALTHCARE OUTBREAK DETECTOR - STORED PROCEDURES
-- ============================================================================
-- File: 05_procedures.sql
-- Purpose: Data entry, case management, batch operations
-- Database: PostgreSQL 14+
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- SECTION 1: PATIENT REGISTRATION
-- ============================================================================

-- 1.1 Register new patient
CREATE OR REPLACE FUNCTION surveillance.register_patient(
    p_first_name VARCHAR(100),
    p_last_name VARCHAR(100),
    p_date_of_birth DATE DEFAULT NULL,
    p_age_years INTEGER DEFAULT NULL,
    p_gender surveillance.gender_type DEFAULT 'unknown',
    p_phone VARCHAR(20) DEFAULT NULL,
    p_district_code VARCHAR(10) DEFAULT NULL,
    p_village VARCHAR(100) DEFAULT NULL,
    p_is_healthcare_worker BOOLEAN DEFAULT FALSE
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_patient_id UUID;
    v_district_id INTEGER;
BEGIN
    -- Lookup district
    IF p_district_code IS NOT NULL THEN
        SELECT district_id INTO v_district_id 
        FROM surveillance.districts 
        WHERE district_code = p_district_code;
    END IF;
    
    -- Calculate age if DOB provided
    IF p_date_of_birth IS NOT NULL AND p_age_years IS NULL THEN
        p_age_years := EXTRACT(YEAR FROM age(p_date_of_birth))::INTEGER;
    END IF;
    
    INSERT INTO surveillance.patients (
        first_name, last_name, date_of_birth, age_years, gender,
        phone, district_id, village, is_healthcare_worker
    ) VALUES (
        p_first_name, p_last_name, p_date_of_birth, p_age_years, p_gender,
        p_phone, v_district_id, p_village, p_is_healthcare_worker
    )
    RETURNING patient_id INTO v_patient_id;
    
    RETURN v_patient_id;
END;
$$;

-- ============================================================================
-- SECTION 2: CASE REPORTING
-- ============================================================================

-- 2.1 Report new case
CREATE OR REPLACE FUNCTION surveillance.report_case(
    p_patient_id UUID,
    p_disease_code VARCHAR(20),
    p_district_code VARCHAR(10),
    p_onset_date DATE,
    p_facility_code VARCHAR(20) DEFAULT NULL,
    p_case_status surveillance.case_status DEFAULT 'suspected',
    p_severity surveillance.severity_level DEFAULT 'mild',
    p_hospitalized BOOLEAN DEFAULT FALSE,
    p_symptoms TEXT[] DEFAULT NULL,
    p_exposure_type VARCHAR(100) DEFAULT NULL,
    p_is_contact_of UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_case_id UUID;
    v_disease_id INTEGER;
    v_district_id INTEGER;
    v_facility_id INTEGER;
    v_generation INTEGER := 0;
    v_disease RECORD;
BEGIN
    -- Lookup disease
    SELECT * INTO v_disease FROM surveillance.diseases WHERE disease_code = p_disease_code;
    IF v_disease.disease_id IS NULL THEN
        RAISE EXCEPTION 'Disease code % not found', p_disease_code;
    END IF;
    v_disease_id := v_disease.disease_id;
    
    -- Lookup district
    SELECT district_id INTO v_district_id FROM surveillance.districts WHERE district_code = p_district_code;
    IF v_district_id IS NULL THEN
        RAISE EXCEPTION 'District code % not found', p_district_code;
    END IF;
    
    -- Lookup facility (optional)
    IF p_facility_code IS NOT NULL THEN
        SELECT facility_id INTO v_facility_id FROM surveillance.health_facilities WHERE facility_code = p_facility_code;
    END IF;
    
    -- Calculate generation number if contact
    IF p_is_contact_of IS NOT NULL THEN
        SELECT generation_number + 1 INTO v_generation 
        FROM surveillance.cases 
        WHERE case_id = p_is_contact_of;
    END IF;
    
    -- Insert case
    INSERT INTO surveillance.cases (
        patient_id, disease_id, district_id, reporting_facility_id,
        onset_date, report_date, case_status, severity, hospitalized,
        symptoms, exposure_type, is_contact_of, generation_number
    ) VALUES (
        p_patient_id, v_disease_id, v_district_id, v_facility_id,
        p_onset_date, CURRENT_DATE, p_case_status, p_severity, p_hospitalized,
        p_symptoms, p_exposure_type, p_is_contact_of, v_generation
    )
    RETURNING case_id INTO v_case_id;
    
    -- Check if immediately notifiable
    IF v_disease.is_immediately_notifiable THEN
        -- Create alert for immediately notifiable disease
        INSERT INTO surveillance.alerts (
            alert_code, alert_level, alert_status, alert_type,
            disease_id, district_id, title, description,
            detection_date, current_value
        ) VALUES (
            'ALERT-IMM-' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS'),
            CASE WHEN v_disease.disease_code IN ('EBO', 'MAR', 'PLG') THEN 'emergency'::surveillance.alert_level
                 ELSE 'alert'::surveillance.alert_level END,
            'active',
            'immediate_notification',
            v_disease_id,
            v_district_id,
            'Immediately Notifiable Disease: ' || v_disease.disease_name,
            'New case reported requiring immediate notification',
            CURRENT_DATE,
            1
        );
    END IF;
    
    RETURN v_case_id;
END;
$$;

-- 2.2 Update case status
CREATE OR REPLACE FUNCTION surveillance.update_case_status(
    p_case_id UUID,
    p_new_status surveillance.case_status,
    p_notes TEXT DEFAULT NULL,
    p_updated_by VARCHAR(100) DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_old_status surveillance.case_status;
BEGIN
    SELECT case_status INTO v_old_status FROM surveillance.cases WHERE case_id = p_case_id;
    
    IF v_old_status IS NULL THEN
        RETURN FALSE;
    END IF;
    
    UPDATE surveillance.cases SET
        case_status = p_new_status,
        death_date = CASE WHEN p_new_status = 'deceased' THEN CURRENT_DATE ELSE death_date END,
        discharge_date = CASE WHEN p_new_status = 'recovered' THEN CURRENT_DATE ELSE discharge_date END,
        notes = COALESCE(notes || E'\n', '') || COALESCE(p_notes, ''),
        updated_at = CURRENT_TIMESTAMP
    WHERE case_id = p_case_id;
    
    RETURN TRUE;
END;
$$;

-- 2.3 Verify case
CREATE OR REPLACE FUNCTION surveillance.verify_case(
    p_case_id UUID,
    p_verified_by VARCHAR(100),
    p_new_status surveillance.case_status DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE surveillance.cases SET
        verified = TRUE,
        verified_by = p_verified_by,
        verified_at = CURRENT_TIMESTAMP,
        case_status = COALESCE(p_new_status, case_status),
        updated_at = CURRENT_TIMESTAMP
    WHERE case_id = p_case_id;
    
    RETURN FOUND;
END;
$$;

-- ============================================================================
-- SECTION 3: LABORATORY FUNCTIONS
-- ============================================================================

-- 3.1 Register specimen
CREATE OR REPLACE FUNCTION surveillance.register_specimen(
    p_case_id UUID,
    p_specimen_type surveillance.specimen_type,
    p_collection_facility_code VARCHAR(20),
    p_collected_by VARCHAR(100) DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_specimen_id UUID;
    v_facility_id INTEGER;
    v_specimen_code VARCHAR(30);
BEGIN
    SELECT facility_id INTO v_facility_id 
    FROM surveillance.health_facilities 
    WHERE facility_code = p_collection_facility_code;
    
    v_specimen_code := 'SPEC-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' ||
                       LPAD(nextval('surveillance.specimen_seq')::TEXT, 6, '0');
    
    INSERT INTO surveillance.specimens (
        specimen_code, case_id, specimen_type,
        collection_date, collection_facility_id, collected_by,
        status
    ) VALUES (
        v_specimen_code, p_case_id, p_specimen_type,
        CURRENT_TIMESTAMP, v_facility_id, p_collected_by,
        'collected'
    )
    RETURNING specimen_id INTO v_specimen_id;
    
    RETURN v_specimen_id;
END;
$$;

CREATE SEQUENCE IF NOT EXISTS surveillance.specimen_seq START 1;

-- 3.2 Record lab test result
CREATE OR REPLACE FUNCTION surveillance.record_test_result(
    p_specimen_id UUID,
    p_test_name VARCHAR(200),
    p_result surveillance.test_result,
    p_result_value VARCHAR(200) DEFAULT NULL,
    p_performed_by VARCHAR(100) DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_test_id UUID;
    v_test_code VARCHAR(30);
    v_case_id UUID;
BEGIN
    v_test_code := 'TEST-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' ||
                   LPAD(nextval('surveillance.test_seq')::TEXT, 6, '0');
    
    INSERT INTO surveillance.lab_tests (
        test_code, specimen_id, test_name, test_date,
        result, result_value, result_date, performed_by
    ) VALUES (
        v_test_code, p_specimen_id, p_test_name, CURRENT_TIMESTAMP,
        p_result, p_result_value, CURRENT_TIMESTAMP, p_performed_by
    )
    RETURNING test_id INTO v_test_id;
    
    -- Auto-update case status on positive result
    IF p_result = 'positive' THEN
        SELECT case_id INTO v_case_id FROM surveillance.specimens WHERE specimen_id = p_specimen_id;
        
        UPDATE surveillance.cases SET
            case_status = 'confirmed',
            updated_at = CURRENT_TIMESTAMP
        WHERE case_id = v_case_id
        AND case_status = 'suspected';
    END IF;
    
    RETURN v_test_id;
END;
$$;

CREATE SEQUENCE IF NOT EXISTS surveillance.test_seq START 1;

-- ============================================================================
-- SECTION 4: CONTACT TRACING
-- ============================================================================

-- 4.1 Register contact
CREATE OR REPLACE FUNCTION surveillance.register_contact(
    p_case_id UUID,
    p_contact_name VARCHAR(200),
    p_phone VARCHAR(20) DEFAULT NULL,
    p_relationship VARCHAR(50) DEFAULT NULL,
    p_exposure_date DATE DEFAULT NULL,
    p_district_code VARCHAR(10) DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_contact_id UUID;
    v_district_id INTEGER;
    v_quarantine_days INTEGER;
    v_disease_id INTEGER;
BEGIN
    -- Get district
    IF p_district_code IS NOT NULL THEN
        SELECT district_id INTO v_district_id FROM surveillance.districts WHERE district_code = p_district_code;
    END IF;
    
    -- Get incubation period for quarantine
    SELECT d.disease_id, d.incubation_max_days INTO v_disease_id, v_quarantine_days
    FROM surveillance.cases c
    JOIN surveillance.diseases d ON c.disease_id = d.disease_id
    WHERE c.case_id = p_case_id;
    
    INSERT INTO surveillance.case_contacts (
        case_id, contact_name, phone, relationship,
        exposure_date, district_id,
        quarantine_start_date, quarantine_end_date,
        follow_up_status
    ) VALUES (
        p_case_id, p_contact_name, p_phone, p_relationship,
        COALESCE(p_exposure_date, CURRENT_DATE), v_district_id,
        CURRENT_DATE, CURRENT_DATE + (COALESCE(v_quarantine_days, 14) || ' days')::INTERVAL,
        'pending'
    )
    RETURNING contact_id INTO v_contact_id;
    
    RETURN v_contact_id;
END;
$$;

-- 4.2 Update contact follow-up
CREATE OR REPLACE FUNCTION surveillance.update_contact_followup(
    p_contact_id UUID,
    p_status VARCHAR(50),
    p_developed_symptoms BOOLEAN DEFAULT FALSE,
    p_link_to_case_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE surveillance.case_contacts SET
        follow_up_status = p_status,
        last_follow_up_date = CURRENT_DATE,
        developed_symptoms = p_developed_symptoms,
        became_case = (p_link_to_case_id IS NOT NULL),
        linked_case_id = p_link_to_case_id,
        updated_at = CURRENT_TIMESTAMP
    WHERE contact_id = p_contact_id;
    
    RETURN FOUND;
END;
$$;

-- ============================================================================
-- SECTION 5: OUTBREAK MANAGEMENT
-- ============================================================================

-- 5.1 Declare outbreak
CREATE OR REPLACE FUNCTION surveillance.declare_outbreak(
    p_disease_code VARCHAR(20),
    p_district_code VARCHAR(10),
    p_first_case_date DATE DEFAULT NULL,
    p_declared_by VARCHAR(100) DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_outbreak_id UUID;
    v_disease_id INTEGER;
    v_district_id INTEGER;
    v_outbreak_code VARCHAR(30);
    v_total_cases INTEGER;
    v_confirmed_cases INTEGER;
    v_deaths INTEGER;
BEGIN
    SELECT disease_id INTO v_disease_id FROM surveillance.diseases WHERE disease_code = p_disease_code;
    SELECT district_id INTO v_district_id FROM surveillance.districts WHERE district_code = p_district_code;
    
    -- Count current cases
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE case_status = 'confirmed'),
        COUNT(*) FILTER (WHERE case_status = 'deceased')
    INTO v_total_cases, v_confirmed_cases, v_deaths
    FROM surveillance.cases
    WHERE disease_id = v_disease_id AND district_id = v_district_id
    AND report_date > CURRENT_DATE - INTERVAL '30 days';
    
    v_outbreak_code := 'OBK-' || p_disease_code || '-' || p_district_code || '-' ||
                       TO_CHAR(CURRENT_DATE, 'YYYYMMDD');
    
    INSERT INTO surveillance.outbreaks (
        outbreak_code, disease_id, district_id,
        declaration_date, first_case_date,
        total_cases, confirmed_cases, deaths,
        response_status, alert_level,
        created_by
    ) VALUES (
        v_outbreak_code, v_disease_id, v_district_id,
        CURRENT_DATE, COALESCE(p_first_case_date, CURRENT_DATE - INTERVAL '7 days'),
        v_total_cases, v_confirmed_cases, v_deaths,
        'active', 'outbreak',
        p_declared_by
    )
    RETURNING outbreak_id INTO v_outbreak_id;
    
    -- Create alert
    INSERT INTO surveillance.alerts (
        alert_code, alert_level, alert_status, alert_type,
        disease_id, district_id, outbreak_id,
        title, description, detection_date, current_value
    ) VALUES (
        'ALERT-OBK-' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS'),
        'outbreak',
        'active',
        'outbreak_declared',
        v_disease_id, v_district_id, v_outbreak_id,
        'Outbreak Declared: ' || (SELECT disease_name FROM surveillance.diseases WHERE disease_id = v_disease_id),
        'Outbreak declared in ' || (SELECT district_name FROM surveillance.districts WHERE district_id = v_district_id),
        CURRENT_DATE,
        v_total_cases
    );
    
    RETURN v_outbreak_id;
END;
$$;

-- 5.2 Update outbreak status
CREATE OR REPLACE FUNCTION surveillance.update_outbreak(
    p_outbreak_id UUID,
    p_response_status VARCHAR(50) DEFAULT NULL,
    p_situation_summary TEXT DEFAULT NULL,
    p_containment_measures TEXT[] DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_disease_id INTEGER;
    v_district_id INTEGER;
BEGIN
    SELECT disease_id, district_id INTO v_disease_id, v_district_id
    FROM surveillance.outbreaks WHERE outbreak_id = p_outbreak_id;
    
    -- Recount cases
    UPDATE surveillance.outbreaks SET
        response_status = COALESCE(p_response_status, response_status),
        situation_summary = COALESCE(p_situation_summary, situation_summary),
        containment_measures = COALESCE(p_containment_measures, containment_measures),
        total_cases = (SELECT COUNT(*) FROM surveillance.cases 
                       WHERE disease_id = v_disease_id AND district_id = v_district_id
                       AND report_date > declaration_date),
        confirmed_cases = (SELECT COUNT(*) FROM surveillance.cases 
                          WHERE disease_id = v_disease_id AND district_id = v_district_id
                          AND report_date > declaration_date AND case_status = 'confirmed'),
        deaths = (SELECT COUNT(*) FROM surveillance.cases 
                  WHERE disease_id = v_disease_id AND district_id = v_district_id
                  AND report_date > declaration_date AND case_status = 'deceased'),
        end_date = CASE WHEN p_response_status = 'resolved' THEN CURRENT_DATE ELSE end_date END,
        updated_at = CURRENT_TIMESTAMP
    WHERE outbreak_id = p_outbreak_id;
    
    RETURN FOUND;
END;
$$;

-- ============================================================================
-- SECTION 6: AGGREGATION PROCEDURES
-- ============================================================================

-- 6.1 Refresh daily case counts
CREATE OR REPLACE PROCEDURE surveillance.refresh_daily_counts()
LANGUAGE plpgsql
AS $$
BEGIN
    -- Update/insert daily counts for last 7 days
    INSERT INTO surveillance.daily_case_counts (
        count_date, disease_id, district_id,
        new_cases, confirmed_cases, suspected_cases, deaths, recoveries
    )
    SELECT 
        c.report_date,
        c.disease_id,
        c.district_id,
        COUNT(*),
        COUNT(*) FILTER (WHERE c.case_status = 'confirmed'),
        COUNT(*) FILTER (WHERE c.case_status = 'suspected'),
        COUNT(*) FILTER (WHERE c.case_status = 'deceased'),
        COUNT(*) FILTER (WHERE c.case_status = 'recovered')
    FROM surveillance.cases c
    WHERE c.report_date > CURRENT_DATE - INTERVAL '7 days'
    GROUP BY c.report_date, c.disease_id, c.district_id
    ON CONFLICT (count_date, disease_id, district_id) DO UPDATE SET
        new_cases = EXCLUDED.new_cases,
        confirmed_cases = EXCLUDED.confirmed_cases,
        suspected_cases = EXCLUDED.suspected_cases,
        deaths = EXCLUDED.deaths,
        recoveries = EXCLUDED.recoveries,
        updated_at = CURRENT_TIMESTAMP;
    
    -- Update moving averages
    UPDATE surveillance.daily_case_counts dc SET
        seven_day_avg = (
            SELECT ROUND(AVG(new_cases), 2)
            FROM surveillance.daily_case_counts dc2
            WHERE dc2.disease_id = dc.disease_id
            AND dc2.district_id = dc.district_id
            AND dc2.count_date BETWEEN dc.count_date - INTERVAL '6 days' AND dc.count_date
        ),
        fourteen_day_avg = (
            SELECT ROUND(AVG(new_cases), 2)
            FROM surveillance.daily_case_counts dc2
            WHERE dc2.disease_id = dc.disease_id
            AND dc2.district_id = dc.district_id
            AND dc2.count_date BETWEEN dc.count_date - INTERVAL '13 days' AND dc.count_date
        )
    WHERE dc.count_date > CURRENT_DATE - INTERVAL '7 days';
    
    RAISE NOTICE 'Daily counts refreshed successfully';
END;
$$;

-- 6.2 Refresh weekly epi data
CREATE OR REPLACE PROCEDURE surveillance.refresh_weekly_epi_data(
    p_year INTEGER DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER,
    p_week INTEGER DEFAULT EXTRACT(WEEK FROM CURRENT_DATE)::INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO surveillance.weekly_epi_data (
        epi_year, epi_week, disease_id, district_id,
        total_cases, confirmed, suspected, probable, deaths,
        cases_male, cases_female,
        cases_under_5, cases_5_to_14, cases_15_to_49, cases_50_plus
    )
    SELECT 
        p_year,
        p_week,
        c.disease_id,
        c.district_id,
        COUNT(*),
        COUNT(*) FILTER (WHERE c.case_status = 'confirmed'),
        COUNT(*) FILTER (WHERE c.case_status = 'suspected'),
        COUNT(*) FILTER (WHERE c.case_status = 'probable'),
        COUNT(*) FILTER (WHERE c.case_status = 'deceased'),
        COUNT(*) FILTER (WHERE p.gender = 'male'),
        COUNT(*) FILTER (WHERE p.gender = 'female'),
        COUNT(*) FILTER (WHERE p.age_years < 5),
        COUNT(*) FILTER (WHERE p.age_years BETWEEN 5 AND 14),
        COUNT(*) FILTER (WHERE p.age_years BETWEEN 15 AND 49),
        COUNT(*) FILTER (WHERE p.age_years >= 50)
    FROM surveillance.cases c
    JOIN surveillance.patients p ON c.patient_id = p.patient_id
    WHERE c.report_year = p_year AND c.report_week = p_week
    GROUP BY c.disease_id, c.district_id
    ON CONFLICT (epi_year, epi_week, disease_id, district_id) DO UPDATE SET
        total_cases = EXCLUDED.total_cases,
        confirmed = EXCLUDED.confirmed,
        suspected = EXCLUDED.suspected,
        probable = EXCLUDED.probable,
        deaths = EXCLUDED.deaths,
        cases_male = EXCLUDED.cases_male,
        cases_female = EXCLUDED.cases_female,
        cases_under_5 = EXCLUDED.cases_under_5,
        cases_5_to_14 = EXCLUDED.cases_5_to_14,
        cases_15_to_49 = EXCLUDED.cases_15_to_49,
        cases_50_plus = EXCLUDED.cases_50_plus;
    
    RAISE NOTICE 'Weekly epi data refreshed for % week %', p_year, p_week;
END;
$$;

-- ============================================================================
-- SECTION 7: BATCH OPERATIONS
-- ============================================================================

-- 7.1 Batch import cases from JSON
CREATE OR REPLACE FUNCTION surveillance.batch_import_cases(
    p_cases JSONB
)
RETURNS TABLE(
    imported INTEGER,
    failed INTEGER,
    errors TEXT[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_case JSONB;
    v_imported INTEGER := 0;
    v_failed INTEGER := 0;
    v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    FOR v_case IN SELECT * FROM jsonb_array_elements(p_cases)
    LOOP
        BEGIN
            PERFORM surveillance.report_case(
                p_patient_id := (v_case->>'patient_id')::UUID,
                p_disease_code := v_case->>'disease_code',
                p_district_code := v_case->>'district_code',
                p_onset_date := (v_case->>'onset_date')::DATE,
                p_case_status := COALESCE((v_case->>'case_status')::surveillance.case_status, 'suspected'),
                p_hospitalized := COALESCE((v_case->>'hospitalized')::BOOLEAN, FALSE)
            );
            v_imported := v_imported + 1;
        EXCEPTION WHEN OTHERS THEN
            v_failed := v_failed + 1;
            v_errors := array_append(v_errors, SQLERRM);
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_imported, v_failed, v_errors;
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_func_count INTEGER;
    v_proc_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'surveillance'
    AND p.prokind = 'f';
    
    SELECT COUNT(*) INTO v_proc_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'surveillance'
    AND p.prokind = 'p';
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'STORED PROCEDURES CREATED SUCCESSFULLY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Functions: %', v_func_count;
    RAISE NOTICE 'Procedures: %', v_proc_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Data Entry:';
    RAISE NOTICE '  - register_patient()';
    RAISE NOTICE '  - report_case()';
    RAISE NOTICE '  - update_case_status()';
    RAISE NOTICE '  - verify_case()';
    RAISE NOTICE '';
    RAISE NOTICE 'Laboratory:';
    RAISE NOTICE '  - register_specimen()';
    RAISE NOTICE '  - record_test_result()';
    RAISE NOTICE '';
    RAISE NOTICE 'Contact Tracing:';
    RAISE NOTICE '  - register_contact()';
    RAISE NOTICE '  - update_contact_followup()';
    RAISE NOTICE '';
    RAISE NOTICE 'Outbreak Management:';
    RAISE NOTICE '  - declare_outbreak()';
    RAISE NOTICE '  - update_outbreak()';
    RAISE NOTICE '';
    RAISE NOTICE 'Aggregation:';
    RAISE NOTICE '  - refresh_daily_counts()';
    RAISE NOTICE '  - refresh_weekly_epi_data()';
    RAISE NOTICE '==========================================';
END $$;
