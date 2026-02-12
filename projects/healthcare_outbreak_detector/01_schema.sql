-- ============================================================================
-- 🏥 HEALTHCARE OUTBREAK DETECTOR - DATABASE SCHEMA
-- ============================================================================
-- File: 01_schema.sql
-- Purpose: Core tables, custom types, constraints, triggers
-- Database: PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- SECTION 1: SCHEMA & EXTENSIONS
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS surveillance;
SET search_path TO surveillance, public;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";      -- Fuzzy text search
CREATE EXTENSION IF NOT EXISTS "btree_gist";   -- Exclusion constraints

-- ============================================================================
-- SECTION 2: CUSTOM ENUM TYPES
-- ============================================================================

-- Gender
CREATE TYPE surveillance.gender_type AS ENUM (
    'male', 'female', 'other', 'unknown'
);

-- Case status
CREATE TYPE surveillance.case_status AS ENUM (
    'suspected', 'probable', 'confirmed', 'ruled_out', 'recovered', 'deceased'
);

-- Severity levels
CREATE TYPE surveillance.severity_level AS ENUM (
    'mild', 'moderate', 'severe', 'critical'
);

-- Alert levels
CREATE TYPE surveillance.alert_level AS ENUM (
    'watch', 'alert', 'outbreak', 'emergency'
);

-- Alert status
CREATE TYPE surveillance.alert_status AS ENUM (
    'active', 'investigating', 'contained', 'resolved', 'escalated'
);

-- Specimen types
CREATE TYPE surveillance.specimen_type AS ENUM (
    'blood', 'urine', 'stool', 'sputum', 'swab_nasal', 'swab_throat',
    'csf', 'tissue', 'serum', 'plasma', 'other'
);

-- Test result
CREATE TYPE surveillance.test_result AS ENUM (
    'positive', 'negative', 'inconclusive', 'pending', 'invalid'
);

-- Transmission mode
CREATE TYPE surveillance.transmission_mode AS ENUM (
    'vector_borne', 'waterborne', 'airborne', 'contact', 'foodborne',
    'bloodborne', 'sexual', 'vertical', 'unknown'
);

-- Facility type
CREATE TYPE surveillance.facility_type AS ENUM (
    'national_referral', 'regional_referral', 'district_hospital',
    'health_center_iv', 'health_center_iii', 'health_center_ii',
    'clinic', 'laboratory', 'pharmacy'
);

-- ============================================================================
-- SECTION 3: REFERENCE TABLES
-- ============================================================================

