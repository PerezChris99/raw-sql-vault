-- ============================================================================
-- 🏥 HEALTHCARE OUTBREAK DETECTOR - API QUERIES
-- ============================================================================
-- File: 07_api_queries.sql
-- Purpose: JSONB functions optimized for REST API responses
-- Database: PostgreSQL 14+
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- SECTION 1: CASE API FUNCTIONS
-- ============================================================================

-- 1.1 Get case by ID (full details)
CREATE OR REPLACE FUNCTION surveillance.api_get_case(p_case_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'case_id', c.case_id,
        'case_number', c.case_number,
        'status', c.case_status,
        'severity', c.severity,
        'hospitalized', c.hospitalized,
        'onset_date', c.onset_date,
        'report_date', c.report_date,
        'symptoms', c.symptoms,
        'verified', c.verified,
        'patient', jsonb_build_object(
            'patient_id', p.patient_id,
            'patient_code', p.patient_code,
            'name', p.first_name || ' ' || p.last_name,
            'age', p.age_years,
            'gender', p.gender
        ),
        'disease', jsonb_build_object(
            'disease_id', d.disease_id,
            'code', d.disease_code,
            'name', d.disease_name,
            'icd10', d.icd10_code
        ),
        'location', jsonb_build_object(
            'district', dist.district_name,
            'district_code', dist.district_code,
            'region', r.region_name
        ),
        'lab_results', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'test_id', lt.test_id,
                'test_name', lt.test_name,
                'result', lt.result,
                'result_date', lt.result_date
            )), '[]'::jsonb)
            FROM surveillance.specimens s
            JOIN surveillance.lab_tests lt ON s.specimen_id = lt.specimen_id
            WHERE s.case_id = c.case_id
        ),
        'contacts_count', (
            SELECT COUNT(*) FROM surveillance.case_contacts cc WHERE cc.case_id = c.case_id
        ),
        'created_at', c.created_at,
        'updated_at', c.updated_at
    ) INTO v_result
    FROM surveillance.cases c
    JOIN surveillance.patients p ON c.patient_id = p.patient_id
    JOIN surveillance.diseases d ON c.disease_id = d.disease_id
    JOIN surveillance.districts dist ON c.district_id = dist.district_id
    JOIN surveillance.regions r ON dist.region_id = r.region_id
    WHERE c.case_id = p_case_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'Case not found'));
END;
$$;

