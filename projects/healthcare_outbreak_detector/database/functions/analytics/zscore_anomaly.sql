-- ============================================================================
-- Function: zscore_anomaly.sql
-- Purpose: Statistical Z-score based anomaly detection
-- ============================================================================

SET search_path TO surveillance, public;

CREATE OR REPLACE FUNCTION surveillance.detect_zscore_anomalies(
    p_disease_id INTEGER DEFAULT NULL,
    p_district_id INTEGER DEFAULT NULL,
    p_lookback_days INTEGER DEFAULT 7,
    p_baseline_weeks INTEGER DEFAULT 8,
    p_threshold NUMERIC DEFAULT 2.0
)
RETURNS TABLE (
    disease_id INTEGER,
    disease_name VARCHAR,
    district_id INTEGER,
    district_name VARCHAR,
    current_period_cases BIGINT,
    baseline_mean NUMERIC,
    baseline_stddev NUMERIC,
    z_score NUMERIC,
    is_anomaly BOOLEAN,
    confidence_level VARCHAR
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    WITH current_period AS (
        SELECT 
            c.disease_id,
            c.district_id,
            COUNT(*) AS case_count
        FROM surveillance.cases c
        WHERE c.report_date > CURRENT_DATE - p_lookback_days
        AND (p_disease_id IS NULL OR c.disease_id = p_disease_id)
        AND (p_district_id IS NULL OR c.district_id = p_district_id)
        GROUP BY c.disease_id, c.district_id
    ),
    baseline_period AS (
        SELECT 
            c.disease_id,
            c.district_id,
            COUNT(*)::NUMERIC / p_baseline_weeks AS weekly_avg,
            STDDEV(sub.weekly_count) AS weekly_stddev
        FROM surveillance.cases c
        CROSS JOIN LATERAL (
            SELECT COUNT(*) AS weekly_count
            FROM surveillance.cases c2
            WHERE c2.disease_id = c.disease_id
            AND c2.district_id = c.district_id
            AND c2.report_date BETWEEN 
                CURRENT_DATE - ((p_baseline_weeks + 1) * 7) 
                AND CURRENT_DATE - p_lookback_days
            GROUP BY DATE_TRUNC('week', c2.report_date)
        ) sub
        WHERE c.report_date BETWEEN 
            CURRENT_DATE - ((p_baseline_weeks + 1) * 7) 
            AND CURRENT_DATE - p_lookback_days
        AND (p_disease_id IS NULL OR c.disease_id = p_disease_id)
        AND (p_district_id IS NULL OR c.district_id = p_district_id)
        GROUP BY c.disease_id, c.district_id
    ),
    calculations AS (
        SELECT 
            cp.disease_id,
            d.disease_name,
            cp.district_id,
            dist.district_name,
            cp.case_count,
            COALESCE(bp.weekly_avg * (p_lookback_days::NUMERIC / 7), 0) AS expected_cases,
            COALESCE(bp.weekly_stddev * SQRT(p_lookback_days::NUMERIC / 7), 1) AS adjusted_stddev
        FROM current_period cp
        JOIN surveillance.diseases d ON cp.disease_id = d.disease_id
        JOIN surveillance.districts dist ON cp.district_id = dist.district_id
        LEFT JOIN baseline_period bp ON cp.disease_id = bp.disease_id 
            AND cp.district_id = bp.district_id
    )
    SELECT 
        calc.disease_id,
        calc.disease_name,
        calc.district_id,
        calc.district_name,
        calc.case_count,
        ROUND(calc.expected_cases, 2),
        ROUND(calc.adjusted_stddev, 2),
        ROUND((calc.case_count - calc.expected_cases) / GREATEST(calc.adjusted_stddev, 0.1), 2) AS calc_z_score,
        (calc.case_count - calc.expected_cases) / GREATEST(calc.adjusted_stddev, 0.1) > p_threshold,
        CASE 
            WHEN (calc.case_count - calc.expected_cases) / GREATEST(calc.adjusted_stddev, 0.1) > 3 THEN 'HIGH (>3σ)'
            WHEN (calc.case_count - calc.expected_cases) / GREATEST(calc.adjusted_stddev, 0.1) > 2 THEN 'MEDIUM (>2σ)'
            WHEN (calc.case_count - calc.expected_cases) / GREATEST(calc.adjusted_stddev, 0.1) > 1.5 THEN 'LOW (>1.5σ)'
            ELSE 'NORMAL'
        END
    FROM calculations calc
    WHERE calc.case_count > 0
    ORDER BY (calc.case_count - calc.expected_cases) / GREATEST(calc.adjusted_stddev, 0.1) DESC;
END;
$$;

COMMENT ON FUNCTION surveillance.detect_zscore_anomalies IS 
'Detect statistical anomalies using Z-score deviation from historical baseline';
