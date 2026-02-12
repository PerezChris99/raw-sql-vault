-- ============================================================================
-- Function: detect_outbreak.sql
-- Purpose: Main outbreak detection with multiple algorithms
-- ============================================================================

SET search_path TO surveillance, public;

-- Comprehensive outbreak detection combining multiple methods
CREATE OR REPLACE FUNCTION surveillance.detect_outbreaks(
    p_disease_code VARCHAR DEFAULT NULL,
    p_district_code VARCHAR DEFAULT NULL,
    p_lookback_days INTEGER DEFAULT 7,
    p_sensitivity NUMERIC DEFAULT 2.0
)
RETURNS TABLE (
    disease_code VARCHAR,
    disease_name VARCHAR,
    district_code VARCHAR,
    district_name VARCHAR,
    current_cases INTEGER,
    baseline_avg NUMERIC,
    z_score NUMERIC,
    threshold INTEGER,
    detection_method VARCHAR,
    alert_level surveillance.alert_level,
    is_outbreak BOOLEAN
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    WITH recent_cases AS (
        SELECT 
            c.disease_id,
            c.district_id,
            COUNT(*) AS case_count
        FROM surveillance.cases c
        WHERE c.report_date > CURRENT_DATE - p_lookback_days
        AND (p_disease_code IS NULL OR c.disease_id = (
            SELECT disease_id FROM surveillance.diseases WHERE disease_code = p_disease_code
        ))
        AND (p_district_code IS NULL OR c.district_id = (
            SELECT district_id FROM surveillance.districts WHERE district_code = p_district_code
        ))
        GROUP BY c.disease_id, c.district_id
    ),
    baseline_stats AS (
        SELECT 
            dc.disease_id,
            dc.district_id,
            AVG(dc.new_cases) AS avg_cases,
            STDDEV(dc.new_cases) AS std_cases,
            MAX(dc.new_cases) AS max_historical
        FROM surveillance.daily_case_counts dc
        WHERE dc.count_date BETWEEN CURRENT_DATE - 56 AND CURRENT_DATE - p_lookback_days
        GROUP BY dc.disease_id, dc.district_id
    ),
    analysis AS (
        SELECT 
            d.disease_code,
            d.disease_name,
            dist.district_code,
            dist.district_name,
            rc.case_count::INTEGER AS current_cases,
            COALESCE(bs.avg_cases * p_lookback_days, 0)::NUMERIC AS baseline_avg,
            CASE 
                WHEN COALESCE(bs.std_cases, 0) > 0 THEN
                    (rc.case_count - bs.avg_cases * p_lookback_days) / (bs.std_cases * SQRT(p_lookback_days))
                ELSE 
                    CASE WHEN rc.case_count > 0 THEN p_sensitivity + 1 ELSE 0 END
            END AS z_score,
            d.outbreak_threshold,
            CASE 
                WHEN rc.case_count >= d.outbreak_threshold THEN 'threshold'
                WHEN COALESCE(bs.std_cases, 0) > 0 AND 
                     (rc.case_count - bs.avg_cases * p_lookback_days) / (bs.std_cases * SQRT(p_lookback_days)) > p_sensitivity 
                THEN 'z_score'
                WHEN bs.avg_cases IS NOT NULL AND rc.case_count > bs.avg_cases * p_lookback_days * 2 THEN 'baseline_excess'
                ELSE 'monitoring'
            END AS detection_method
        FROM recent_cases rc
        JOIN surveillance.diseases d ON rc.disease_id = d.disease_id
        JOIN surveillance.districts dist ON rc.district_id = dist.district_id
        LEFT JOIN baseline_stats bs ON rc.disease_id = bs.disease_id AND rc.district_id = bs.district_id
    )
    SELECT 
        a.disease_code,
        a.disease_name,
        a.district_code,
        a.district_name,
        a.current_cases,
        ROUND(a.baseline_avg, 2),
        ROUND(a.z_score, 2),
        a.outbreak_threshold,
        a.detection_method,
        CASE 
            WHEN a.z_score > 4 OR a.current_cases > a.outbreak_threshold * 2 THEN 'outbreak'::surveillance.alert_level
            WHEN a.z_score > 3 OR a.current_cases >= a.outbreak_threshold THEN 'alert'::surveillance.alert_level
            WHEN a.z_score > 2 THEN 'watch'::surveillance.alert_level
            ELSE 'watch'::surveillance.alert_level
        END,
        (a.detection_method IN ('threshold', 'z_score', 'baseline_excess'))
    FROM analysis a
    WHERE a.detection_method != 'monitoring'
    ORDER BY 
        CASE a.detection_method 
            WHEN 'threshold' THEN 1 
            WHEN 'z_score' THEN 2 
            ELSE 3 
        END,
        a.z_score DESC NULLS LAST;
END;
$$;

COMMENT ON FUNCTION surveillance.detect_outbreaks IS 
'Multi-method outbreak detection combining threshold, z-score, and baseline excess detection';
