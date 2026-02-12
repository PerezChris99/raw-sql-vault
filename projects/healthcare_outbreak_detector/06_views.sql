-- ============================================================================
-- 🏥 HEALTHCARE OUTBREAK DETECTOR - DATABASE VIEWS
-- ============================================================================
-- File: 06_views.sql
-- Purpose: Standard views, materialized views for dashboards
-- Database: PostgreSQL 14+
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- SECTION 1: BASIC CASE VIEWS
-- ============================================================================

-- 1.1 Complete case details view
CREATE OR REPLACE VIEW surveillance.v_case_details AS
SELECT 
    c.case_id,
    c.case_number,
    c.report_date,
    c.onset_date,
    c.case_status,
    c.severity,
    c.hospitalized,
    c.death_date,
    c.discharge_date,
    c.verified,
    -- Patient info
    p.patient_id,
    p.patient_code,
    p.first_name,
    p.last_name,
    p.first_name || ' ' || p.last_name AS patient_name,
    p.age_years,
    p.gender,
    -- Disease info
    d.disease_id,
    d.disease_code,
    d.disease_name,
    d.icd10_code,
    dc.category_name AS disease_category,
    d.is_immediately_notifiable,
    -- Location info
    dist.district_id,
    dist.district_code,
    dist.district_name,
    r.region_name,
    -- Facility info
    f.facility_name AS reporting_facility,
    f.facility_type,
    -- Calculated fields
    CURRENT_DATE - c.onset_date AS days_since_onset,
    c.report_date - c.onset_date AS reporting_delay_days,
    CASE 
        WHEN c.case_status = 'deceased' THEN TRUE
        ELSE FALSE
    END AS is_fatal
FROM surveillance.cases c
JOIN surveillance.patients p ON c.patient_id = p.patient_id
JOIN surveillance.diseases d ON c.disease_id = d.disease_id
LEFT JOIN surveillance.disease_categories dc ON d.category_id = dc.category_id
JOIN surveillance.districts dist ON c.district_id = dist.district_id
JOIN surveillance.regions r ON dist.region_id = r.region_id
LEFT JOIN surveillance.health_facilities f ON c.reporting_facility_id = f.facility_id;

-- 1.2 Active cases view
CREATE OR REPLACE VIEW surveillance.v_active_cases AS
SELECT *
FROM surveillance.v_case_details
WHERE case_status IN ('suspected', 'probable', 'confirmed')
AND discharge_date IS NULL
AND death_date IS NULL;

-- 1.3 Recent cases view (last 30 days)
CREATE OR REPLACE VIEW surveillance.v_recent_cases AS
SELECT *
FROM surveillance.v_case_details
WHERE report_date > CURRENT_DATE - INTERVAL '30 days';

-- ============================================================================
-- SECTION 2: AGGREGATE VIEWS
-- ============================================================================

-- 2.1 Cases by disease and district
CREATE OR REPLACE VIEW surveillance.v_cases_by_disease_district AS
SELECT 
    d.disease_code,
    d.disease_name,
    dist.district_code,
    dist.district_name,
    COUNT(*) AS total_cases,
    COUNT(*) FILTER (WHERE c.case_status = 'confirmed') AS confirmed_cases,
    COUNT(*) FILTER (WHERE c.case_status = 'suspected') AS suspected_cases,
    COUNT(*) FILTER (WHERE c.case_status = 'deceased') AS deaths,
    COUNT(*) FILTER (WHERE c.case_status = 'recovered') AS recovered,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE c.case_status = 'deceased') / 
        NULLIF(COUNT(*) FILTER (WHERE c.case_status IN ('confirmed', 'deceased', 'recovered')), 0),
        2
    ) AS case_fatality_rate,
    MIN(c.onset_date) AS first_case_date,
    MAX(c.onset_date) AS last_case_date
FROM surveillance.cases c
JOIN surveillance.diseases d ON c.disease_id = d.disease_id
JOIN surveillance.districts dist ON c.district_id = dist.district_id
WHERE c.report_date > CURRENT_DATE - INTERVAL '90 days'
GROUP BY d.disease_code, d.disease_name, dist.district_code, dist.district_name;