-- 3.1 Regions (Uganda's 4 regions)
CREATE TABLE surveillance.regions (
    region_id SERIAL PRIMARY KEY,
    region_code VARCHAR(10) UNIQUE NOT NULL,
    region_name VARCHAR(50) NOT NULL,
    population INTEGER,
    area_sq_km DECIMAL(10,2),
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- 3.2 Districts
CREATE TABLE surveillance.districts (
    district_id SERIAL PRIMARY KEY,
    region_id INTEGER NOT NULL REFERENCES surveillance.regions(region_id),
    district_code VARCHAR(10) UNIQUE NOT NULL,
    district_name VARCHAR(100) NOT NULL,
    population INTEGER,
    area_sq_km DECIMAL(10,2),
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    risk_level VARCHAR(20) DEFAULT 'normal',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- 3.3 Sub-counties
CREATE TABLE surveillance.sub_counties (
    sub_county_id SERIAL PRIMARY KEY,
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    sub_county_code VARCHAR(15) UNIQUE NOT NULL,
    sub_county_name VARCHAR(100) NOT NULL,
    population INTEGER,
    is_active BOOLEAN DEFAULT TRUE
);

-- 3.4 Health facilities
CREATE TABLE surveillance.health_facilities (
    facility_id SERIAL PRIMARY KEY,
    facility_code VARCHAR(20) UNIQUE NOT NULL,
    facility_name VARCHAR(200) NOT NULL,
    facility_type surveillance.facility_type NOT NULL,
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    sub_county_id INTEGER REFERENCES surveillance.sub_counties(sub_county_id),
    
    -- Contact
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(100),
    
    -- Location
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    
    -- Capacity
    bed_capacity INTEGER,
    icu_beds INTEGER,
    isolation_beds INTEGER,
    
    -- Status
    is_reporting_facility BOOLEAN DEFAULT TRUE,
    is_testing_facility BOOLEAN DEFAULT FALSE,
    is_treatment_center BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- ============================================================================
-- SECTION 4: DISEASE REGISTRY
-- ============================================================================

-- 4.1 Disease categories
CREATE TABLE surveillance.disease_categories (
    category_id SERIAL PRIMARY KEY,
    category_code VARCHAR(10) UNIQUE NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

-- 4.2 Diseases
CREATE TABLE surveillance.diseases (
    disease_id SERIAL PRIMARY KEY,
    category_id INTEGER REFERENCES surveillance.disease_categories(category_id),
    disease_code VARCHAR(20) UNIQUE NOT NULL,
    disease_name VARCHAR(200) NOT NULL,
    icd10_code VARCHAR(10),                    -- WHO ICD-10 code
    
    -- Characteristics
    transmission_mode surveillance.transmission_mode,
    incubation_min_days INTEGER,
    incubation_max_days INTEGER,
    infectious_period_days INTEGER,
    case_fatality_rate DECIMAL(5,2),          -- Percentage
    
    -- Surveillance parameters
    is_notifiable BOOLEAN DEFAULT TRUE,        -- Must report to MOH
    is_immediately_notifiable BOOLEAN DEFAULT FALSE,  -- Report within 24h
    is_outbreak_prone BOOLEAN DEFAULT FALSE,
    endemic_baseline INTEGER,                  -- Expected cases/week
    outbreak_threshold INTEGER,                -- Cases to trigger alert
    
    -- Alert thresholds
    alert_threshold_multiplier DECIMAL(3,2) DEFAULT 1.5,
    outbreak_threshold_multiplier DECIMAL(3,2) DEFAULT 2.0,
    emergency_threshold_multiplier DECIMAL(3,2) DEFAULT 3.0,
    
    -- Treatment
    has_vaccine BOOLEAN DEFAULT FALSE,
    has_treatment BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- 4.3 Disease symptoms (for syndromic surveillance)
CREATE TABLE surveillance.disease_symptoms (
    symptom_id SERIAL PRIMARY KEY,
    disease_id INTEGER NOT NULL REFERENCES surveillance.diseases(disease_id),
    symptom_name VARCHAR(100) NOT NULL,
    is_primary BOOLEAN DEFAULT FALSE,
    specificity DECIMAL(3,2),  -- 0-1 scale
    UNIQUE(disease_id, symptom_name)
);

-- ============================================================================
-- SECTION 5: PATIENT & CASE MANAGEMENT
-- ============================================================================

-- 5.1 Patients
CREATE TABLE surveillance.patients (
    patient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_code VARCHAR(25) UNIQUE NOT NULL,
    
    -- Demographics
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    date_of_birth DATE,
    age_years INTEGER,
    age_months INTEGER,
    gender surveillance.gender_type DEFAULT 'unknown',
    
    -- Contact
    phone VARCHAR(20),
    email VARCHAR(100),
    
    -- Location
    district_id INTEGER REFERENCES surveillance.districts(district_id),
    sub_county_id INTEGER REFERENCES surveillance.sub_counties(sub_county_id),
    village VARCHAR(100),
    address TEXT,
    latitude DECIMAL(9,6),
    longitude DECIMAL(9,6),
    
    -- Risk factors
    is_healthcare_worker BOOLEAN DEFAULT FALSE,
    is_pregnant BOOLEAN DEFAULT FALSE,
    has_comorbidities BOOLEAN DEFAULT FALSE,
    comorbidity_details TEXT,
    travel_history TEXT,
    
    -- Metadata
    national_id VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100),
    
    -- Search optimization
    search_vector TSVECTOR,
    
    -- Constraints
    CONSTRAINT chk_age CHECK (age_years >= 0 AND age_years <= 150)
);

-- 5.2 Cases (disease episodes)
CREATE TABLE surveillance.cases (
    case_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_number VARCHAR(30) UNIQUE NOT NULL,
    
    -- References
    patient_id UUID NOT NULL REFERENCES surveillance.patients(patient_id),
    disease_id INTEGER NOT NULL REFERENCES surveillance.diseases(disease_id),
    reporting_facility_id INTEGER REFERENCES surveillance.health_facilities(facility_id),
    treating_facility_id INTEGER REFERENCES surveillance.health_facilities(facility_id),
    
    -- Location at onset
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    sub_county_id INTEGER REFERENCES surveillance.sub_counties(sub_county_id),
    
    -- Dates
    onset_date DATE NOT NULL,                  -- Symptom onset
    report_date DATE NOT NULL DEFAULT CURRENT_DATE,
    notification_date DATE,
    admission_date DATE,
    discharge_date DATE,
    death_date DATE,
    
    -- Case classification
    case_status surveillance.case_status DEFAULT 'suspected',
    severity surveillance.severity_level DEFAULT 'mild',
    
    -- Clinical
    symptoms TEXT[],
    temperature DECIMAL(4,1),
    hospitalized BOOLEAN DEFAULT FALSE,
    icu_admission BOOLEAN DEFAULT FALSE,
    on_ventilator BOOLEAN DEFAULT FALSE,
    
    -- Outcome
    outcome VARCHAR(50),
    cause_of_death VARCHAR(200),
    
    -- Epidemiological
    exposure_type VARCHAR(100),
    exposure_location TEXT,
    probable_source VARCHAR(200),
    is_imported BOOLEAN DEFAULT FALSE,
    import_country VARCHAR(100),
    
    -- Contact tracing
    is_contact_of UUID REFERENCES surveillance.cases(case_id),
    generation_number INTEGER DEFAULT 0,       -- Transmission chain position
    
    -- Verification
    verified BOOLEAN DEFAULT FALSE,
    verified_by VARCHAR(100),
    verified_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    data_source VARCHAR(50) DEFAULT 'facility_report',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100),
    
    -- Computed for partitioning
    report_year INTEGER GENERATED ALWAYS AS (EXTRACT(YEAR FROM report_date)::INTEGER) STORED,
    report_week INTEGER GENERATED ALWAYS AS (EXTRACT(WEEK FROM report_date)::INTEGER) STORED
);

-- 5.3 Case contacts (contact tracing)
CREATE TABLE surveillance.case_contacts (
    contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id UUID NOT NULL REFERENCES surveillance.cases(case_id),
    
    -- Contact person details
    contact_name VARCHAR(200),
    relationship VARCHAR(50),
    phone VARCHAR(20),
    
    -- Location
    district_id INTEGER REFERENCES surveillance.districts(district_id),
    address TEXT,
    
    -- Exposure
    exposure_date DATE,
    exposure_type VARCHAR(100),
    exposure_duration_minutes INTEGER,
    
    -- Follow-up
    follow_up_status VARCHAR(50) DEFAULT 'pending',
    last_follow_up_date DATE,
    quarantine_start_date DATE,
    quarantine_end_date DATE,
    developed_symptoms BOOLEAN DEFAULT FALSE,
    became_case BOOLEAN DEFAULT FALSE,
    linked_case_id UUID REFERENCES surveillance.cases(case_id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SECTION 6: LABORATORY DATA
-- ============================================================================

-- 6.1 Specimens
CREATE TABLE surveillance.specimens (
    specimen_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    specimen_code VARCHAR(30) UNIQUE NOT NULL,
    case_id UUID NOT NULL REFERENCES surveillance.cases(case_id),
    
    -- Collection
    specimen_type surveillance.specimen_type NOT NULL,
    collection_date TIMESTAMP WITH TIME ZONE NOT NULL,
    collection_facility_id INTEGER REFERENCES surveillance.health_facilities(facility_id),
    collected_by VARCHAR(100),
    
    -- Transport
    transport_date TIMESTAMP WITH TIME ZONE,
    transport_temperature DECIMAL(4,1),
    transport_condition VARCHAR(50),
    
    -- Reception at lab
    testing_facility_id INTEGER REFERENCES surveillance.health_facilities(facility_id),
    received_date TIMESTAMP WITH TIME ZONE,
    received_condition VARCHAR(50),
    is_adequate BOOLEAN DEFAULT TRUE,
    rejection_reason VARCHAR(200),
    
    -- Status
    status VARCHAR(50) DEFAULT 'collected',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 6.2 Lab tests
CREATE TABLE surveillance.lab_tests (
    test_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    test_code VARCHAR(30) UNIQUE NOT NULL,
    specimen_id UUID NOT NULL REFERENCES surveillance.specimens(specimen_id),
    
    -- Test details
    test_name VARCHAR(200) NOT NULL,
    test_method VARCHAR(100),
    
    -- Results
    result surveillance.test_result DEFAULT 'pending',
    result_value VARCHAR(200),
    result_unit VARCHAR(50),
    reference_range VARCHAR(100),
    
    -- Timing
    test_date TIMESTAMP WITH TIME ZONE,
    result_date TIMESTAMP WITH TIME ZONE,
    turnaround_hours INTEGER GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (result_date - test_date)) / 3600
    )::INTEGER STORED,
    
    -- Quality
    performed_by VARCHAR(100),
    verified_by VARCHAR(100),
    verification_date TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SECTION 7: OUTBREAK & ALERT MANAGEMENT
-- ============================================================================

-- 7.1 Outbreaks
CREATE TABLE surveillance.outbreaks (
    outbreak_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outbreak_code VARCHAR(30) UNIQUE NOT NULL,
    
    -- Disease
    disease_id INTEGER NOT NULL REFERENCES surveillance.diseases(disease_id),
    
    -- Location
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    affected_sub_counties INTEGER[],
    
    -- Timeline
    declaration_date DATE NOT NULL DEFAULT CURRENT_DATE,
    first_case_date DATE,
    peak_date DATE,
    end_date DATE,
    
    -- Epidemiology
    total_cases INTEGER DEFAULT 0,
    confirmed_cases INTEGER DEFAULT 0,
    suspected_cases INTEGER DEFAULT 0,
    deaths INTEGER DEFAULT 0,
    case_fatality_rate DECIMAL(5,2) GENERATED ALWAYS AS (
        ROUND(100.0 * deaths / NULLIF(confirmed_cases, 0), 2)
    ) STORED,
    attack_rate DECIMAL(8,4),
    
    -- Response
    response_status VARCHAR(50) DEFAULT 'active',
    response_team_deployed BOOLEAN DEFAULT FALSE,
    containment_measures TEXT[],
    
    -- Alerts
    alert_level surveillance.alert_level DEFAULT 'outbreak',
    escalated_to_national BOOLEAN DEFAULT FALSE,
    escalation_date DATE,
    
    -- Documentation
    situation_summary TEXT,
    response_notes TEXT,
    lessons_learned TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100)
);

-- 7.2 Alerts
CREATE TABLE surveillance.alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_code VARCHAR(30) UNIQUE NOT NULL,
    
    -- Classification
    alert_level surveillance.alert_level NOT NULL,
    alert_status surveillance.alert_status DEFAULT 'active',
    alert_type VARCHAR(50) NOT NULL,  -- 'threshold_breach', 'cluster', 'anomaly', 'manual'
    
    -- Target
    disease_id INTEGER REFERENCES surveillance.diseases(disease_id),
    district_id INTEGER REFERENCES surveillance.districts(district_id),
    facility_id INTEGER REFERENCES surveillance.health_facilities(facility_id),
    outbreak_id UUID REFERENCES surveillance.outbreaks(outbreak_id),
    
    -- Details
    title VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- Metrics that triggered alert
    current_value INTEGER,
    baseline_value DECIMAL(10,2),
    threshold_value DECIMAL(10,2),
    deviation_percent DECIMAL(8,2),
    
    -- Time period
    detection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    period_start DATE,
    period_end DATE,
    
    -- Response
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by VARCHAR(100),
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    investigated BOOLEAN DEFAULT FALSE,
    investigation_notes TEXT,
    resolution_notes TEXT,
    resolved_date DATE,
    
    -- Notifications
    notifications_sent BOOLEAN DEFAULT FALSE,
    notification_recipients TEXT[],
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) DEFAULT 'system'
);

-- 7.3 Alert notifications log
CREATE TABLE surveillance.alert_notifications (
    notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_id UUID NOT NULL REFERENCES surveillance.alerts(alert_id),
    
    -- Recipient
    recipient_type VARCHAR(50),  -- 'district_officer', 'national_team', 'facility_head'
    recipient_name VARCHAR(200),
    recipient_phone VARCHAR(20),
    recipient_email VARCHAR(100),
    
    -- Message
    channel VARCHAR(20),  -- 'sms', 'email', 'push', 'whatsapp'
    message_content TEXT,
    
    -- Status
    sent_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'pending',
    error_message TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SECTION 8: AGGREGATED STATISTICS
-- ============================================================================

-- 8.1 Daily case counts (for fast time-series queries)
CREATE TABLE surveillance.daily_case_counts (
    count_id SERIAL PRIMARY KEY,
    count_date DATE NOT NULL,
    disease_id INTEGER NOT NULL REFERENCES surveillance.diseases(disease_id),
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    
    -- Counts
    new_cases INTEGER DEFAULT 0,
    confirmed_cases INTEGER DEFAULT 0,
    suspected_cases INTEGER DEFAULT 0,
    deaths INTEGER DEFAULT 0,
    recoveries INTEGER DEFAULT 0,
    
    -- Cumulative
    cumulative_cases INTEGER DEFAULT 0,
    cumulative_deaths INTEGER DEFAULT 0,
    
    -- Computed
    seven_day_avg DECIMAL(10,2),
    fourteen_day_avg DECIMAL(10,2),
    week_over_week_change DECIMAL(8,2),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_daily_count UNIQUE (count_date, disease_id, district_id)
);

-- 8.2 Weekly epidemiological report data
CREATE TABLE surveillance.weekly_epi_data (
    epi_id SERIAL PRIMARY KEY,
    epi_year INTEGER NOT NULL,
    epi_week INTEGER NOT NULL,
    disease_id INTEGER NOT NULL REFERENCES surveillance.diseases(disease_id),
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    
    -- Cases
    total_cases INTEGER DEFAULT 0,
    confirmed INTEGER DEFAULT 0,
    suspected INTEGER DEFAULT 0,
    probable INTEGER DEFAULT 0,
    deaths INTEGER DEFAULT 0,
    
    -- Demographics
    cases_male INTEGER DEFAULT 0,
    cases_female INTEGER DEFAULT 0,
    cases_under_5 INTEGER DEFAULT 0,
    cases_5_to_14 INTEGER DEFAULT 0,
    cases_15_to_49 INTEGER DEFAULT 0,
    cases_50_plus INTEGER DEFAULT 0,
    
    -- Rates
    incidence_rate DECIMAL(12,4),  -- per 100,000
    case_fatality_rate DECIMAL(5,2),
    
    -- Comparison
    baseline_cases DECIMAL(10,2),
    is_above_threshold BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT uq_weekly_epi UNIQUE (epi_year, epi_week, disease_id, district_id)
);

-- ============================================================================
-- SECTION 9: AUDIT LOG
-- ============================================================================

CREATE TABLE surveillance.audit_log (
    log_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id TEXT,
    operation VARCHAR(10) NOT NULL,
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

-- ============================================================================
-- SECTION 10: TRIGGERS
-- ============================================================================

-- 10.1 Auto-generate patient code
CREATE OR REPLACE FUNCTION surveillance.generate_patient_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.patient_code IS NULL THEN
        NEW.patient_code := 'PAT-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' ||
                           LPAD(nextval('surveillance.patient_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS surveillance.patient_seq START 1;

CREATE TRIGGER trg_patient_code
    BEFORE INSERT ON surveillance.patients
    FOR EACH ROW
    EXECUTE FUNCTION surveillance.generate_patient_code();

-- 10.2 Auto-generate case number
CREATE OR REPLACE FUNCTION surveillance.generate_case_number()
RETURNS TRIGGER AS $$
DECLARE
    v_disease_code VARCHAR(20);
BEGIN
    SELECT disease_code INTO v_disease_code 
    FROM surveillance.diseases 
    WHERE disease_id = NEW.disease_id;
    
    IF NEW.case_number IS NULL THEN
        NEW.case_number := 'CASE-' || COALESCE(v_disease_code, 'UNK') || '-' ||
                          TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' ||
                          LPAD(nextval('surveillance.case_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS surveillance.case_seq START 1;

CREATE TRIGGER trg_case_number
    BEFORE INSERT ON surveillance.cases
    FOR EACH ROW
    EXECUTE FUNCTION surveillance.generate_case_number();

-- 10.3 Update timestamps
CREATE OR REPLACE FUNCTION surveillance.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_patients_timestamp
    BEFORE UPDATE ON surveillance.patients
    FOR EACH ROW EXECUTE FUNCTION surveillance.update_timestamp();

CREATE TRIGGER trg_cases_timestamp
    BEFORE UPDATE ON surveillance.cases
    FOR EACH ROW EXECUTE FUNCTION surveillance.update_timestamp();

CREATE TRIGGER trg_alerts_timestamp
    BEFORE UPDATE ON surveillance.alerts
    FOR EACH ROW EXECUTE FUNCTION surveillance.update_timestamp();

CREATE TRIGGER trg_outbreaks_timestamp
    BEFORE UPDATE ON surveillance.outbreaks
    FOR EACH ROW EXECUTE FUNCTION surveillance.update_timestamp();

-- 10.4 Patient search vector update
CREATE OR REPLACE FUNCTION surveillance.update_patient_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('english', COALESCE(NEW.first_name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.last_name, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.patient_code, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.village, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.phone, '')), 'C');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_patient_search_vector
    BEFORE INSERT OR UPDATE ON surveillance.patients
    FOR EACH ROW
    EXECUTE FUNCTION surveillance.update_patient_search_vector();

-- 10.5 Audit logging trigger
CREATE OR REPLACE FUNCTION surveillance.audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO surveillance.audit_log (table_name, record_id, operation, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.case_id::TEXT, 'INSERT', to_jsonb(NEW), current_user);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO surveillance.audit_log (table_name, record_id, operation, old_data, new_data, changed_by)
        VALUES (TG_TABLE_NAME, NEW.case_id::TEXT, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), current_user);
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO surveillance.audit_log (table_name, record_id, operation, old_data, changed_by)
        VALUES (TG_TABLE_NAME, OLD.case_id::TEXT, 'DELETE', to_jsonb(OLD), current_user);
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cases_audit
    AFTER INSERT OR UPDATE OR DELETE ON surveillance.cases
    FOR EACH ROW EXECUTE FUNCTION surveillance.audit_trigger_function();

-- 10.6 Auto-calculate age from DOB
CREATE OR REPLACE FUNCTION surveillance.calculate_patient_age()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.date_of_birth IS NOT NULL THEN
        NEW.age_years := EXTRACT(YEAR FROM age(NEW.date_of_birth))::INTEGER;
        NEW.age_months := EXTRACT(MONTH FROM age(NEW.date_of_birth))::INTEGER;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_patient_age
    BEFORE INSERT OR UPDATE ON surveillance.patients
    FOR EACH ROW
    EXECUTE FUNCTION surveillance.calculate_patient_age();

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_table_count INTEGER;
    v_type_count INTEGER;
    v_trigger_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_table_count
    FROM pg_tables WHERE schemaname = 'surveillance';
    
    SELECT COUNT(*) INTO v_type_count
    FROM pg_type t
    JOIN pg_namespace n ON t.typnamespace = n.oid
    WHERE n.nspname = 'surveillance' AND t.typtype = 'e';
    
    SELECT COUNT(*) INTO v_trigger_count
    FROM pg_trigger WHERE tgname LIKE 'trg_%';
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'SCHEMA CREATED SUCCESSFULLY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Tables: %', v_table_count;
    RAISE NOTICE 'ENUM types: %', v_type_count;
    RAISE NOTICE 'Triggers: %', v_trigger_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Core Tables:';
    RAISE NOTICE '  - regions, districts, sub_counties';
    RAISE NOTICE '  - health_facilities';
    RAISE NOTICE '  - disease_categories, diseases';
    RAISE NOTICE '  - patients, cases, case_contacts';
    RAISE NOTICE '  - specimens, lab_tests';
    RAISE NOTICE '  - outbreaks, alerts, alert_notifications';
    RAISE NOTICE '  - daily_case_counts, weekly_epi_data';
    RAISE NOTICE '==========================================';
END $$;