-- 1.2 List cases with filters
CREATE OR REPLACE FUNCTION surveillance.api_list_cases(
    p_disease_code VARCHAR DEFAULT NULL,
    p_district_code VARCHAR DEFAULT NULL,
    p_status VARCHAR DEFAULT NULL,
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_page INTEGER DEFAULT 1,
    p_page_size INTEGER DEFAULT 20
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_offset INTEGER;
    v_total INTEGER;
    v_cases JSONB;
BEGIN
    v_offset := (p_page - 1) * p_page_size;
    
    -- Get total count
    SELECT COUNT(*) INTO v_total
    FROM surveillance.cases c
    JOIN surveillance.diseases d ON c.disease_id = d.disease_id
    JOIN surveillance.districts dist ON c.district_id = dist.district_id
    WHERE (p_disease_code IS NULL OR d.disease_code = p_disease_code)
    AND (p_district_code IS NULL OR dist.district_code = p_district_code)
    AND (p_status IS NULL OR c.case_status::TEXT = p_status)
    AND (p_from_date IS NULL OR c.report_date >= p_from_date)
    AND (p_to_date IS NULL OR c.report_date <= p_to_date);
    
    -- Get paginated results
    SELECT COALESCE(jsonb_agg(cases_data ORDER BY report_date DESC), '[]'::jsonb)
    INTO v_cases
    FROM (
        SELECT jsonb_build_object(
            'case_id', c.case_id,
            'case_number', c.case_number,
            'status', c.case_status,
            'severity', c.severity,
            'report_date', c.report_date,
            'disease_code', d.disease_code,
            'disease_name', d.disease_name,
            'district', dist.district_name,
            'patient_name', p.first_name || ' ' || LEFT(p.last_name, 1) || '.',
            'age', p.age_years,
            'gender', p.gender
        ) AS cases_data,
        c.report_date
        FROM surveillance.cases c
        JOIN surveillance.patients p ON c.patient_id = p.patient_id
        JOIN surveillance.diseases d ON c.disease_id = d.disease_id
        JOIN surveillance.districts dist ON c.district_id = dist.district_id
        WHERE (p_disease_code IS NULL OR d.disease_code = p_disease_code)
        AND (p_district_code IS NULL OR dist.district_code = p_district_code)
        AND (p_status IS NULL OR c.case_status::TEXT = p_status)
        AND (p_from_date IS NULL OR c.report_date >= p_from_date)
        AND (p_to_date IS NULL OR c.report_date <= p_to_date)
        ORDER BY c.report_date DESC
        LIMIT p_page_size OFFSET v_offset
    ) sub;
    
    RETURN jsonb_build_object(
        'data', v_cases,
        'pagination', jsonb_build_object(
            'page', p_page,
            'page_size', p_page_size,
            'total_items', v_total,
            'total_pages', CEIL(v_total::NUMERIC / p_page_size)
        )
    );
END;
$$;

-- ============================================================================
-- SECTION 2: DISEASE API FUNCTIONS
-- ============================================================================

-- 2.1 Get disease summary
CREATE OR REPLACE FUNCTION surveillance.api_get_disease_summary(p_disease_code VARCHAR DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF p_disease_code IS NOT NULL THEN
        RETURN (
            SELECT jsonb_build_object(
                'disease', jsonb_build_object(
                    'disease_id', d.disease_id,
                    'code', d.disease_code,
                    'name', d.disease_name,
                    'icd10', d.icd10_code,
                    'category', dc.category_name,
                    'transmission_mode', d.transmission_mode,
                    'outbreak_threshold', d.outbreak_threshold,
                    'notifiable', d.is_immediately_notifiable
                ),
                'statistics', jsonb_build_object(
                    'cases_7d', COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - 7),
                    'cases_30d', COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - 30),
                    'deaths_30d', COUNT(*) FILTER (WHERE c.case_status = 'deceased' AND c.report_date > CURRENT_DATE - 30),
                    'confirmed_30d', COUNT(*) FILTER (WHERE c.case_status = 'confirmed' AND c.report_date > CURRENT_DATE - 30),
                    'districts_affected', COUNT(DISTINCT c.district_id) FILTER (WHERE c.report_date > CURRENT_DATE - 30)
                ),
                'by_district', (
                    SELECT COALESCE(jsonb_agg(jsonb_build_object(
                        'district', dist.district_name,
                        'cases', sub.cnt
                    ) ORDER BY sub.cnt DESC), '[]'::jsonb)
                    FROM (
                        SELECT c2.district_id, COUNT(*) AS cnt
                        FROM surveillance.cases c2
                        WHERE c2.disease_id = d.disease_id
                        AND c2.report_date > CURRENT_DATE - 30
                        GROUP BY c2.district_id
                    ) sub
                    JOIN surveillance.districts dist ON sub.district_id = dist.district_id
                )
            )
            FROM surveillance.diseases d
            LEFT JOIN surveillance.disease_categories dc ON d.category_id = dc.category_id
            LEFT JOIN surveillance.cases c ON d.disease_id = c.disease_id AND c.report_date > CURRENT_DATE - 90
            WHERE d.disease_code = p_disease_code
            GROUP BY d.disease_id, d.disease_code, d.disease_name, d.icd10_code, dc.category_name,
                     d.transmission_mode, d.outbreak_threshold, d.is_immediately_notifiable
        );
    ELSE
        RETURN (
            SELECT jsonb_build_object(
                'diseases', COALESCE(jsonb_agg(jsonb_build_object(
                    'disease_code', d.disease_code,
                    'disease_name', d.disease_name,
                    'cases_7d', COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - 7),
                    'cases_30d', COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - 30),
                    'trend', CASE 
                        WHEN COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - 7) >
                             COUNT(*) FILTER (WHERE c.report_date BETWEEN CURRENT_DATE - 14 AND CURRENT_DATE - 7)
                        THEN 'increasing'
                        WHEN COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - 7) <
                             COUNT(*) FILTER (WHERE c.report_date BETWEEN CURRENT_DATE - 14 AND CURRENT_DATE - 7)
                        THEN 'decreasing'
                        ELSE 'stable'
                    END
                ) ORDER BY COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - 30) DESC), '[]'::jsonb)
            )
            FROM surveillance.diseases d
            LEFT JOIN surveillance.cases c ON d.disease_id = c.disease_id
            GROUP BY d.disease_id, d.disease_code, d.disease_name
            HAVING COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - 30) > 0
        );
    END IF;
