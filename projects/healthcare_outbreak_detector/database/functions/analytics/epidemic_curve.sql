-- ============================================================================
-- Function: epidemic_curve.sql
-- Purpose: Generate epidemic curve data for outbreak visualization
-- ============================================================================

SET search_path TO surveillance, public;

CREATE OR REPLACE FUNCTION surveillance.get_epidemic_curve(
    p_disease_id INTEGER,
    p_district_id INTEGER DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_interval VARCHAR DEFAULT 'day'  -- day, week, month
)
RETURNS TABLE (
    period_start DATE,
    period_end DATE,
    new_cases BIGINT,
    confirmed_cases BIGINT,
    deaths BIGINT,
    cumulative_cases BIGINT,
    cumulative_deaths BIGINT
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_start DATE;
    v_end DATE;
BEGIN
    -- Determine date range
    v_start := COALESCE(p_start_date, (
        SELECT MIN(onset_date) FROM surveillance.cases 
        WHERE disease_id = p_disease_id 
        AND (p_district_id IS NULL OR district_id = p_district_id)
    ));
    v_end := COALESCE(p_end_date, CURRENT_DATE);
    
    RETURN QUERY
    WITH date_series AS (
        SELECT 
            d::DATE AS period_date,
            CASE p_interval
                WHEN 'week' THEN DATE_TRUNC('week', d)::DATE
                WHEN 'month' THEN DATE_TRUNC('month', d)::DATE
                ELSE d::DATE
            END AS period_bucket
        FROM generate_series(v_start, v_end, '1 day'::INTERVAL) d
    ),
    case_data AS (
        SELECT 
            CASE p_interval
                WHEN 'week' THEN DATE_TRUNC('week', c.onset_date)::DATE
                WHEN 'month' THEN DATE_TRUNC('month', c.onset_date)::DATE
                ELSE c.onset_date
            END AS period_bucket,
            COUNT(*) AS total_cases,
            COUNT(*) FILTER (WHERE c.case_status = 'confirmed') AS confirmed,
            COUNT(*) FILTER (WHERE c.case_status = 'deceased') AS deceased
        FROM surveillance.cases c
        WHERE c.disease_id = p_disease_id
        AND (p_district_id IS NULL OR c.district_id = p_district_id)
        AND c.onset_date BETWEEN v_start AND v_end
        GROUP BY 1
    ),
    periods AS (
        SELECT DISTINCT period_bucket
        FROM date_series
        ORDER BY period_bucket
    )
    SELECT 
        p.period_bucket,
        CASE p_interval
            WHEN 'week' THEN p.period_bucket + INTERVAL '6 days'
            WHEN 'month' THEN (p.period_bucket + INTERVAL '1 month' - INTERVAL '1 day')::DATE
            ELSE p.period_bucket
        END::DATE,
        COALESCE(cd.total_cases, 0),
        COALESCE(cd.confirmed, 0),
        COALESCE(cd.deceased, 0),
        SUM(COALESCE(cd.total_cases, 0)) OVER (ORDER BY p.period_bucket),
        SUM(COALESCE(cd.deceased, 0)) OVER (ORDER BY p.period_bucket)
    FROM periods p
    LEFT JOIN case_data cd ON p.period_bucket = cd.period_bucket
    ORDER BY p.period_bucket;
END;
$$;

COMMENT ON FUNCTION surveillance.get_epidemic_curve IS 
'Generate epidemic curve data with configurable time intervals for visualization';
