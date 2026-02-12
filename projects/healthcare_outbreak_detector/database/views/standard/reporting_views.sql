-- ============================================================================
-- Views: Standard Views
-- Purpose: Commonly accessed data views for reporting
-- ============================================================================

SET search_path TO surveillance, public;

-- Active cases view with full details
CREATE OR REPLACE VIEW surveillance.v_active_cases AS
SELECT 
    c.case_id,
    c.case_number,
    p.patient_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    p.age_years,
    p.gender,
    d.disease_name,
    d.disease_code,
    d.icd10_code,
    dc.category_name AS disease_category,
    dist.district_name,
    r.region_name,
    hf.facility_name AS reporting_facility,
    c.onset_date,
    c.report_date,
    c.case_status,
    c.severity,
    c.hospitalized,
    c.in_isolation,
    c.outcome,
    CURRENT_DATE - c.onset_date AS days_since_onset
FROM surveillance.cases c
JOIN surveillance.patients p ON c.patient_id = p.patient_id
JOIN surveillance.diseases d ON c.disease_id = d.disease_id
JOIN surveillance.disease_categories dc ON d.category_id = dc.category_id
JOIN surveillance.districts dist ON c.district_id = dist.district_id
JOIN surveillance.regions r ON dist.region_id = r.region_id
LEFT JOIN surveillance.health_facilities hf ON c.reporting_facility_id = hf.facility_id
WHERE c.case_status IN ('suspected', 'probable', 'confirmed')
  AND c.outcome IS NULL;

-- Weekly summary by district
CREATE OR REPLACE VIEW surveillance.v_weekly_summary AS
SELECT 
    DATE_TRUNC('week', c.report_date)::DATE AS week_start,
    dist.district_code,
    dist.district_name,
    d.disease_code,
    d.disease_name,
    COUNT(*) AS total_cases,
    COUNT(*) FILTER (WHERE c.case_status = 'confirmed') AS confirmed_cases,
    COUNT(*) FILTER (WHERE c.outcome = 'dead') AS deaths,
    ROUND(
        COUNT(*) FILTER (WHERE c.outcome = 'dead') * 100.0 / NULLIF(COUNT(*), 0), 2
    ) AS case_fatality_rate
FROM surveillance.cases c
JOIN surveillance.diseases d ON c.disease_id = d.disease_id
JOIN surveillance.districts dist ON c.district_id = dist.district_id
GROUP BY 1, dist.district_code, dist.district_name, d.disease_code, d.disease_name;

-- Active alerts view
CREATE OR REPLACE VIEW surveillance.v_active_alerts AS
SELECT 
    a.alert_id,
    a.alert_code,
    a.alert_level,
    a.alert_type,
    d.disease_name,
    d.disease_code,
    dist.district_name,
    r.region_name,
    a.title,
    a.description,
    a.detection_date,
    a.current_value,
    a.threshold_value,
    a.created_at,
    CURRENT_TIMESTAMP - a.created_at AS duration_open
FROM surveillance.alerts a
JOIN surveillance.diseases d ON a.disease_id = d.disease_id
JOIN surveillance.districts dist ON a.district_id = dist.district_id
JOIN surveillance.regions r ON dist.region_id = r.region_id
WHERE a.alert_status = 'active'
ORDER BY 
    CASE a.alert_level 
        WHEN 'emergency' THEN 1 
        WHEN 'alert' THEN 2 
        WHEN 'watch' THEN 3 
    END,
    a.created_at DESC;

-- Laboratory results view
CREATE OR REPLACE VIEW surveillance.v_lab_results AS
SELECT 
    s.specimen_id,
    s.specimen_number,
    c.case_number,
    p.first_name || ' ' || p.last_name AS patient_name,
    d.disease_name,
    s.specimen_type,
    s.collection_date,
    lr.test_name,
    lr.test_result,
    lr.result_value,
    lr.result_date,
    hf.facility_name AS testing_laboratory,
    lr.result_date - s.collection_date AS turnaround_days
FROM surveillance.specimens s
JOIN surveillance.cases c ON s.case_id = c.case_id
JOIN surveillance.patients p ON c.patient_id = p.patient_id
JOIN surveillance.diseases d ON c.disease_id = d.disease_id
JOIN surveillance.lab_results lr ON s.specimen_id = lr.specimen_id
LEFT JOIN surveillance.health_facilities hf ON s.testing_lab_id = hf.facility_id;

COMMENT ON VIEW surveillance.v_active_cases IS 'Currently active surveillance cases with full patient and location details';
COMMENT ON VIEW surveillance.v_weekly_summary IS 'Weekly epidemiological summary by district and disease';
COMMENT ON VIEW surveillance.v_active_alerts IS 'All currently active outbreak alerts sorted by severity';
COMMENT ON VIEW surveillance.v_lab_results IS 'Laboratory results with specimen and case details';
