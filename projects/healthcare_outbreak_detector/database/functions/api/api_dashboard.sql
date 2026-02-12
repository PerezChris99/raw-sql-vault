-- ============================================================================
-- Function: api_dashboard.sql
-- Purpose: JSONB API endpoints for dashboard data
-- ============================================================================

SET search_path TO surveillance, public;

-- National dashboard
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
                FROM surveillance.cases WHERE report_date > CURRENT_DATE - 30
                GROUP BY disease_id ORDER BY cnt DESC LIMIT 5
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
            WHERE a.alert_status = 'active' LIMIT 10
        ),
        'trend_7d', (
            SELECT COALESCE(jsonb_agg(jsonb_build_object(
                'date', report_date, 'cases', cnt
            ) ORDER BY report_date), '[]'::jsonb)
            FROM (
                SELECT report_date, COUNT(*) AS cnt
                FROM surveillance.cases WHERE report_date > CURRENT_DATE - 7
                GROUP BY report_date
            ) sub
        ),
        'timestamp', CURRENT_TIMESTAMP
    );
END;
$$;

-- District dashboard
CREATE OR REPLACE FUNCTION surveillance.api_get_district_dashboard(p_district_code VARCHAR)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_district_id INTEGER;
BEGIN
    SELECT district_id INTO v_district_id 
    FROM surveillance.districts WHERE district_code = p_district_code;
    
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

COMMENT ON FUNCTION surveillance.api_get_dashboard IS 'National surveillance dashboard API endpoint';
COMMENT ON FUNCTION surveillance.api_get_district_dashboard IS 'District-level surveillance dashboard API endpoint';