END;
$$;

-- ============================================================================
-- SECTION 3: OUTBREAK API FUNCTIONS
-- ============================================================================

-- 3.1 Get active outbreaks
CREATE OR REPLACE FUNCTION surveillance.api_get_active_outbreaks()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'outbreaks', COALESCE(jsonb_agg(jsonb_build_object(
                'outbreak_id', o.outbreak_id,
                'outbreak_code', o.outbreak_code,
                'disease', d.disease_name,
                'disease_code', d.disease_code,
                'district', dist.district_name,
                'region', r.region_name,
                'declaration_date', o.declaration_date,
                'duration_days', CURRENT_DATE - o.first_case_date,
                'total_cases', o.total_cases,
                'confirmed_cases', o.confirmed_cases,
                'deaths', o.deaths,
                'cfr', ROUND(100.0 * o.deaths / NULLIF(o.confirmed_cases, 0), 1),
                'alert_level', o.alert_level,
                'response_status', o.response_status
            ) ORDER BY o.declaration_date DESC), '[]'::jsonb),
            'count', COUNT(*),
            'timestamp', CURRENT_TIMESTAMP
        )
        FROM surveillance.outbreaks o
        JOIN surveillance.diseases d ON o.disease_id = d.disease_id
        JOIN surveillance.districts dist ON o.district_id = dist.district_id
        JOIN surveillance.regions r ON dist.region_id = r.region_id
        WHERE o.end_date IS NULL AND o.response_status != 'resolved'
    );
END;
$$;

-- 3.2 Get outbreak details
CREATE OR REPLACE FUNCTION surveillance.api_get_outbreak(p_outbreak_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'outbreak', jsonb_build_object(
                'outbreak_id', o.outbreak_id,
                'outbreak_code', o.outbreak_code,
                'disease_code', d.disease_code,
                'disease_name', d.disease_name,
                'district', dist.district_name,
                'region', r.region_name,
                'declaration_date', o.declaration_date,
                'first_case_date', o.first_case_date,
                'duration_days', CURRENT_DATE - o.first_case_date,
                'total_cases', o.total_cases,
                'confirmed_cases', o.confirmed_cases,
                'deaths', o.deaths,
                'cfr', ROUND(100.0 * o.deaths / NULLIF(o.confirmed_cases, 0), 1),
                'alert_level', o.alert_level,
                'response_status', o.response_status,
                'situation_summary', o.situation_summary,
                'containment_measures', o.containment_measures
            ),
            'epidemic_curve', (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'date', sub.report_date,
                    'cases', sub.daily_cases,
                    'cumulative', SUM(sub.daily_cases) OVER (ORDER BY sub.report_date)
                ) ORDER BY sub.report_date), '[]'::jsonb)
                FROM (
                    SELECT c.report_date, COUNT(*) AS daily_cases
                    FROM surveillance.cases c
                    WHERE c.disease_id = o.disease_id 
                    AND c.district_id = o.district_id
                    AND c.report_date >= o.first_case_date
                    GROUP BY c.report_date
                ) sub
            ),
            'by_age_group', (
                SELECT jsonb_build_object(
                    'under_5', COUNT(*) FILTER (WHERE p.age_years < 5),
                    '5_to_14', COUNT(*) FILTER (WHERE p.age_years BETWEEN 5 AND 14),
                    '15_to_49', COUNT(*) FILTER (WHERE p.age_years BETWEEN 15 AND 49),
                    '50_plus', COUNT(*) FILTER (WHERE p.age_years >= 50)
                )
                FROM surveillance.cases c
                JOIN surveillance.patients p ON c.patient_id = p.patient_id
                WHERE c.disease_id = o.disease_id 
                AND c.district_id = o.district_id
                AND c.report_date >= o.first_case_date
            )
        )
        FROM surveillance.outbreaks o
        JOIN surveillance.diseases d ON o.disease_id = d.disease_id
        JOIN surveillance.districts dist ON o.district_id = dist.district_id
        JOIN surveillance.regions r ON dist.region_id = r.region_id
        WHERE o.outbreak_id = p_outbreak_id
    );
