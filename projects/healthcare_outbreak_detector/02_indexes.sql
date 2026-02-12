-- ============================================================================
-- 🏥 HEALTHCARE OUTBREAK DETECTOR - PERFORMANCE INDEXES
-- ============================================================================
-- File: 02_indexes.sql
-- Purpose: Optimized indexes for surveillance query patterns
-- Database: PostgreSQL 14+
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- SECTION 1: PRIMARY LOOKUP INDEXES
-- ============================================================================

-- 1.1 Regions & Districts
CREATE INDEX IF NOT EXISTS idx_districts_region ON surveillance.districts(region_id);
CREATE INDEX IF NOT EXISTS idx_districts_code ON surveillance.districts(district_code);
CREATE INDEX IF NOT EXISTS idx_districts_name ON surveillance.districts USING gin(district_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_sub_counties_district ON surveillance.sub_counties(district_id);

-- 1.2 Health Facilities
CREATE INDEX IF NOT EXISTS idx_facilities_district ON surveillance.health_facilities(district_id);
CREATE INDEX IF NOT EXISTS idx_facilities_type ON surveillance.health_facilities(facility_type);
CREATE INDEX IF NOT EXISTS idx_facilities_code ON surveillance.health_facilities(facility_code);
CREATE INDEX IF NOT EXISTS idx_facilities_reporting ON surveillance.health_facilities(is_reporting_facility) 
    WHERE is_reporting_facility = TRUE;
CREATE INDEX IF NOT EXISTS idx_facilities_testing ON surveillance.health_facilities(is_testing_facility) 
    WHERE is_testing_facility = TRUE;
CREATE INDEX IF NOT EXISTS idx_facilities_name ON surveillance.health_facilities USING gin(facility_name gin_trgm_ops);

-- 1.3 Diseases
CREATE INDEX IF NOT EXISTS idx_diseases_category ON surveillance.diseases(category_id);
CREATE INDEX IF NOT EXISTS idx_diseases_code ON surveillance.diseases(disease_code);
CREATE INDEX IF NOT EXISTS idx_diseases_icd10 ON surveillance.diseases(icd10_code);
CREATE INDEX IF NOT EXISTS idx_diseases_notifiable ON surveillance.diseases(is_notifiable) WHERE is_notifiable = TRUE;
CREATE INDEX IF NOT EXISTS idx_diseases_outbreak_prone ON surveillance.diseases(is_outbreak_prone) WHERE is_outbreak_prone = TRUE;
CREATE INDEX IF NOT EXISTS idx_diseases_immediately_notifiable ON surveillance.diseases(is_immediately_notifiable) 
    WHERE is_immediately_notifiable = TRUE;

-- ============================================================================
-- SECTION 2: PATIENT INDEXES
-- ============================================================================

-- 2.1 Patient lookups
CREATE INDEX IF NOT EXISTS idx_patients_code ON surveillance.patients(patient_code);
CREATE INDEX IF NOT EXISTS idx_patients_district ON surveillance.patients(district_id);
CREATE INDEX IF NOT EXISTS idx_patients_sub_county ON surveillance.patients(sub_county_id);
CREATE INDEX IF NOT EXISTS idx_patients_gender ON surveillance.patients(gender);
CREATE INDEX IF NOT EXISTS idx_patients_age ON surveillance.patients(age_years);
CREATE INDEX IF NOT EXISTS idx_patients_dob ON surveillance.patients(date_of_birth);
CREATE INDEX IF NOT EXISTS idx_patients_healthcare_worker ON surveillance.patients(is_healthcare_worker) 
    WHERE is_healthcare_worker = TRUE;

-- 2.2 Full-text search
CREATE INDEX IF NOT EXISTS idx_patients_search ON surveillance.patients USING gin(search_vector);
CREATE INDEX IF NOT EXISTS idx_patients_name ON surveillance.patients USING gin(
    (first_name || ' ' || last_name) gin_trgm_ops
);
CREATE INDEX IF NOT EXISTS idx_patients_phone ON surveillance.patients(phone) WHERE phone IS NOT NULL;

-- 2.3 Patient creation date (for recent patients)
CREATE INDEX IF NOT EXISTS idx_patients_created ON surveillance.patients(created_at DESC);

-- ============================================================================
-- SECTION 3: CASE INDEXES (CRITICAL FOR SURVEILLANCE)
-- ============================================================================

-- 3.1 Core case lookups
CREATE INDEX IF NOT EXISTS idx_cases_patient ON surveillance.cases(patient_id);
CREATE INDEX IF NOT EXISTS idx_cases_disease ON surveillance.cases(disease_id);
CREATE INDEX IF NOT EXISTS idx_cases_district ON surveillance.cases(district_id);
CREATE INDEX IF NOT EXISTS idx_cases_sub_county ON surveillance.cases(sub_county_id);
CREATE INDEX IF NOT EXISTS idx_cases_reporting_facility ON surveillance.cases(reporting_facility_id);
CREATE INDEX IF NOT EXISTS idx_cases_treating_facility ON surveillance.cases(treating_facility_id);
CREATE INDEX IF NOT EXISTS idx_cases_number ON surveillance.cases(case_number);

-- 3.2 Case status and severity (frequent filters)
CREATE INDEX IF NOT EXISTS idx_cases_status ON surveillance.cases(case_status);
CREATE INDEX IF NOT EXISTS idx_cases_severity ON surveillance.cases(severity);
CREATE INDEX IF NOT EXISTS idx_cases_confirmed ON surveillance.cases(case_status) WHERE case_status = 'confirmed';
CREATE INDEX IF NOT EXISTS idx_cases_suspected ON surveillance.cases(case_status) WHERE case_status = 'suspected';
CREATE INDEX IF NOT EXISTS idx_cases_deceased ON surveillance.cases(case_status) WHERE case_status = 'deceased';

-- 3.3 Date indexes (CRITICAL for time-series outbreak queries)
CREATE INDEX IF NOT EXISTS idx_cases_onset_date ON surveillance.cases(onset_date DESC);
CREATE INDEX IF NOT EXISTS idx_cases_report_date ON surveillance.cases(report_date DESC);
CREATE INDEX IF NOT EXISTS idx_cases_admission_date ON surveillance.cases(admission_date) WHERE admission_date IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cases_death_date ON surveillance.cases(death_date) WHERE death_date IS NOT NULL;

-- 3.4 BRIN indexes for time-series data (efficient for large tables)
CREATE INDEX IF NOT EXISTS idx_cases_report_date_brin ON surveillance.cases USING brin(report_date);
CREATE INDEX IF NOT EXISTS idx_cases_onset_date_brin ON surveillance.cases USING brin(onset_date);

-- 3.5 Composite indexes for outbreak detection queries
CREATE INDEX IF NOT EXISTS idx_cases_disease_district_date ON surveillance.cases(disease_id, district_id, report_date DESC);
CREATE INDEX IF NOT EXISTS idx_cases_disease_date ON surveillance.cases(disease_id, report_date DESC);
CREATE INDEX IF NOT EXISTS idx_cases_district_date ON surveillance.cases(district_id, report_date DESC);
CREATE INDEX IF NOT EXISTS idx_cases_disease_status_date ON surveillance.cases(disease_id, case_status, report_date DESC);

-- 3.6 Epidemiological week queries
CREATE INDEX IF NOT EXISTS idx_cases_year_week ON surveillance.cases(report_year, report_week);

-- 3.7 Contact tracing
CREATE INDEX IF NOT EXISTS idx_cases_contact_of ON surveillance.cases(is_contact_of) WHERE is_contact_of IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cases_generation ON surveillance.cases(generation_number);

-- 3.8 Hospitalization tracking
CREATE INDEX IF NOT EXISTS idx_cases_hospitalized ON surveillance.cases(hospitalized) WHERE hospitalized = TRUE;
CREATE INDEX IF NOT EXISTS idx_cases_icu ON surveillance.cases(icu_admission) WHERE icu_admission = TRUE;
CREATE INDEX IF NOT EXISTS idx_cases_ventilator ON surveillance.cases(on_ventilator) WHERE on_ventilator = TRUE;

-- 3.9 Verification status
CREATE INDEX IF NOT EXISTS idx_cases_unverified ON surveillance.cases(verified) WHERE verified = FALSE;

-- 3.10 Import tracking
CREATE INDEX IF NOT EXISTS idx_cases_imported ON surveillance.cases(is_imported) WHERE is_imported = TRUE;

-- ============================================================================
-- SECTION 4: CASE CONTACTS INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_contacts_case ON surveillance.case_contacts(case_id);
CREATE INDEX IF NOT EXISTS idx_contacts_district ON surveillance.case_contacts(district_id);
CREATE INDEX IF NOT EXISTS idx_contacts_status ON surveillance.case_contacts(follow_up_status);
CREATE INDEX IF NOT EXISTS idx_contacts_became_case ON surveillance.case_contacts(became_case) WHERE became_case = TRUE;
CREATE INDEX IF NOT EXISTS idx_contacts_linked_case ON surveillance.case_contacts(linked_case_id) WHERE linked_case_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_quarantine ON surveillance.case_contacts(quarantine_end_date) 
    WHERE quarantine_end_date IS NOT NULL;

-- ============================================================================
-- SECTION 5: LABORATORY INDEXES
-- ============================================================================

-- 5.1 Specimens
CREATE INDEX IF NOT EXISTS idx_specimens_case ON surveillance.specimens(case_id);
CREATE INDEX IF NOT EXISTS idx_specimens_code ON surveillance.specimens(specimen_code);
CREATE INDEX IF NOT EXISTS idx_specimens_type ON surveillance.specimens(specimen_type);
CREATE INDEX IF NOT EXISTS idx_specimens_collection_facility ON surveillance.specimens(collection_facility_id);
CREATE INDEX IF NOT EXISTS idx_specimens_testing_facility ON surveillance.specimens(testing_facility_id);
CREATE INDEX IF NOT EXISTS idx_specimens_collection_date ON surveillance.specimens(collection_date DESC);
CREATE INDEX IF NOT EXISTS idx_specimens_status ON surveillance.specimens(status);

-- 5.2 Lab tests
CREATE INDEX IF NOT EXISTS idx_tests_specimen ON surveillance.lab_tests(specimen_id);
CREATE INDEX IF NOT EXISTS idx_tests_code ON surveillance.lab_tests(test_code);
CREATE INDEX IF NOT EXISTS idx_tests_result ON surveillance.lab_tests(result);
CREATE INDEX IF NOT EXISTS idx_tests_positive ON surveillance.lab_tests(result) WHERE result = 'positive';
CREATE INDEX IF NOT EXISTS idx_tests_pending ON surveillance.lab_tests(result) WHERE result = 'pending';
CREATE INDEX IF NOT EXISTS idx_tests_date ON surveillance.lab_tests(test_date DESC);
CREATE INDEX IF NOT EXISTS idx_tests_result_date ON surveillance.lab_tests(result_date DESC);

-- ============================================================================
-- SECTION 6: OUTBREAK & ALERT INDEXES
-- ============================================================================

-- 6.1 Outbreaks
CREATE INDEX IF NOT EXISTS idx_outbreaks_disease ON surveillance.outbreaks(disease_id);
CREATE INDEX IF NOT EXISTS idx_outbreaks_district ON surveillance.outbreaks(district_id);
CREATE INDEX IF NOT EXISTS idx_outbreaks_code ON surveillance.outbreaks(outbreak_code);
CREATE INDEX IF NOT EXISTS idx_outbreaks_declaration ON surveillance.outbreaks(declaration_date DESC);
CREATE INDEX IF NOT EXISTS idx_outbreaks_status ON surveillance.outbreaks(response_status);
CREATE INDEX IF NOT EXISTS idx_outbreaks_active ON surveillance.outbreaks(response_status) 
    WHERE response_status = 'active';
CREATE INDEX IF NOT EXISTS idx_outbreaks_alert_level ON surveillance.outbreaks(alert_level);

-- 6.2 Alerts
CREATE INDEX IF NOT EXISTS idx_alerts_disease ON surveillance.alerts(disease_id);
CREATE INDEX IF NOT EXISTS idx_alerts_district ON surveillance.alerts(district_id);
CREATE INDEX IF NOT EXISTS idx_alerts_facility ON surveillance.alerts(facility_id);
CREATE INDEX IF NOT EXISTS idx_alerts_outbreak ON surveillance.alerts(outbreak_id);
CREATE INDEX IF NOT EXISTS idx_alerts_code ON surveillance.alerts(alert_code);
CREATE INDEX IF NOT EXISTS idx_alerts_level ON surveillance.alerts(alert_level);
CREATE INDEX IF NOT EXISTS idx_alerts_status ON surveillance.alerts(alert_status);
CREATE INDEX IF NOT EXISTS idx_alerts_active ON surveillance.alerts(alert_status) WHERE alert_status = 'active';
CREATE INDEX IF NOT EXISTS idx_alerts_type ON surveillance.alerts(alert_type);
CREATE INDEX IF NOT EXISTS idx_alerts_detection_date ON surveillance.alerts(detection_date DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_unacknowledged ON surveillance.alerts(acknowledged) WHERE acknowledged = FALSE;

-- 6.3 Alert notifications
CREATE INDEX IF NOT EXISTS idx_notifications_alert ON surveillance.alert_notifications(alert_id);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON surveillance.alert_notifications(status);
CREATE INDEX IF NOT EXISTS idx_notifications_channel ON surveillance.alert_notifications(channel);
CREATE INDEX IF NOT EXISTS idx_notifications_pending ON surveillance.alert_notifications(status) WHERE status = 'pending';

-- ============================================================================
-- SECTION 7: AGGREGATED DATA INDEXES
-- ============================================================================

-- 7.1 Daily case counts
CREATE INDEX IF NOT EXISTS idx_daily_counts_date ON surveillance.daily_case_counts(count_date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_counts_disease ON surveillance.daily_case_counts(disease_id);
CREATE INDEX IF NOT EXISTS idx_daily_counts_district ON surveillance.daily_case_counts(district_id);
CREATE INDEX IF NOT EXISTS idx_daily_counts_composite ON surveillance.daily_case_counts(disease_id, district_id, count_date DESC);

-- 7.2 Weekly epi data
CREATE INDEX IF NOT EXISTS idx_weekly_epi_year_week ON surveillance.weekly_epi_data(epi_year DESC, epi_week DESC);
CREATE INDEX IF NOT EXISTS idx_weekly_epi_disease ON surveillance.weekly_epi_data(disease_id);
CREATE INDEX IF NOT EXISTS idx_weekly_epi_district ON surveillance.weekly_epi_data(district_id);
CREATE INDEX IF NOT EXISTS idx_weekly_epi_above_threshold ON surveillance.weekly_epi_data(is_above_threshold) 
    WHERE is_above_threshold = TRUE;

-- ============================================================================
-- SECTION 8: AUDIT LOG INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_audit_table ON surveillance.audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_audit_operation ON surveillance.audit_log(operation);
CREATE INDEX IF NOT EXISTS idx_audit_changed_at ON surveillance.audit_log(changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_changed_by ON surveillance.audit_log(changed_by);
CREATE INDEX IF NOT EXISTS idx_audit_record ON surveillance.audit_log(record_id);

-- BRIN for time-series audit data
CREATE INDEX IF NOT EXISTS idx_audit_changed_at_brin ON surveillance.audit_log USING brin(changed_at);

-- ============================================================================
-- SECTION 9: GIN INDEXES FOR ARRAY COLUMNS
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_cases_symptoms ON surveillance.cases USING gin(symptoms);
CREATE INDEX IF NOT EXISTS idx_outbreaks_containment ON surveillance.outbreaks USING gin(containment_measures);
CREATE INDEX IF NOT EXISTS idx_notifications_recipients ON surveillance.alerts USING gin(notification_recipients);

-- ============================================================================
-- SECTION 10: COVERING INDEXES FOR COMMON QUERIES
-- ============================================================================

-- Covering index for outbreak detection query
CREATE INDEX IF NOT EXISTS idx_cases_outbreak_covering ON surveillance.cases(
    disease_id, district_id, report_date
) INCLUDE (case_status, severity, hospitalized);

-- Covering index for daily dashboard
CREATE INDEX IF NOT EXISTS idx_cases_dashboard_covering ON surveillance.cases(
    report_date DESC, disease_id
) INCLUDE (case_status, district_id, hospitalized, icu_admission);

-- Covering index for patient lookup
CREATE INDEX IF NOT EXISTS idx_patients_lookup_covering ON surveillance.patients(
    district_id, created_at DESC
) INCLUDE (patient_code, first_name, last_name, gender, age_years);

-- ============================================================================
-- SECTION 11: INDEX MAINTENANCE FUNCTIONS
-- ============================================================================

-- 11.1 Rebuild all indexes function
CREATE OR REPLACE FUNCTION surveillance.rebuild_indexes_concurrent()
RETURNS TABLE(index_name TEXT, status TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_idx RECORD;
BEGIN
    FOR v_idx IN 
        SELECT indexname
        FROM pg_indexes
        WHERE schemaname = 'surveillance'
        AND indexname NOT LIKE '%_pkey'
        ORDER BY indexname
    LOOP
        BEGIN
            EXECUTE format('REINDEX INDEX CONCURRENTLY surveillance.%I', v_idx.indexname);
            index_name := v_idx.indexname;
            status := 'SUCCESS';
        EXCEPTION WHEN OTHERS THEN
            index_name := v_idx.indexname;
            status := 'FAILED: ' || SQLERRM;
        END;
        RETURN NEXT;
    END LOOP;
END;
$$;

-- 11.2 Index usage statistics
CREATE OR REPLACE VIEW surveillance.v_index_usage AS
SELECT 
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED'
        WHEN idx_scan < 100 THEN 'LOW_USAGE'
        WHEN idx_scan < 1000 THEN 'MODERATE'
        ELSE 'HIGH_USAGE'
    END AS usage_category
FROM pg_stat_user_indexes
WHERE schemaname = 'surveillance'
ORDER BY idx_scan DESC;

-- 11.3 Missing index suggestions
CREATE OR REPLACE VIEW surveillance.v_missing_indexes AS
SELECT 
    relname AS table_name,
    seq_scan,
    seq_tup_read,
    idx_scan,
    seq_scan - idx_scan AS seq_to_idx_ratio,
    CASE 
        WHEN seq_scan > 100 AND idx_scan < seq_scan * 0.1 THEN 'NEEDS_INDEX'
        WHEN seq_scan > 10 AND idx_scan = 0 THEN 'CONSIDER_INDEX'
        ELSE 'OK'
    END AS recommendation
FROM pg_stat_user_tables
WHERE schemaname = 'surveillance'
AND seq_scan > 0
ORDER BY seq_scan - idx_scan DESC;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_index_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_index_count
    FROM pg_indexes
    WHERE schemaname = 'surveillance';
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'INDEXES CREATED SUCCESSFULLY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Total indexes: %', v_index_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Index Types Used:';
    RAISE NOTICE '  - B-tree: Primary lookups';
    RAISE NOTICE '  - GIN: Full-text, trigram, arrays';
    RAISE NOTICE '  - BRIN: Time-series data';
    RAISE NOTICE '  - Covering: High-performance queries';
    RAISE NOTICE '  - Partial: Filtered conditions';
    RAISE NOTICE '';
    RAISE NOTICE 'Management Functions:';
    RAISE NOTICE '  - rebuild_indexes_concurrent()';
    RAISE NOTICE '  - v_index_usage (view)';
    RAISE NOTICE '  - v_missing_indexes (view)';
    RAISE NOTICE '==========================================';
END $$;
