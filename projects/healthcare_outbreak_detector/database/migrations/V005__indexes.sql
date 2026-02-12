-- ============================================================================
-- Migration: V005__indexes.sql
-- Purpose: Create optimized indexes for surveillance system
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- GEOGRAPHIC INDEXES
-- ============================================================================

CREATE INDEX idx_districts_region ON surveillance.districts(region_id);
CREATE INDEX idx_districts_active ON surveillance.districts(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_subcounties_district ON surveillance.sub_counties(district_id);
CREATE INDEX idx_facilities_district ON surveillance.health_facilities(district_id);
CREATE INDEX idx_facilities_type ON surveillance.health_facilities(facility_type);
CREATE INDEX idx_facilities_active_lab ON surveillance.health_facilities(has_lab) WHERE is_active = TRUE AND has_lab = TRUE;

-- ============================================================================
-- DISEASE INDEXES
-- ============================================================================

CREATE INDEX idx_diseases_category ON surveillance.diseases(category_id);
CREATE INDEX idx_diseases_notifiable ON surveillance.diseases(is_immediately_notifiable) WHERE is_immediately_notifiable = TRUE;
CREATE INDEX idx_diseases_active ON surveillance.diseases(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_disease_symptoms_disease ON surveillance.disease_symptoms(disease_id);

-- ============================================================================
-- PATIENT INDEXES
-- ============================================================================

CREATE INDEX idx_patients_district ON surveillance.patients(district_id);
CREATE INDEX idx_patients_names ON surveillance.patients(last_name, first_name);
CREATE INDEX idx_patients_search_gin ON surveillance.patients USING GIN(search_vector);
CREATE INDEX idx_patients_phone ON surveillance.patients(phone) WHERE phone IS NOT NULL;
CREATE INDEX idx_patients_national_id ON surveillance.patients(national_id) WHERE national_id IS NOT NULL;
CREATE INDEX idx_patients_healthcare_worker ON surveillance.patients(is_healthcare_worker) WHERE is_healthcare_worker = TRUE;

-- ============================================================================
-- CASE INDEXES - PRIMARY QUERIES
-- ============================================================================

-- Core lookup indexes
CREATE INDEX idx_cases_patient ON surveillance.cases(patient_id);
CREATE INDEX idx_cases_disease ON surveillance.cases(disease_id);
CREATE INDEX idx_cases_district ON surveillance.cases(district_id);
CREATE INDEX idx_cases_facility ON surveillance.cases(reporting_facility_id);
CREATE INDEX idx_cases_status ON surveillance.cases(case_status);

-- Date-based indexes
CREATE INDEX idx_cases_report_date ON surveillance.cases(report_date DESC);
CREATE INDEX idx_cases_onset_date ON surveillance.cases(onset_date);
CREATE INDEX idx_cases_year_week ON surveillance.cases(report_year, report_week);

-- BRIN index for time-series queries on large tables
CREATE INDEX idx_cases_report_date_brin ON surveillance.cases USING BRIN(report_date);

-- Composite indexes for common queries
CREATE INDEX idx_cases_disease_district_date ON surveillance.cases(disease_id, district_id, report_date DESC);
CREATE INDEX idx_cases_district_date ON surveillance.cases(district_id, report_date DESC);
CREATE INDEX idx_cases_disease_status ON surveillance.cases(disease_id, case_status);

-- Partial indexes for active/recent cases
CREATE INDEX idx_cases_active ON surveillance.cases(disease_id, district_id, report_date) 
    WHERE case_status IN ('suspected', 'probable', 'confirmed');
CREATE INDEX idx_cases_recent_30d ON surveillance.cases(disease_id, district_id) 
    WHERE report_date > CURRENT_DATE - INTERVAL '30 days';
CREATE INDEX idx_cases_hospitalized ON surveillance.cases(district_id, report_date) 
    WHERE hospitalized = TRUE;
CREATE INDEX idx_cases_deceased ON surveillance.cases(disease_id, death_date) 
    WHERE case_status = 'deceased';

-- Covering index for dashboard queries
CREATE INDEX idx_cases_dashboard_covering ON surveillance.cases(disease_id, district_id, report_date, case_status)
    INCLUDE (severity, hospitalized);

-- Contact tracing
CREATE INDEX idx_cases_contact_of ON surveillance.cases(is_contact_of) WHERE is_contact_of IS NOT NULL;
CREATE INDEX idx_cases_generation ON surveillance.cases(disease_id, generation_number);

-- ============================================================================
-- CONTACT TRACING INDEXES
-- ============================================================================

CREATE INDEX idx_contacts_case ON surveillance.case_contacts(case_id);
CREATE INDEX idx_contacts_district ON surveillance.case_contacts(district_id);
CREATE INDEX idx_contacts_followup_status ON surveillance.case_contacts(follow_up_status);
CREATE INDEX idx_contacts_quarantine_active ON surveillance.case_contacts(quarantine_end_date) 
    WHERE quarantine_end_date >= CURRENT_DATE AND NOT developed_symptoms;
CREATE INDEX idx_contacts_became_case ON surveillance.case_contacts(linked_case_id) WHERE became_case = TRUE;

-- ============================================================================
-- LABORATORY INDEXES
-- ============================================================================

CREATE INDEX idx_specimens_case ON surveillance.specimens(case_id);
CREATE INDEX idx_specimens_status ON surveillance.specimens(status);
CREATE INDEX idx_specimens_collection_date ON surveillance.specimens(collection_date DESC);
CREATE INDEX idx_specimens_pending ON surveillance.specimens(collection_date) 
    WHERE status IN ('collected', 'in_transit', 'received');

CREATE INDEX idx_lab_tests_specimen ON surveillance.lab_tests(specimen_id);
CREATE INDEX idx_lab_tests_result ON surveillance.lab_tests(result);
CREATE INDEX idx_lab_tests_date ON surveillance.lab_tests(test_date DESC);
CREATE INDEX idx_lab_tests_positive ON surveillance.lab_tests(specimen_id, result_date) 
    WHERE result = 'positive';
CREATE INDEX idx_lab_tests_turnaround ON surveillance.lab_tests(turnaround_hours) 
    WHERE turnaround_hours IS NOT NULL;

-- ============================================================================
-- OUTBREAK INDEXES
-- ============================================================================

CREATE INDEX idx_outbreaks_disease ON surveillance.outbreaks(disease_id);
CREATE INDEX idx_outbreaks_district ON surveillance.outbreaks(district_id);
CREATE INDEX idx_outbreaks_active ON surveillance.outbreaks(declaration_date) 
    WHERE end_date IS NULL;
CREATE INDEX idx_outbreaks_status ON surveillance.outbreaks(response_status);
CREATE INDEX idx_outbreaks_disease_district ON surveillance.outbreaks(disease_id, district_id, declaration_date DESC);

-- ============================================================================
-- ALERT INDEXES
-- ============================================================================

CREATE INDEX idx_alerts_disease ON surveillance.alerts(disease_id);
CREATE INDEX idx_alerts_district ON surveillance.alerts(district_id);
CREATE INDEX idx_alerts_outbreak ON surveillance.alerts(outbreak_id) WHERE outbreak_id IS NOT NULL;
CREATE INDEX idx_alerts_status ON surveillance.alerts(alert_status);
CREATE INDEX idx_alerts_level ON surveillance.alerts(alert_level);
CREATE INDEX idx_alerts_active ON surveillance.alerts(alert_level, created_at DESC) 
    WHERE alert_status = 'active';
CREATE INDEX idx_alerts_unacknowledged ON surveillance.alerts(created_at) 
    WHERE alert_status = 'active' AND acknowledged_at IS NULL;
CREATE INDEX idx_alerts_detection_date ON surveillance.alerts(detection_date DESC);

-- Composite for alert queries
CREATE INDEX idx_alerts_disease_district_active ON surveillance.alerts(disease_id, district_id) 
    WHERE alert_status = 'active';

-- ============================================================================
-- NOTIFICATION INDEXES
-- ============================================================================

CREATE INDEX idx_notifications_alert ON surveillance.alert_notifications(alert_id);
CREATE INDEX idx_notifications_status ON surveillance.alert_notifications(status);
CREATE INDEX idx_notifications_pending ON surveillance.alert_notifications(created_at) 
    WHERE status = 'pending';
CREATE INDEX idx_notifications_recipient ON surveillance.alert_notifications(recipient_type, recipient_id);

-- ============================================================================
-- TIME SERIES INDEXES
-- ============================================================================

CREATE INDEX idx_daily_counts_disease ON surveillance.daily_case_counts(disease_id);
CREATE INDEX idx_daily_counts_district ON surveillance.daily_case_counts(district_id);
CREATE INDEX idx_daily_counts_date ON surveillance.daily_case_counts(count_date DESC);
CREATE INDEX idx_daily_counts_disease_district ON surveillance.daily_case_counts(disease_id, district_id, count_date DESC);

-- BRIN for date-ordered data
CREATE INDEX idx_daily_counts_brin ON surveillance.daily_case_counts USING BRIN(count_date);

CREATE INDEX idx_weekly_epi_year_week ON surveillance.weekly_epi_data(epi_year DESC, epi_week DESC);
CREATE INDEX idx_weekly_epi_disease ON surveillance.weekly_epi_data(disease_id);
CREATE INDEX idx_weekly_epi_district ON surveillance.weekly_epi_data(district_id);

-- ============================================================================
-- GIN INDEXES FOR JSONB AND ARRAYS
-- ============================================================================

CREATE INDEX idx_cases_symptoms_gin ON surveillance.cases USING GIN(symptoms);
CREATE INDEX idx_cases_travel_gin ON surveillance.cases USING GIN(travel_history) WHERE travel_history IS NOT NULL;
CREATE INDEX idx_outbreaks_measures_gin ON surveillance.outbreaks USING GIN(containment_measures);
CREATE INDEX idx_outbreaks_resources_gin ON surveillance.outbreaks USING GIN(resources_deployed);