END;
$$;

-- ============================================================================
-- SECTION 4: DASHBOARD API FUNCTIONS
-- ============================================================================

-- 4.1 National dashboard
CREATE OR REPLACE FUNCTION surveillance.api_get_dashboard()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN jsonb_build_object(
        'summary', jsonb_build_object(
            'cases_today', (SELECT COUNT(*) FROM surveillance.cases WHERE report_date = CURRENT_DATE),
            'cases_7d', (SELECT COUNT(*) FROM surveillance.cases WHERE report_date > CURRENT_DATE - 7),
            'cases_30d', (SELECT COUNT(*) FROM surveillance.cases WHERE report_date > CURRENT_DATE - 30),
            'deaths_30d', (SELECT COUNT(*) FROM surveillance.cases WHERE report_date > CURRENT_DATE - 30 AND case_status = 'deceased'),
            'active_outbreaks', (SELECT COUNT(*) FROM surveillance.outbreaks WHERE end_date IS NULL),
            'active_alerts', (SELECT COUNT(*) FROM surveillance.alerts WHERE alert_status = 'active'),
            'districts_reporting', (SELECT COUNT(DISTINCT district_id) FROM surveillance.cases WHERE report_date > CURRENT_DATE - 7)
        ),
        'top_diseases', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'disease_code', d.disease_code,
                'disease_name', d.disease_name,
                'cases', sub.cnt,
                'deaths', sub.deaths
            ) ORDER BY sub.cnt DESC), '[]'::jsonb)
            FROM (
                SELECT disease_id, COUNT(*) AS cnt,
                       COUNT(*) FILTER (WHERE case_status = 'deceased') AS deaths
                FROM surveillance.cases
                WHERE report_date > CURRENT_DATE - 30
                GROUP BY disease_id
                ORDER BY cnt DESC
                LIMIT 5
            ) sub
            JOIN surveillance.diseases d ON sub.disease_id = d.disease_id
        ),
        'alerts', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'alert_code', a.alert_code,
                'title', a.title,
                'level', a.alert_level,
                'disease', d.disease_name,
                'district', dist.district_name,
                'detection_date', a.detection_date
            ) ORDER BY a.created_at DESC), '[]'::jsonb)
            FROM surveillance.alerts a
            LEFT JOIN surveillance.diseases d ON a.disease_id = d.disease_id
            LEFT JOIN surveillance.districts dist ON a.district_id = dist.district_id
            WHERE a.alert_status = 'active'
            LIMIT 10
        ),
        'trend_7d', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'date', report_date,
                'cases', cnt
            ) ORDER BY report_date), '[]'::jsonb)
            FROM (
                SELECT report_date, COUNT(*) AS cnt
                FROM surveillance.cases
                WHERE report_date > CURRENT_DATE - 7
                GROUP BY report_date
            ) sub
        ),
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$$;

