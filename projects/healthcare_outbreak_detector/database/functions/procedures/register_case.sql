-- ============================================================================
-- Procedure: register_case.sql
-- Purpose: Case registration and initial processing
-- ============================================================================

SET search_path TO surveillance, public;

-- Register new patient
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
    IF p_district_code IS NOT NULL THEN
        SELECT district_id INTO v_district_id 
        FROM surveillance.districts WHERE district_code = p_district_code;
    END IF;
    
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

-- Report new case
CREATE OR REPLACE FUNCTION surveillance.report_case(
    p_patient_id UUID,
    p_disease_code VARCHAR(20),
    p_district_code VARCHAR(10),
    p_onset_date DATE,
    p_facility_code VARCHAR(20) DEFAULT NULL,
    p_case_status surveillance.case_status DEFAULT 'suspected',
    p_severity surveillance.severity_level DEFAULT 'mild',
    p_hospitalized BOOLEAN DEFAULT FALSE,
    p_symptoms TEXT[] DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_case_id UUID;
    v_disease_id INTEGER;
    v_district_id INTEGER;
    v_facility_id INTEGER;
    v_disease RECORD;
BEGIN
    -- Lookup disease
    SELECT * INTO v_disease FROM surveillance.diseases WHERE disease_code = p_disease_code;
    IF v_disease.disease_id IS NULL THEN
        RAISE EXCEPTION 'Disease code % not found', p_disease_code;
    END IF;
    v_disease_id := v_disease.disease_id;
    
    -- Lookup district
    SELECT district_id INTO v_district_id 
    FROM surveillance.districts WHERE district_code = p_district_code;
    IF v_district_id IS NULL THEN
        RAISE EXCEPTION 'District code % not found', p_district_code;
    END IF;
    
    -- Lookup facility (optional)
    IF p_facility_code IS NOT NULL THEN
        SELECT facility_id INTO v_facility_id 
        FROM surveillance.health_facilities WHERE facility_code = p_facility_code;
    END IF;
    
    -- Insert case
    INSERT INTO surveillance.cases (
        patient_id, disease_id, district_id, reporting_facility_id,
        onset_date, report_date, case_status, severity, hospitalized, symptoms
    ) VALUES (
        p_patient_id, v_disease_id, v_district_id, v_facility_id,
        p_onset_date, CURRENT_DATE, p_case_status, p_severity, p_hospitalized, p_symptoms
    )
    RETURNING case_id INTO v_case_id;
    
    -- Check if immediately notifiable
    IF v_disease.is_immediately_notifiable THEN
        INSERT INTO surveillance.alerts (
            alert_code, alert_level, alert_status, alert_type,
            disease_id, district_id, title, description,
            detection_date, current_value
        ) VALUES (
            'IMMED-' || p_disease_code || '-' || TO_CHAR(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS'),
            CASE WHEN p_disease_code IN ('EBO', 'MAR', 'PLG') THEN 'emergency' ELSE 'alert' END,
            'active', 'immediate_notification',
            v_disease_id, v_district_id,
            'Immediately Notifiable: ' || v_disease.disease_name,
            'New case reported requiring immediate notification',
            CURRENT_DATE, 1
        );
    END IF;
    
    RETURN v_case_id;
END;
$$;

COMMENT ON FUNCTION surveillance.register_patient IS 'Register new patient in the surveillance system';
COMMENT ON FUNCTION surveillance.report_case IS 'Report new disease case with automatic alert generation for notifiable diseases';
