-- ============================================================================
-- Migration: V003__schema_tables.sql
-- Purpose: Create all surveillance system tables
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- GEOGRAPHIC HIERARCHY
-- ============================================================================

CREATE TABLE surveillance.regions (
    region_id SERIAL PRIMARY KEY,
    region_code VARCHAR(10) UNIQUE NOT NULL,
    region_name VARCHAR(100) NOT NULL,
    population INTEGER,
    coordinates POINT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE surveillance.regions IS 'Administrative regions (top-level geographic division)';

CREATE TABLE surveillance.districts (
    district_id SERIAL PRIMARY KEY,
    region_id INTEGER NOT NULL REFERENCES surveillance.regions(region_id),
    district_code VARCHAR(10) UNIQUE NOT NULL,
    district_name VARCHAR(100) NOT NULL,
    population INTEGER,
    area_sq_km NUMERIC(10,2),
    latitude NUMERIC(9,6),
    longitude NUMERIC(9,6),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE surveillance.districts IS 'Administrative districts within regions';

CREATE TABLE surveillance.sub_counties (
    sub_county_id SERIAL PRIMARY KEY,
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    sub_county_code VARCHAR(15) UNIQUE NOT NULL,
    sub_county_name VARCHAR(100) NOT NULL,
    population INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE surveillance.sub_counties IS 'Sub-county administrative units';

CREATE TABLE surveillance.health_facilities (
    facility_id SERIAL PRIMARY KEY,
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    facility_code VARCHAR(20) UNIQUE NOT NULL,
    facility_name VARCHAR(200) NOT NULL,
    facility_type surveillance.facility_type NOT NULL,
    latitude NUMERIC(9,6),
    longitude NUMERIC(9,6),
    phone VARCHAR(20),
    email VARCHAR(100),
    has_lab BOOLEAN DEFAULT FALSE,
    bed_capacity INTEGER,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE surveillance.health_facilities IS 'Healthcare facilities in the surveillance network';

-- ============================================================================
-- DISEASE REGISTRY
-- ============================================================================

CREATE TABLE surveillance.disease_categories (
    category_id SERIAL PRIMARY KEY,
    category_code VARCHAR(10) UNIQUE NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE
);
COMMENT ON TABLE surveillance.disease_categories IS 'Disease classification categories';

CREATE TABLE surveillance.diseases (
    disease_id SERIAL PRIMARY KEY,
    category_id INTEGER REFERENCES surveillance.disease_categories(category_id),
    disease_code VARCHAR(20) UNIQUE NOT NULL,
    disease_name VARCHAR(200) NOT NULL,
    icd10_code VARCHAR(10),
    transmission_mode surveillance.transmission_mode,
    incubation_min_days INTEGER,
    incubation_max_days INTEGER,
    is_immediately_notifiable BOOLEAN DEFAULT FALSE,
    outbreak_threshold INTEGER DEFAULT 10,
    baseline_cases_per_week NUMERIC(10,2),
    case_fatality_rate NUMERIC(5,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE surveillance.diseases IS 'Disease registry with epidemiological parameters';

CREATE TABLE surveillance.disease_symptoms (
    symptom_id SERIAL PRIMARY KEY,
    disease_id INTEGER NOT NULL REFERENCES surveillance.diseases(disease_id),
    symptom_name VARCHAR(100) NOT NULL,
    is_pathognomonic BOOLEAN DEFAULT FALSE,
    frequency_percent NUMERIC(5,2),
    UNIQUE(disease_id, symptom_name)
);
COMMENT ON TABLE surveillance.disease_symptoms IS 'Common symptoms by disease for syndromic surveillance';

-- ============================================================================
-- PATIENT MANAGEMENT
-- ============================================================================

CREATE TABLE surveillance.patients (
    patient_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_code VARCHAR(20) UNIQUE,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    age_years INTEGER,
    gender surveillance.gender_type DEFAULT 'unknown',
    phone VARCHAR(20),
    email VARCHAR(100),
    national_id VARCHAR(30),
    district_id INTEGER REFERENCES surveillance.districts(district_id),
    sub_county_id INTEGER REFERENCES surveillance.sub_counties(sub_county_id),
    village VARCHAR(100),
    is_healthcare_worker BOOLEAN DEFAULT FALSE,
    occupation VARCHAR(100),
    search_vector TSVECTOR,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_age CHECK (age_years IS NULL OR age_years BETWEEN 0 AND 150)
);
COMMENT ON TABLE surveillance.patients IS 'Patient demographic registry';

-- ============================================================================
-- CASE MANAGEMENT
-- ============================================================================

CREATE TABLE surveillance.cases (
    case_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_number VARCHAR(20) UNIQUE,
    patient_id UUID NOT NULL REFERENCES surveillance.patients(patient_id),
    disease_id INTEGER NOT NULL REFERENCES surveillance.diseases(disease_id),
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    reporting_facility_id INTEGER REFERENCES surveillance.health_facilities(facility_id),
    onset_date DATE NOT NULL,
    report_date DATE NOT NULL DEFAULT CURRENT_DATE,
    report_year INTEGER GENERATED ALWAYS AS (EXTRACT(YEAR FROM report_date)::INTEGER) STORED,
    report_week INTEGER GENERATED ALWAYS AS (EXTRACT(WEEK FROM report_date)::INTEGER) STORED,
    case_status surveillance.case_status DEFAULT 'suspected',
    severity surveillance.severity_level DEFAULT 'mild',
    hospitalized BOOLEAN DEFAULT FALSE,
    hospitalization_date DATE,
    icu_admission BOOLEAN DEFAULT FALSE,
    death_date DATE,
    discharge_date DATE,
    symptoms TEXT[],
    exposure_type VARCHAR(100),
    exposure_location VARCHAR(200),
    travel_history JSONB,
    is_contact_of UUID REFERENCES surveillance.cases(case_id),
    generation_number INTEGER DEFAULT 0,
    verified BOOLEAN DEFAULT FALSE,
    verified_by VARCHAR(100),
    verified_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_dates CHECK (onset_date <= report_date),
    CONSTRAINT death_after_onset CHECK (death_date IS NULL OR death_date >= onset_date)
);
COMMENT ON TABLE surveillance.cases IS 'Disease case registry with clinical and epidemiological data';

-- ============================================================================
-- CONTACT TRACING
-- ============================================================================

CREATE TABLE surveillance.case_contacts (
    contact_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    case_id UUID NOT NULL REFERENCES surveillance.cases(case_id),
    contact_name VARCHAR(200) NOT NULL,
    phone VARCHAR(20),
    relationship VARCHAR(50),
    exposure_date DATE,
    exposure_location VARCHAR(200),
    district_id INTEGER REFERENCES surveillance.districts(district_id),
    village VARCHAR(100),
    quarantine_start_date DATE,
    quarantine_end_date DATE,
    follow_up_status VARCHAR(50) DEFAULT 'pending',
    last_follow_up_date DATE,
    developed_symptoms BOOLEAN DEFAULT FALSE,
    became_case BOOLEAN DEFAULT FALSE,
    linked_case_id UUID REFERENCES surveillance.cases(case_id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE surveillance.case_contacts IS 'Contact tracing records for case investigation';

-- ============================================================================
-- LABORATORY SYSTEM
-- ============================================================================

CREATE TABLE surveillance.specimens (
    specimen_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    specimen_code VARCHAR(30) UNIQUE,
    case_id UUID NOT NULL REFERENCES surveillance.cases(case_id),
    specimen_type surveillance.specimen_type NOT NULL,
    collection_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    collection_facility_id INTEGER REFERENCES surveillance.health_facilities(facility_id),
    collected_by VARCHAR(100),
    status VARCHAR(50) DEFAULT 'collected',
    received_at_lab TIMESTAMP WITH TIME ZONE,
    testing_facility_id INTEGER REFERENCES surveillance.health_facilities(facility_id),
    storage_location VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE surveillance.specimens IS 'Laboratory specimen tracking';

CREATE TABLE surveillance.lab_tests (
    test_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    test_code VARCHAR(30) UNIQUE,
    specimen_id UUID NOT NULL REFERENCES surveillance.specimens(specimen_id),
    test_name VARCHAR(200) NOT NULL,
    test_method VARCHAR(200),
    test_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    result surveillance.test_result DEFAULT 'pending',
    result_value VARCHAR(200),
    result_unit VARCHAR(50),
    reference_range VARCHAR(100),
    result_date TIMESTAMP WITH TIME ZONE,
    turnaround_hours NUMERIC(6,1) GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (result_date - test_date))/3600
    ) STORED,
    testing_facility_id INTEGER REFERENCES surveillance.health_facilities(facility_id),
    performed_by VARCHAR(100),
    validated_by VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE surveillance.lab_tests IS 'Laboratory test results';

-- ============================================================================
-- OUTBREAK MANAGEMENT
-- ============================================================================

CREATE TABLE surveillance.outbreaks (
    outbreak_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    outbreak_code VARCHAR(50) UNIQUE NOT NULL,
    disease_id INTEGER NOT NULL REFERENCES surveillance.diseases(disease_id),
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    declaration_date DATE NOT NULL DEFAULT CURRENT_DATE,
    first_case_date DATE,
    end_date DATE,
    response_status VARCHAR(50) DEFAULT 'active',
    alert_level surveillance.alert_level DEFAULT 'outbreak',
    total_cases INTEGER DEFAULT 0,
    confirmed_cases INTEGER DEFAULT 0,
    deaths INTEGER DEFAULT 0,
    case_fatality_rate NUMERIC(5,2) GENERATED ALWAYS AS (
        CASE WHEN confirmed_cases > 0 
             THEN ROUND(100.0 * deaths / confirmed_cases, 2)
             ELSE 0 END
    ) STORED,
    attack_rate NUMERIC(8,4),
    situation_summary TEXT,
    containment_measures TEXT[],
    resources_deployed JSONB,
    created_by VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE surveillance.outbreaks IS 'Declared outbreak events for response coordination';

-- ============================================================================
-- ALERT SYSTEM
-- ============================================================================

CREATE TABLE surveillance.alerts (
    alert_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alert_code VARCHAR(50) UNIQUE NOT NULL,
    alert_level surveillance.alert_level NOT NULL,
    alert_status surveillance.alert_status DEFAULT 'active',
    alert_type VARCHAR(50),
    disease_id INTEGER REFERENCES surveillance.diseases(disease_id),
    district_id INTEGER REFERENCES surveillance.districts(district_id),
    outbreak_id UUID REFERENCES surveillance.outbreaks(outbreak_id),
    title VARCHAR(300) NOT NULL,
    description TEXT,
    detection_date DATE NOT NULL DEFAULT CURRENT_DATE,
    current_value INTEGER,
    threshold_value INTEGER,
    baseline_value NUMERIC(10,2),
    detection_method VARCHAR(50),
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    acknowledged_by VARCHAR(100),
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by VARCHAR(100),
    resolution_notes TEXT,
    escalated BOOLEAN DEFAULT FALSE,
    escalation_date TIMESTAMP WITH TIME ZONE,
    escalation_reason TEXT,
    escalated_by VARCHAR(100),
    notification_sent BOOLEAN DEFAULT FALSE,
    notification_sent_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE surveillance.alerts IS 'Surveillance alerts for anomaly detection';

CREATE TABLE surveillance.alert_notifications (
    notification_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alert_id UUID NOT NULL REFERENCES surveillance.alerts(alert_id),
    recipient_type VARCHAR(50) NOT NULL,
    recipient_id VARCHAR(100),
    recipient_email VARCHAR(200),
    recipient_phone VARCHAR(20),
    notification_channel VARCHAR(20) NOT NULL,
    message TEXT,
    sent_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) DEFAULT 'pending',
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE surveillance.alert_notifications IS 'Alert notification delivery tracking';

-- ============================================================================
-- TIME SERIES AGGREGATES
-- ============================================================================

CREATE TABLE surveillance.daily_case_counts (
    count_date DATE NOT NULL,
    disease_id INTEGER NOT NULL REFERENCES surveillance.diseases(disease_id),
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    new_cases INTEGER DEFAULT 0,
    confirmed_cases INTEGER DEFAULT 0,
    suspected_cases INTEGER DEFAULT 0,
    probable_cases INTEGER DEFAULT 0,
    deaths INTEGER DEFAULT 0,
    recoveries INTEGER DEFAULT 0,
    seven_day_avg NUMERIC(10,2),
    fourteen_day_avg NUMERIC(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (count_date, disease_id, district_id)
);
COMMENT ON TABLE surveillance.daily_case_counts IS 'Pre-aggregated daily case counts for analytics';

CREATE TABLE surveillance.weekly_epi_data (
    epi_year INTEGER NOT NULL,
    epi_week INTEGER NOT NULL,
    disease_id INTEGER NOT NULL REFERENCES surveillance.diseases(disease_id),
    district_id INTEGER NOT NULL REFERENCES surveillance.districts(district_id),
    total_cases INTEGER DEFAULT 0,
    confirmed INTEGER DEFAULT 0,
    suspected INTEGER DEFAULT 0,
    probable INTEGER DEFAULT 0,
    deaths INTEGER DEFAULT 0,
    cases_male INTEGER DEFAULT 0,
    cases_female INTEGER DEFAULT 0,
    cases_under_5 INTEGER DEFAULT 0,
    cases_5_to_14 INTEGER DEFAULT 0,
    cases_15_to_49 INTEGER DEFAULT 0,
    cases_50_plus INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (epi_year, epi_week, disease_id, district_id)
);
COMMENT ON TABLE surveillance.weekly_epi_data IS 'Weekly epidemiological summary data';

-- ============================================================================
-- AUDIT LOGGING
-- ============================================================================

CREATE TABLE surveillance.audit_log (
    audit_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id TEXT NOT NULL,
    operation VARCHAR(10) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    client_ip INET,
    user_agent TEXT
);
COMMENT ON TABLE surveillance.audit_log IS 'Immutable audit trail for compliance';

CREATE INDEX idx_audit_log_table_date ON surveillance.audit_log(table_name, changed_at);
CREATE INDEX idx_audit_log_record ON surveillance.audit_log(table_name, record_id);