-- 2.2 Daily case summary
CREATE OR REPLACE VIEW surveillance.v_daily_summary AS
SELECT 
    c.report_date,
    COUNT(*) AS new_cases,
    COUNT(DISTINCT c.disease_id) AS diseases_reported,
    COUNT(DISTINCT c.district_id) AS districts_affected,
    COUNT(*) FILTER (WHERE c.case_status = 'confirmed') AS confirmed,
    COUNT(*) FILTER (WHERE c.case_status = 'suspected') AS suspected,
    COUNT(*) FILTER (WHERE c.case_status = 'deceased') AS deaths,
    COUNT(*) FILTER (WHERE c.hospitalized) AS hospitalized
FROM surveillance.cases c
WHERE c.report_date > CURRENT_DATE - INTERVAL '30 days'
GROUP BY c.report_date
ORDER BY c.report_date DESC;

-- 2.3 Disease ranking
CREATE OR REPLACE VIEW surveillance.v_disease_ranking AS
WITH disease_stats AS (
    SELECT 
        d.disease_id,
        d.disease_code,
        d.disease_name,
        d.is_immediately_notifiable,
        COUNT(*) AS total_cases_30d,
        COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - INTERVAL '7 days') AS cases_last_7d,
        COUNT(*) FILTER (WHERE c.case_status = 'deceased') AS deaths_30d,
        COUNT(DISTINCT c.district_id) AS districts_affected
    FROM surveillance.diseases d
    LEFT JOIN surveillance.cases c ON d.disease_id = c.disease_id
        AND c.report_date > CURRENT_DATE - INTERVAL '30 days'
    GROUP BY d.disease_id, d.disease_code, d.disease_name, d.is_immediately_notifiable
)
SELECT 
    *,
    RANK() OVER (ORDER BY total_cases_30d DESC) AS case_rank,
    ROUND(100.0 * deaths_30d / NULLIF(total_cases_30d, 0), 2) AS cfr_30d
FROM disease_stats
WHERE total_cases_30d > 0
ORDER BY total_cases_30d DESC;

-- ============================================================================
-- SECTION 3: OUTBREAK VIEWS
-- ============================================================================

-- 3.1 Active outbreaks view
CREATE OR REPLACE VIEW surveillance.v_active_outbreaks AS
SELECT 
    o.outbreak_id,
    o.outbreak_code,
    o.declaration_date,
    o.first_case_date,
    o.response_status,
    o.alert_level,
    o.total_cases,
    o.confirmed_cases,
    o.deaths,
    ROUND(100.0 * o.deaths / NULLIF(o.confirmed_cases, 0), 2) AS case_fatality_rate,
    CURRENT_DATE - o.first_case_date AS outbreak_duration_days,
    d.disease_code,
    d.disease_name,
    dist.district_code,
    dist.district_name,
    r.region_name,
    o.situation_summary,
    o.containment_measures
FROM surveillance.outbreaks o
JOIN surveillance.diseases d ON o.disease_id = d.disease_id
JOIN surveillance.districts dist ON o.district_id = dist.district_id
JOIN surveillance.regions r ON dist.region_id = r.region_id
WHERE o.end_date IS NULL
AND o.response_status IN ('active', 'ongoing')
ORDER BY o.declaration_date DESC;

-- 3.2 Outbreak history
CREATE OR REPLACE VIEW surveillance.v_outbreak_history AS
SELECT 
    o.*,
    d.disease_code,
    d.disease_name,
    dist.district_name,
    o.end_date - o.first_case_date AS total_duration_days,
    ROUND(100.0 * o.deaths / NULLIF(o.confirmed_cases, 0), 2) AS final_cfr
FROM surveillance.outbreaks o
JOIN surveillance.diseases d ON o.disease_id = d.disease_id
JOIN surveillance.districts dist ON o.district_id = dist.district_id
ORDER BY o.declaration_date DESC;

-- ============================================================================
-- SECTION 4: ALERTS VIEW
-- ============================================================================

-- 4.1 Active alerts
CREATE OR REPLACE VIEW surveillance.v_active_alerts AS
SELECT 
    a.alert_id,
    a.alert_code,
    a.alert_level,
    a.alert_status,
    a.alert_type,
    a.title,
    a.description,
    a.detection_date,
    a.current_value,
    a.threshold_value,
    a.created_at,
    d.disease_code,
    d.disease_name,
    dist.district_code,
    dist.district_name,
    r.region_name,
    CURRENT_DATE - a.detection_date AS days_active