-- 4.2 District dashboard
CREATE OR REPLACE FUNCTION surveillance.api_get_district_dashboard(p_district_code VARCHAR)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_district_id INTEGER;
BEGIN
    SELECT district_id INTO v_district_id FROM surveillance.districts WHERE district_code = p_district_code;
    
    IF v_district_id IS NULL THEN
        RETURN jsonb_build_object('error', 'District not found');
    END IF;
    
    RETURN (
        SELECT jsonb_build_object(
            'district', jsonb_build_object(
                'district_id', dist.district_id,
                'code', dist.district_code,
                'name', dist.district_name,
                'region', r.region_name,
                'population', dist.population
            ),
            'summary', jsonb_build_object(
                'cases_7d', COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - 7),
                'cases_30d', COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - 30),
                'deaths_30d', COUNT(*) FILTER (WHERE c.case_status = 'deceased' AND c.report_date > CURRENT_DATE - 30),
                'incidence_rate', ROUND(100000.0 * COUNT(*) FILTER (WHERE c.report_date > CURRENT_DATE - 30) / NULLIF(dist.population, 0), 2)
            ),
            'diseases', (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'disease_code', d.disease_code,
                    'disease_name', d.disease_name,
                    'cases_30d', sub.cnt
                ) ORDER BY sub.cnt DESC), '[]'::jsonb)
                FROM (
                    SELECT c2.disease_id, COUNT(*) AS cnt
                    FROM surveillance.cases c2
                    WHERE c2.district_id = v_district_id
                    AND c2.report_date > CURRENT_DATE - 30
                    GROUP BY c2.disease_id
                ) sub
                JOIN surveillance.diseases d ON sub.disease_id = d.disease_id
            ),
            'facilities', (
                SELECT COALESCE(jsonb_agg(jsonb_build_object(
                    'facility_code', f.facility_code,
                    'facility_name', f.facility_name,
                    'facility_type', f.facility_type,
                    'cases_reported', COALESCE(sub.cnt, 0)
                )), '[]'::jsonb)
                FROM surveillance.health_facilities f
                LEFT JOIN (
                    SELECT reporting_facility_id, COUNT(*) AS cnt
                    FROM surveillance.cases
                    WHERE district_id = v_district_id
                    AND report_date > CURRENT_DATE - 30
                    GROUP BY reporting_facility_id
                ) sub ON f.facility_id = sub.reporting_facility_id
                WHERE f.district_id = v_district_id
            ),
            'timestamp', CURRENT_TIMESTAMP
        )
        FROM surveillance.districts dist
        JOIN surveillance.regions r ON dist.region_id = r.region_id
        LEFT JOIN surveillance.cases c ON dist.district_id = c.district_id
        WHERE dist.district_id = v_district_id
        GROUP BY dist.district_id, dist.district_code, dist.district_name, r.region_name, dist.population
    );
END;
$$;

-- ============================================================================
-- SECTION 5: ALERT API FUNCTIONS
-- ============================================================================

-- 5.1 Get active alerts
CREATE OR REPLACE FUNCTION surveillance.api_get_alerts(
    p_level VARCHAR DEFAULT NULL,
    p_district_code VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'alerts', COALESCE(jsonb_agg(jsonb_build_object(
                'alert_id', a.alert_id,
                'alert_code', a.alert_code,
                'level', a.alert_level,
                'type', a.alert_type,
                'title', a.title,
                'description', a.description,
                'disease', d.disease_name,
                'district', dist.district_name,
                'detection_date', a.detection_date,
                'current_value', a.current_value,
                'threshold_value', a.threshold_value,
                'days_active', CURRENT_DATE - a.detection_date
            ) ORDER BY 
                CASE a.alert_level WHEN 'emergency' THEN 1 WHEN 'outbreak' THEN 2 WHEN 'alert' THEN 3 ELSE 4 END,
                a.created_at DESC
            ), '[]'::jsonb),
            'by_level', jsonb_build_object(
                'emergency', COUNT(*) FILTER (WHERE a.alert_level = 'emergency'),
                'outbreak', COUNT(*) FILTER (WHERE a.alert_level = 'outbreak'),
                'alert', COUNT(*) FILTER (WHERE a.alert_level = 'alert'),
                'watch', COUNT(*) FILTER (WHERE a.alert_level = 'watch')
            ),
            'count', COUNT(*),
            'timestamp', CURRENT_TIMESTAMP
        )
        FROM surveillance.alerts a
        LEFT JOIN surveillance.diseases d ON a.disease_id = d.disease_id
        LEFT JOIN surveillance.districts dist ON a.district_id = dist.district_id
        WHERE a.alert_status = 'active'
        AND (p_level IS NULL OR a.alert_level::TEXT = p_level)
        AND (p_district_code IS NULL OR dist.district_code = p_district_code)
    );