FROM surveillance.alerts a
LEFT JOIN surveillance.diseases d ON a.disease_id = d.disease_id
LEFT JOIN surveillance.districts dist ON a.district_id = dist.district_id
LEFT JOIN surveillance.regions r ON dist.region_id = r.region_id
WHERE a.alert_status = 'active'
ORDER BY 
    CASE a.alert_level 
        WHEN 'emergency' THEN 1
        WHEN 'outbreak' THEN 2
        WHEN 'alert' THEN 3
        ELSE 4
    END,
    a.created_at DESC;

-- ============================================================================
-- SECTION 5: LABORATORY VIEWS
-- ============================================================================

-- 5.1 Lab test results
CREATE OR REPLACE VIEW surveillance.v_lab_results AS
SELECT 
    lt.test_id,
    lt.test_code,
    lt.test_name,
    lt.test_date,
    lt.result,
    lt.result_value,
    lt.result_date,
    lt.turnaround_hours,
    s.specimen_code,
    s.specimen_type,
    s.collection_date,
    c.case_number,
    c.case_status,
    d.disease_code,
    d.disease_name,
    p.patient_code,
    p.first_name || ' ' || p.last_name AS patient_name,
    dist.district_name,
    f.facility_name AS testing_facility
FROM surveillance.lab_tests lt
JOIN surveillance.specimens s ON lt.specimen_id = s.specimen_id
JOIN surveillance.cases c ON s.case_id = c.case_id
JOIN surveillance.patients p ON c.patient_id = p.patient_id
JOIN surveillance.diseases d ON c.disease_id = d.disease_id
JOIN surveillance.districts dist ON c.district_id = dist.district_id
LEFT JOIN surveillance.health_facilities f ON lt.testing_facility_id = f.facility_id;

-- 5.2 Pending tests
CREATE OR REPLACE VIEW surveillance.v_pending_tests AS
SELECT 
    s.specimen_id,
    s.specimen_code,
    s.specimen_type,
    s.collection_date,
    s.status AS specimen_status,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - s.collection_date))/3600 AS hours_since_collection,
    c.case_number,
    d.disease_code,
    d.disease_name,
    p.patient_code,
    p.first_name || ' ' || p.last_name AS patient_name,
    dist.district_name
FROM surveillance.specimens s
JOIN surveillance.cases c ON s.case_id = c.case_id
JOIN surveillance.patients p ON c.patient_id = p.patient_id
JOIN surveillance.diseases d ON c.disease_id = d.disease_id
JOIN surveillance.districts dist ON c.district_id = dist.district_id
WHERE s.status IN ('collected', 'in_transit', 'received')
AND NOT EXISTS (
    SELECT 1 FROM surveillance.lab_tests lt 
    WHERE lt.specimen_id = s.specimen_id AND lt.result IS NOT NULL
)
ORDER BY s.collection_date;

-- ============================================================================
-- SECTION 6: CONTACT TRACING VIEWS
-- ============================================================================

-- 6.1 Contacts requiring follow-up
CREATE OR REPLACE VIEW surveillance.v_contacts_pending_followup AS
SELECT 
    cc.contact_id,
    cc.contact_name,
    cc.phone,
    cc.relationship,
    cc.exposure_date,
    cc.quarantine_start_date,
    cc.quarantine_end_date,
    cc.follow_up_status,
    cc.last_follow_up_date,
    CURRENT_DATE - cc.exposure_date AS days_since_exposure,
    cc.quarantine_end_date - CURRENT_DATE AS days_remaining_quarantine,
    c.case_number AS source_case,
    d.disease_code,
    d.disease_name,
    dist.district_name
FROM surveillance.case_contacts cc
JOIN surveillance.cases c ON cc.case_id = c.case_id
JOIN surveillance.diseases d ON c.disease_id = d.disease_id
LEFT JOIN surveillance.districts dist ON cc.district_id = dist.district_id
WHERE cc.follow_up_status IN ('pending', 'under_surveillance')
AND cc.quarantine_end_date >= CURRENT_DATE
AND NOT cc.developed_symptoms
ORDER BY cc.exposure_date DESC;

-- ============================================================================
-- SECTION 7: MATERIALIZED VIEWS FOR DASHBOARDS
-- ============================================================================

-- 7.1 National dashboard statistics (refresh periodically)
CREATE MATERIALIZED VIEW surveillance.mv_national_dashboard AS
SELECT 
    CURRENT_DATE AS snapshot_date,
    -- Overall stats
    (SELECT COUNT(*) FROM surveillance.cases WHERE report_date > CURRENT_DATE - INTERVAL '30 days') AS cases_30d,
    (SELECT COUNT(*) FROM surveillance.cases WHERE report_date > CURRENT_DATE - INTERVAL '7 days') AS cases_7d,
    (SELECT COUNT(*) FROM surveillance.cases WHERE report_date = CURRENT_DATE) AS cases_today,
    (SELECT COUNT(*) FROM surveillance.cases WHERE report_date > CURRENT_DATE - INTERVAL '30 days' 
     AND case_status = 'confirmed') AS confirmed_30d,
    (SELECT COUNT(*) FROM surveillance.cases WHERE report_date > CURRENT_DATE - INTERVAL '30 days' 
     AND case_status = 'deceased') AS deaths_30d,
    -- Active outbreaks
    (SELECT COUNT(*) FROM surveillance.outbreaks WHERE end_date IS NULL) AS active_outbreaks,
    -- Active alerts
    (SELECT COUNT(*) FROM surveillance.alerts WHERE alert_status = 'active') AS active_alerts,
    (SELECT COUNT(*) FROM surveillance.alerts WHERE alert_status = 'active' 
     AND alert_level IN ('emergency', 'outbreak')) AS critical_alerts,
    -- Lab stats
    (SELECT COUNT(*) FROM surveillance.specimens WHERE status = 'collected') AS pending_specimens,
    (SELECT ROUND(AVG(turnaround_hours), 1) FROM surveillance.lab_tests 
     WHERE result_date > CURRENT_DATE - INTERVAL '7 days') AS avg_lab_turnaround_hrs,
    -- Geographic spread
    (SELECT COUNT(DISTINCT district_id) FROM surveillance.cases 
     WHERE report_date > CURRENT_DATE - INTERVAL '7 days') AS districts_reporting_7d
WITH DATA;

CREATE UNIQUE INDEX ON surveillance.mv_national_dashboard (snapshot_date);

-- 7.2 Disease summary (refresh hourly)
CREATE MATERIALIZED VIEW surveillance.mv_disease_summary AS
SELECT 
    d.disease_id,
    d.disease_code,
    d.disease_name,
    d.is_immediately_notifiable,
    d.outbreak_threshold,
    dc.category_name,
    COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - INTERVAL '24 hours') AS cases_24h,
    COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - INTERVAL '7 days') AS cases_7d,
    COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - INTERVAL '30 days') AS cases_30d,
    COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - INTERVAL '30 days' 
                     AND c.case_status = 'deceased') AS deaths_30d,
    COUNT(DISTINCT c.district_id) FILTER (WHERE c.report_date > CURRENT_DATE - INTERVAL '7 days') AS districts_7d,
    MAX(c.report_date) AS last_case_date,
    -- Trend calculation
    ROUND(100.0 * (
        COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - INTERVAL '7 days') -
        COUNT(*) FILTER (WHERE c.report_date BETWEEN CURRENT_DATE - INTERVAL '14 days' 
                         AND CURRENT_DATE - INTERVAL '7 days')
    ) / NULLIF(COUNT(*) FILTER (WHERE c.report_date BETWEEN CURRENT_DATE - INTERVAL '14 days' 
                                 AND CURRENT_DATE - INTERVAL '7 days'), 0), 1) AS trend_pct
FROM surveillance.diseases d
LEFT JOIN surveillance.disease_categories dc ON d.category_id = dc.category_id
LEFT JOIN surveillance.cases c ON d.disease_id = c.disease_id
GROUP BY d.disease_id, d.disease_code, d.disease_name, d.is_immediately_notifiable,
         d.outbreak_threshold, dc.category_name
WITH DATA;

CREATE UNIQUE INDEX ON surveillance.mv_disease_summary (disease_id);