END;
$$;

-- ============================================================================
-- SECTION 6: GEOGRAPHIC API
-- ============================================================================

-- 6.1 Get geographic data for mapping
CREATE OR REPLACE FUNCTION surveillance.api_get_map_data(
    p_disease_code VARCHAR DEFAULT NULL,
    p_days INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'districts', COALESCE(jsonb_agg(jsonb_build_object(
                'district_code', dist.district_code,
                'district_name', dist.district_name,
                'lat', dist.latitude,
                'lng', dist.longitude,
                'cases', COALESCE(sub.cases, 0),
                'deaths', COALESCE(sub.deaths, 0),
                'has_outbreak', EXISTS(
                    SELECT 1 FROM surveillance.outbreaks o 
                    WHERE o.district_id = dist.district_id AND o.end_date IS NULL
                ),
                'risk_level', CASE 
                    WHEN COALESCE(sub.cases, 0) = 0 THEN 'none'
                    WHEN COALESCE(sub.cases, 0) < 5 THEN 'low'
                    WHEN COALESCE(sub.cases, 0) < 20 THEN 'medium'
                    WHEN COALESCE(sub.cases, 0) < 50 THEN 'high'
                    ELSE 'critical'
                END
            )), '[]'::jsonb),
            'timestamp', CURRENT_TIMESTAMP
        )
        FROM surveillance.districts dist
        LEFT JOIN (
            SELECT c.district_id, 
                   COUNT(*) AS cases,
                   COUNT(*) FILTER (WHERE c.case_status = 'deceased') AS deaths
            FROM surveillance.cases c
            JOIN surveillance.diseases d ON c.disease_id = d.disease_id
            WHERE c.report_date > CURRENT_DATE - p_days
            AND (p_disease_code IS NULL OR d.disease_code = p_disease_code)
            GROUP BY c.district_id
        ) sub ON dist.district_id = sub.district_id
    );
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_api_func_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_api_func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'surveillance'
    AND p.proname LIKE 'api_%';
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'API FUNCTIONS CREATED SUCCESSFULLY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Total API Functions: %', v_api_func_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Case APIs:';
    RAISE NOTICE '  - api_get_case(case_id)';
    RAISE NOTICE '  - api_list_cases(filters, pagination)';
    RAISE NOTICE '';
    RAISE NOTICE 'Disease APIs:';
    RAISE NOTICE '  - api_get_disease_summary(disease_code?)';
    RAISE NOTICE '';
    RAISE NOTICE 'Outbreak APIs:';
    RAISE NOTICE '  - api_get_active_outbreaks()';
    RAISE NOTICE '  - api_get_outbreak(outbreak_id)';
    RAISE NOTICE '';
    RAISE NOTICE 'Dashboard APIs:';
    RAISE NOTICE '  - api_get_dashboard()';
    RAISE NOTICE '  - api_get_district_dashboard(district_code)';
    RAISE NOTICE '';
    RAISE NOTICE 'Alert APIs:';
    RAISE NOTICE '  - api_get_alerts(level?, district?)';
    RAISE NOTICE '';
    RAISE NOTICE 'Geographic APIs:';
    RAISE NOTICE '  - api_get_map_data(disease?, days?)';
    RAISE NOTICE '==========================================';
END $$;