-- 7.3 District surveillance matrix
CREATE MATERIALIZED VIEW surveillance.mv_district_matrix AS
SELECT 
    dist.district_id,
    dist.district_code,
    dist.district_name,
    r.region_name,
    dist.population,
    COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - INTERVAL '7 days') AS cases_7d,
    COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - INTERVAL '30 days') AS cases_30d,
    COUNT(DISTINCT c.disease_id) FILTER (WHERE c.report_date > CURRENT_DATE - INTERVAL '30 days') AS diseases_30d,
    -- Incidence rate per 100,000
    ROUND(100000.0 * COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - INTERVAL '30 days') / 
          NULLIF(dist.population, 0), 2) AS incidence_rate_30d,
    -- Active outbreaks in district
    (SELECT COUNT(*) FROM surveillance.outbreaks o WHERE o.district_id = dist.district_id AND o.end_date IS NULL) AS active_outbreaks,
    -- Facilities reporting
    (SELECT COUNT(DISTINCT f.facility_id) FROM surveillance.health_facilities f 
     JOIN surveillance.cases c2 ON f.facility_id = c2.reporting_facility_id
     WHERE f.district_id = dist.district_id AND c2.report_date > CURRENT_DATE - INTERVAL '7 days') AS facilities_reporting,
    -- Top disease
    (SELECT d.disease_code FROM surveillance.diseases d 
     JOIN surveillance.cases c2 ON d.disease_id = c2.disease_id
     WHERE c2.district_id = dist.district_id AND c2.report_date > CURRENT_DATE - INTERVAL '30 days'
     GROUP BY d.disease_code ORDER BY COUNT(*) DESC LIMIT 1) AS top_disease_30d
FROM surveillance.districts dist
JOIN surveillance.regions r ON dist.region_id = r.region_id
LEFT JOIN surveillance.cases c ON dist.district_id = c.district_id
GROUP BY dist.district_id, dist.district_code, dist.district_name, r.region_name, dist.population
WITH DATA;

CREATE UNIQUE INDEX ON surveillance.mv_district_matrix (district_id);

-- ============================================================================
-- SECTION 8: REFRESH FUNCTIONS
-- ============================================================================

-- 8.1 Refresh all materialized views
CREATE OR REPLACE PROCEDURE surveillance.refresh_dashboard_views()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY surveillance.mv_national_dashboard;
    REFRESH MATERIALIZED VIEW CONCURRENTLY surveillance.mv_disease_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY surveillance.mv_district_matrix;
    RAISE NOTICE 'All dashboard views refreshed at %', CURRENT_TIMESTAMP;
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_view_count INTEGER;
    v_matview_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_view_count
    FROM information_schema.views
    WHERE table_schema = 'surveillance';
    
    SELECT COUNT(*) INTO v_matview_count
    FROM pg_matviews
    WHERE schemaname = 'surveillance';
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'DATABASE VIEWS CREATED SUCCESSFULLY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Standard Views: %', v_view_count;
    RAISE NOTICE 'Materialized Views: %', v_matview_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Case Views:';
    RAISE NOTICE '  - v_case_details           (comprehensive case view)';
    RAISE NOTICE '  - v_active_cases           (active cases only)';
    RAISE NOTICE '  - v_recent_cases           (last 30 days)';
    RAISE NOTICE '';
    RAISE NOTICE 'Aggregate Views:';
    RAISE NOTICE '  - v_cases_by_disease_district';
    RAISE NOTICE '  - v_daily_summary';
    RAISE NOTICE '  - v_disease_ranking';
    RAISE NOTICE '';
    RAISE NOTICE 'Outbreak & Alert Views:';
    RAISE NOTICE '  - v_active_outbreaks';
    RAISE NOTICE '  - v_outbreak_history';
    RAISE NOTICE '  - v_active_alerts';
    RAISE NOTICE '';
    RAISE NOTICE 'Lab & Contact Views:';
    RAISE NOTICE '  - v_lab_results';
    RAISE NOTICE '  - v_pending_tests';
    RAISE NOTICE '  - v_contacts_pending_followup';
    RAISE NOTICE '';
    RAISE NOTICE 'Materialized Dashboard Views:';
    RAISE NOTICE '  - mv_national_dashboard';
    RAISE NOTICE '  - mv_disease_summary';
    RAISE NOTICE '  - mv_district_matrix';
    RAISE NOTICE '==========================================';
END $$;
