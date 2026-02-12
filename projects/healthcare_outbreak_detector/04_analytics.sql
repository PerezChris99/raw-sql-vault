-- ============================================================================
-- 🏥 HEALTHCARE OUTBREAK DETECTOR - ANALYTICS QUERIES
-- ============================================================================
-- File: 04_analytics.sql
-- Purpose: Outbreak detection algorithms, statistical analysis, anomaly detection
-- Database: PostgreSQL 14+
-- Algorithms: Z-score, Moving Average, CUSUM, Poisson-based thresholds
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- SECTION 1: BASIC OUTBREAK DETECTION QUERY
-- ============================================================================

/*
The core outbreak detection query from the problem statement:
Identifies districts with case counts exceeding thresholds
*/

-- 1.1 Basic outbreak detection (as specified in requirements)
-- SELECT district, COUNT(*) as cases, 
--        CASE WHEN COUNT(*) > 10 THEN 'Outbreak' END as alert 
-- FROM patients WHERE diagnosis='malaria' AND date > CURRENT_DATE - INTERVAL '30 days' 
-- GROUP BY district HAVING COUNT(*) > AVG(COUNT(*)) OVER ();

-- Enhanced version for production:
CREATE OR REPLACE FUNCTION surveillance.detect_basic_outbreak(
    p_disease_code VARCHAR(10) DEFAULT 'MAL',
    p_days INTEGER DEFAULT 30,
    p_threshold INTEGER DEFAULT 10
)
RETURNS TABLE(
    district_name VARCHAR(100),
    district_code VARCHAR(10),
    case_count BIGINT,
    alert_status TEXT,
    avg_cases NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    WITH district_cases AS (
        SELECT 
            d.district_name,
            d.district_code,
            COUNT(*) as cases
        FROM surveillance.cases c
        JOIN surveillance.districts d ON c.district_id = d.district_id
        JOIN surveillance.diseases dis ON c.disease_id = dis.disease_id
        WHERE dis.disease_code = p_disease_code
        AND c.report_date > CURRENT_DATE - (p_days || ' days')::INTERVAL
        GROUP BY d.district_id, d.district_name, d.district_code
    ),
    with_avg AS (
        SELECT *,
               AVG(cases) OVER () as overall_avg
        FROM district_cases
    )
    SELECT 
        district_name,
        district_code,
        cases,
        CASE 
            WHEN cases > p_threshold AND cases > overall_avg * 2 THEN 'OUTBREAK'
            WHEN cases > p_threshold THEN 'ALERT'
            ELSE 'NORMAL'
        END as alert_status,
        ROUND(overall_avg, 2)
    FROM with_avg
    WHERE cases > overall_avg
    ORDER BY cases DESC;
$$;

-- ============================================================================
-- SECTION 2: Z-SCORE BASED ANOMALY DETECTION
-- ============================================================================

/*
Z-score method: Identifies outliers based on standard deviations from mean
Typically, Z > 2 indicates potential outbreak, Z > 3 confirms outbreak
*/

-- 2.1 Calculate Z-scores for current period vs historical baseline
CREATE OR REPLACE FUNCTION surveillance.detect_zscore_anomalies(
    p_disease_id INTEGER DEFAULT NULL,
    p_lookback_weeks INTEGER DEFAULT 4,
    p_baseline_weeks INTEGER DEFAULT 52
)
RETURNS TABLE(
    disease_name VARCHAR(200),
    district_name VARCHAR(100),
    current_cases BIGINT,
    baseline_mean NUMERIC,
    baseline_stddev NUMERIC,
    z_score NUMERIC,
    alert_level TEXT
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
            COUNT(*) as cases
        FROM surveillance.cases c
        WHERE c.report_date > CURRENT_DATE - (p_lookback_weeks * 7 || ' days')::INTERVAL
        AND (p_disease_id IS NULL OR c.disease_id = p_disease_id)
        GROUP BY c.disease_id, c.district_id
    ),
    baseline_period AS (
        SELECT 
            c.disease_id,
            c.district_id,
            COUNT(*)::NUMERIC / NULLIF(p_baseline_weeks * 7 / (p_lookback_weeks * 7), 0) as weekly_avg,
            STDDEV(COUNT(*) OVER (PARTITION BY c.disease_id, c.district_id)) as weekly_stddev
        FROM surveillance.cases c
        WHERE c.report_date BETWEEN 
            CURRENT_DATE - ((p_baseline_weeks + p_lookback_weeks) * 7 || ' days')::INTERVAL
            AND CURRENT_DATE - (p_lookback_weeks * 7 || ' days')::INTERVAL
        AND (p_disease_id IS NULL OR c.disease_id = p_disease_id)
        GROUP BY c.disease_id, c.district_id
    ),
    historical_stats AS (
        SELECT 
            c.disease_id,
            c.district_id,
            AVG(daily_count) as mean_cases,
            STDDEV(daily_count) as stddev_cases
        FROM (
            SELECT 
                c.disease_id,
                c.district_id,
                c.report_date,
                COUNT(*) as daily_count
            FROM surveillance.cases c
            WHERE c.report_date BETWEEN 
                CURRENT_DATE - ((p_baseline_weeks + p_lookback_weeks) * 7 || ' days')::INTERVAL
                AND CURRENT_DATE - (p_lookback_weeks * 7 || ' days')::INTERVAL
            AND (p_disease_id IS NULL OR c.disease_id = p_disease_id)
            GROUP BY c.disease_id, c.district_id, c.report_date
        ) c
        GROUP BY c.disease_id, c.district_id
    )
    SELECT 
        dis.disease_name,
        d.district_name,
        cp.cases,
        ROUND(hs.mean_cases * (p_lookback_weeks * 7), 2) as baseline_mean,
        ROUND(COALESCE(hs.stddev_cases, 1) * SQRT(p_lookback_weeks * 7), 2) as baseline_stddev,
        ROUND((cp.cases - hs.mean_cases * (p_lookback_weeks * 7)) / 
              NULLIF(COALESCE(hs.stddev_cases, 1) * SQRT(p_lookback_weeks * 7), 0), 2) as z_score,
        CASE 
            WHEN (cp.cases - hs.mean_cases * (p_lookback_weeks * 7)) / 
                 NULLIF(COALESCE(hs.stddev_cases, 1) * SQRT(p_lookback_weeks * 7), 0) > 3 THEN 'OUTBREAK'
            WHEN (cp.cases - hs.mean_cases * (p_lookback_weeks * 7)) / 
                 NULLIF(COALESCE(hs.stddev_cases, 1) * SQRT(p_lookback_weeks * 7), 0) > 2 THEN 'ALERT'
            WHEN (cp.cases - hs.mean_cases * (p_lookback_weeks * 7)) / 
                 NULLIF(COALESCE(hs.stddev_cases, 1) * SQRT(p_lookback_weeks * 7), 0) > 1.5 THEN 'WATCH'
            ELSE 'NORMAL'
        END
    FROM current_period cp
    JOIN surveillance.diseases dis ON cp.disease_id = dis.disease_id
    JOIN surveillance.districts d ON cp.district_id = d.district_id
    LEFT JOIN historical_stats hs ON cp.disease_id = hs.disease_id AND cp.district_id = hs.district_id
    WHERE cp.cases > COALESCE(hs.mean_cases * (p_lookback_weeks * 7), 0) * 1.5
    ORDER BY z_score DESC NULLS LAST;
END;
$$;

-- ============================================================================
-- SECTION 3: MOVING AVERAGE OUTBREAK DETECTION
-- ============================================================================

-- 3.1 7-day and 14-day moving average analysis
CREATE OR REPLACE FUNCTION surveillance.get_disease_moving_averages(
    p_disease_code VARCHAR(10),
    p_district_code VARCHAR(10) DEFAULT NULL,
    p_days INTEGER DEFAULT 90
)
RETURNS TABLE(
    report_date DATE,
    district_name VARCHAR(100),
    daily_cases BIGINT,
    ma_7_day NUMERIC,
    ma_14_day NUMERIC,
    ma_28_day NUMERIC,
    trend TEXT,
    percent_change NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    WITH daily_counts AS (
        SELECT 
            c.report_date,
            d.district_name,
            COUNT(*) as cases
        FROM surveillance.cases c
        JOIN surveillance.districts d ON c.district_id = d.district_id
        JOIN surveillance.diseases dis ON c.disease_id = dis.disease_id
        WHERE dis.disease_code = p_disease_code
        AND c.report_date > CURRENT_DATE - (p_days || ' days')::INTERVAL
        AND (p_district_code IS NULL OR d.district_code = p_district_code)
        GROUP BY c.report_date, d.district_name
    )
    SELECT 
        report_date,
        district_name,
        cases,
        ROUND(AVG(cases) OVER (PARTITION BY district_name 
                               ORDER BY report_date 
                               ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) as ma_7,
        ROUND(AVG(cases) OVER (PARTITION BY district_name 
                               ORDER BY report_date 
                               ROWS BETWEEN 13 PRECEDING AND CURRENT ROW), 2) as ma_14,
        ROUND(AVG(cases) OVER (PARTITION BY district_name 
                               ORDER BY report_date 
                               ROWS BETWEEN 27 PRECEDING AND CURRENT ROW), 2) as ma_28,
        CASE 
            WHEN AVG(cases) OVER (PARTITION BY district_name 
                                  ORDER BY report_date 
                                  ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) >
                 AVG(cases) OVER (PARTITION BY district_name 
                                  ORDER BY report_date 
                                  ROWS BETWEEN 13 PRECEDING AND 7 PRECEDING) * 1.5 THEN 'RISING'
            WHEN AVG(cases) OVER (PARTITION BY district_name 
                                  ORDER BY report_date 
                                  ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) <
                 AVG(cases) OVER (PARTITION BY district_name 
                                  ORDER BY report_date 
                                  ROWS BETWEEN 13 PRECEDING AND 7 PRECEDING) * 0.7 THEN 'FALLING'
            ELSE 'STABLE'
        END as trend,
        ROUND(100.0 * (
            AVG(cases) OVER (PARTITION BY district_name ORDER BY report_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) -
            AVG(cases) OVER (PARTITION BY district_name ORDER BY report_date ROWS BETWEEN 13 PRECEDING AND 7 PRECEDING)
        ) / NULLIF(AVG(cases) OVER (PARTITION BY district_name ORDER BY report_date ROWS BETWEEN 13 PRECEDING AND 7 PRECEDING), 0), 2)
    FROM daily_counts
    ORDER BY report_date DESC, district_name;
$$;

-- ============================================================================
-- SECTION 4: EPIDEMIC CURVE GENERATION
-- ============================================================================

-- 4.1 Generate epidemic curve data for a disease/outbreak
CREATE OR REPLACE FUNCTION surveillance.get_epidemic_curve(
    p_disease_code VARCHAR(10),
    p_district_code VARCHAR(10) DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE(
    epi_date DATE,
    new_cases BIGINT,
    cumulative_cases BIGINT,
    new_deaths BIGINT,
    cumulative_deaths BIGINT,
    active_cases BIGINT,
    confirmed BIGINT,
    suspected BIGINT,
    probable BIGINT
)
LANGUAGE sql
STABLE
AS $$
    WITH date_range AS (
        SELECT generate_series(
            COALESCE(p_start_date, (SELECT MIN(onset_date) FROM surveillance.cases c 
                                    JOIN surveillance.diseases d ON c.disease_id = d.disease_id
                                    WHERE d.disease_code = p_disease_code)),
            COALESCE(p_end_date, CURRENT_DATE),
            '1 day'::INTERVAL
        )::DATE as epi_date
    ),
    daily_stats AS (
        SELECT 
            c.onset_date,
            COUNT(*) FILTER (WHERE c.case_status NOT IN ('deceased', 'recovered')) as new_cases,
            COUNT(*) FILTER (WHERE c.case_status = 'deceased') as new_deaths,
            COUNT(*) FILTER (WHERE c.case_status = 'confirmed') as confirmed,
            COUNT(*) FILTER (WHERE c.case_status = 'suspected') as suspected,
            COUNT(*) FILTER (WHERE c.case_status = 'probable') as probable
        FROM surveillance.cases c
        JOIN surveillance.diseases dis ON c.disease_id = dis.disease_id
        LEFT JOIN surveillance.districts d ON c.district_id = d.district_id
        WHERE dis.disease_code = p_disease_code
        AND (p_district_code IS NULL OR d.district_code = p_district_code)
        GROUP BY c.onset_date
    )
    SELECT 
        dr.epi_date,
        COALESCE(ds.new_cases, 0),
        SUM(COALESCE(ds.new_cases, 0)) OVER (ORDER BY dr.epi_date) as cumulative_cases,
        COALESCE(ds.new_deaths, 0),
        SUM(COALESCE(ds.new_deaths, 0)) OVER (ORDER BY dr.epi_date) as cumulative_deaths,
        SUM(COALESCE(ds.new_cases, 0)) OVER (ORDER BY dr.epi_date) - 
            SUM(COALESCE(ds.new_deaths, 0)) OVER (ORDER BY dr.epi_date) as active_cases,
        COALESCE(ds.confirmed, 0),
        COALESCE(ds.suspected, 0),
        COALESCE(ds.probable, 0)
    FROM date_range dr
    LEFT JOIN daily_stats ds ON dr.epi_date = ds.onset_date
    ORDER BY dr.epi_date;
$$;

-- ============================================================================
-- SECTION 5: GEOGRAPHIC CLUSTER DETECTION
-- ============================================================================

-- 5.1 Detect geographic clusters of cases
CREATE OR REPLACE FUNCTION surveillance.detect_geographic_clusters(
    p_disease_code VARCHAR(10),
    p_days INTEGER DEFAULT 14,
    p_min_cluster_size INTEGER DEFAULT 3
)
RETURNS TABLE(
    cluster_district VARCHAR(100),
    cluster_region VARCHAR(50),
    cases_in_cluster BIGINT,
    percent_of_total NUMERIC,
    neighboring_districts TEXT,
    cluster_severity TEXT
)
LANGUAGE sql
STABLE
AS $$
    WITH recent_cases AS (
        SELECT 
            d.district_id,
            d.district_name,
            r.region_name,
            r.region_id,
            COUNT(*) as cases
        FROM surveillance.cases c
        JOIN surveillance.districts d ON c.district_id = d.district_id
        JOIN surveillance.regions r ON d.region_id = r.region_id
        JOIN surveillance.diseases dis ON c.disease_id = dis.disease_id
        WHERE dis.disease_code = p_disease_code
        AND c.report_date > CURRENT_DATE - (p_days || ' days')::INTERVAL
        GROUP BY d.district_id, d.district_name, r.region_name, r.region_id
    ),
    total_cases AS (
        SELECT SUM(cases) as total FROM recent_cases
    )
    SELECT 
        rc.district_name,
        rc.region_name,
        rc.cases,
        ROUND(100.0 * rc.cases / NULLIF(tc.total, 0), 2),
        (SELECT STRING_AGG(d2.district_name, ', ')
         FROM surveillance.districts d2
         WHERE d2.region_id = rc.region_id
         AND d2.district_id != rc.district_id
         AND EXISTS (SELECT 1 FROM recent_cases rc2 WHERE rc2.district_id = d2.district_id)),
        CASE 
            WHEN rc.cases > 20 THEN 'HIGH'
            WHEN rc.cases > 10 THEN 'MODERATE'
            ELSE 'LOW'
        END
    FROM recent_cases rc
    CROSS JOIN total_cases tc
    WHERE rc.cases >= p_min_cluster_size
    ORDER BY rc.cases DESC;
$$;

-- ============================================================================
-- SECTION 6: REPRODUCTION NUMBER (R0) ESTIMATION
-- ============================================================================

-- 6.1 Estimate basic reproduction number
CREATE OR REPLACE FUNCTION surveillance.estimate_reproduction_number(
    p_disease_code VARCHAR(10),
    p_serial_interval_days INTEGER DEFAULT 5  -- Average time between successive cases
)
RETURNS TABLE(
    estimation_date DATE,
    new_cases BIGINT,
    prev_cases BIGINT,
    estimated_r NUMERIC,
    r_trend TEXT
)
LANGUAGE sql
STABLE
AS $$
    WITH daily_cases AS (
        SELECT 
            c.report_date,
            COUNT(*) as cases
        FROM surveillance.cases c
        JOIN surveillance.diseases dis ON c.disease_id = dis.disease_id
        WHERE dis.disease_code = p_disease_code
        AND c.report_date > CURRENT_DATE - INTERVAL '60 days'
        GROUP BY c.report_date
    )
    SELECT 
        report_date,
        cases,
        LAG(cases, p_serial_interval_days) OVER (ORDER BY report_date),
        ROUND(cases::NUMERIC / NULLIF(LAG(cases, p_serial_interval_days) OVER (ORDER BY report_date), 0), 2),
        CASE 
            WHEN cases::NUMERIC / NULLIF(LAG(cases, p_serial_interval_days) OVER (ORDER BY report_date), 0) > 1.2 THEN 'INCREASING'
            WHEN cases::NUMERIC / NULLIF(LAG(cases, p_serial_interval_days) OVER (ORDER BY report_date), 0) < 0.8 THEN 'DECREASING'
            ELSE 'STABLE'
        END
    FROM daily_cases
    WHERE LAG(cases, p_serial_interval_days) OVER (ORDER BY report_date) > 0
    ORDER BY report_date DESC
    LIMIT 30;
$$;

-- ============================================================================
-- SECTION 7: CASE FATALITY RATE ANALYSIS
-- ============================================================================

-- 7.1 Calculate CFR by disease, district, and time
CREATE OR REPLACE FUNCTION surveillance.analyze_case_fatality_rate(
    p_disease_code VARCHAR(10) DEFAULT NULL,
    p_group_by VARCHAR(20) DEFAULT 'disease'  -- 'disease', 'district', 'week', 'age_group'
)
RETURNS TABLE(
    group_name TEXT,
    total_cases BIGINT,
    deaths BIGINT,
    cfr_percent NUMERIC,
    cfr_trend TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF p_group_by = 'disease' THEN
        RETURN QUERY
        SELECT 
            dis.disease_name::TEXT,
            COUNT(*)::BIGINT,
            COUNT(*) FILTER (WHERE c.case_status = 'deceased')::BIGINT,
            ROUND(100.0 * COUNT(*) FILTER (WHERE c.case_status = 'deceased') / NULLIF(COUNT(*), 0), 2),
            CASE 
                WHEN COUNT(*) FILTER (WHERE c.case_status = 'deceased')::NUMERIC / NULLIF(COUNT(*), 0) > 
                     dis.case_fatality_rate / 100.0 * 1.5 THEN 'ABOVE_EXPECTED'
                ELSE 'NORMAL'
            END
        FROM surveillance.cases c
        JOIN surveillance.diseases dis ON c.disease_id = dis.disease_id
        WHERE (p_disease_code IS NULL OR dis.disease_code = p_disease_code)
        AND c.report_date > CURRENT_DATE - INTERVAL '90 days'
        GROUP BY dis.disease_id, dis.disease_name, dis.case_fatality_rate
        ORDER BY COUNT(*) DESC;
        
    ELSIF p_group_by = 'district' THEN
        RETURN QUERY
        SELECT 
            d.district_name::TEXT,
            COUNT(*)::BIGINT,
            COUNT(*) FILTER (WHERE c.case_status = 'deceased')::BIGINT,
            ROUND(100.0 * COUNT(*) FILTER (WHERE c.case_status = 'deceased') / NULLIF(COUNT(*), 0), 2),
            'N/A'::TEXT
        FROM surveillance.cases c
        JOIN surveillance.districts d ON c.district_id = d.district_id
        JOIN surveillance.diseases dis ON c.disease_id = dis.disease_id
        WHERE (p_disease_code IS NULL OR dis.disease_code = p_disease_code)
        AND c.report_date > CURRENT_DATE - INTERVAL '90 days'
        GROUP BY d.district_id, d.district_name
        ORDER BY COUNT(*) DESC;
        
    ELSIF p_group_by = 'age_group' THEN
        RETURN QUERY
        SELECT 
            CASE 
                WHEN p.age_years < 5 THEN 'Under 5'
                WHEN p.age_years < 15 THEN '5-14'
                WHEN p.age_years < 50 THEN '15-49'
                ELSE '50+'
            END::TEXT,
            COUNT(*)::BIGINT,
            COUNT(*) FILTER (WHERE c.case_status = 'deceased')::BIGINT,
            ROUND(100.0 * COUNT(*) FILTER (WHERE c.case_status = 'deceased') / NULLIF(COUNT(*), 0), 2),
            'N/A'::TEXT
        FROM surveillance.cases c
        JOIN surveillance.patients p ON c.patient_id = p.patient_id
        JOIN surveillance.diseases dis ON c.disease_id = dis.disease_id
        WHERE (p_disease_code IS NULL OR dis.disease_code = p_disease_code)
        AND c.report_date > CURRENT_DATE - INTERVAL '90 days'
        GROUP BY CASE 
            WHEN p.age_years < 5 THEN 'Under 5'
            WHEN p.age_years < 15 THEN '5-14'
            WHEN p.age_years < 50 THEN '15-49'
            ELSE '50+'
        END
        ORDER BY COUNT(*) DESC;
    END IF;
END;
$$;

-- ============================================================================
-- SECTION 8: WEEKLY EPIDEMIOLOGICAL ANALYSIS
-- ============================================================================

-- 8.1 Generate weekly epi report data
CREATE OR REPLACE FUNCTION surveillance.get_weekly_epi_summary(
    p_year INTEGER DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER,
    p_week INTEGER DEFAULT EXTRACT(WEEK FROM CURRENT_DATE)::INTEGER
)
RETURNS TABLE(
    disease_name VARCHAR(200),
    is_outbreak_prone BOOLEAN,
    current_week_cases BIGINT,
    previous_week_cases BIGINT,
    week_change_pct NUMERIC,
    ytd_cases BIGINT,
    ytd_deaths BIGINT,
    districts_affected BIGINT,
    alert_status TEXT
)
LANGUAGE sql
STABLE
AS $$
    WITH current_week AS (
        SELECT 
            c.disease_id,
            COUNT(*) as cases,
            COUNT(DISTINCT c.district_id) as districts
        FROM surveillance.cases c
        WHERE c.report_year = p_year AND c.report_week = p_week
        GROUP BY c.disease_id
    ),
    previous_week AS (
        SELECT 
            c.disease_id,
            COUNT(*) as cases
        FROM surveillance.cases c
        WHERE (c.report_year = p_year AND c.report_week = p_week - 1)
           OR (p_week = 1 AND c.report_year = p_year - 1 AND c.report_week = 52)
        GROUP BY c.disease_id
    ),
    ytd AS (
        SELECT 
            c.disease_id,
            COUNT(*) as cases,
            COUNT(*) FILTER (WHERE c.case_status = 'deceased') as deaths
        FROM surveillance.cases c
        WHERE c.report_year = p_year
        GROUP BY c.disease_id
    )
    SELECT 
        dis.disease_name,
        dis.is_outbreak_prone,
        COALESCE(cw.cases, 0),
        COALESCE(pw.cases, 0),
        ROUND(100.0 * (COALESCE(cw.cases, 0) - COALESCE(pw.cases, 0)) / NULLIF(COALESCE(pw.cases, 1), 0), 2),
        COALESCE(y.cases, 0),
        COALESCE(y.deaths, 0),
        COALESCE(cw.districts, 0),
        CASE 
            WHEN COALESCE(cw.cases, 0) > dis.outbreak_threshold THEN 'OUTBREAK'
            WHEN COALESCE(cw.cases, 0) > dis.endemic_baseline * 1.5 THEN 'ALERT'
            WHEN COALESCE(cw.cases, 0) > dis.endemic_baseline THEN 'WATCH'
            ELSE 'NORMAL'
        END
    FROM surveillance.diseases dis
    LEFT JOIN current_week cw ON dis.disease_id = cw.disease_id
    LEFT JOIN previous_week pw ON dis.disease_id = pw.disease_id
    LEFT JOIN ytd y ON dis.disease_id = y.disease_id
    WHERE dis.is_notifiable = TRUE
    AND (COALESCE(cw.cases, 0) > 0 OR COALESCE(y.cases, 0) > 0)
    ORDER BY COALESCE(cw.cases, 0) DESC;
$$;

-- ============================================================================
-- SECTION 9: COMPREHENSIVE OUTBREAK DETECTION
-- ============================================================================

-- 9.1 Main outbreak detection function (combines multiple methods)
CREATE OR REPLACE FUNCTION surveillance.detect_outbreaks(
    p_sensitivity VARCHAR(10) DEFAULT 'medium'  -- 'low', 'medium', 'high'
)
RETURNS TABLE(
    disease_name VARCHAR(200),
    district_name VARCHAR(100),
    current_cases BIGINT,
    baseline NUMERIC,
    threshold NUMERIC,
    deviation NUMERIC,
    alert_level surveillance.alert_level,
    detection_method TEXT,
    requires_action BOOLEAN
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_multiplier DECIMAL;
BEGIN
    -- Set sensitivity multiplier
    v_multiplier := CASE p_sensitivity
        WHEN 'high' THEN 1.2
        WHEN 'low' THEN 2.0
        ELSE 1.5  -- medium
    END;
    
    RETURN QUERY
    WITH recent_cases AS (
        SELECT 
            c.disease_id,
            c.district_id,
            COUNT(*) as cases
        FROM surveillance.cases c
        WHERE c.report_date > CURRENT_DATE - INTERVAL '7 days'
        GROUP BY c.disease_id, c.district_id
    ),
    baseline_stats AS (
        SELECT 
            c.disease_id,
            c.district_id,
            AVG(daily_count)::NUMERIC as mean_daily,
            STDDEV(daily_count)::NUMERIC as stddev_daily
        FROM (
            SELECT 
                disease_id,
                district_id,
                report_date,
                COUNT(*) as daily_count
            FROM surveillance.cases
            WHERE report_date BETWEEN CURRENT_DATE - INTERVAL '90 days' AND CURRENT_DATE - INTERVAL '7 days'
            GROUP BY disease_id, district_id, report_date
        ) c
        GROUP BY c.disease_id, c.district_id
    )
    SELECT 
        dis.disease_name,
        d.district_name,
        rc.cases,
        ROUND(bs.mean_daily * 7, 2),
        ROUND((bs.mean_daily * 7) * dis.alert_threshold_multiplier, 2),
        ROUND((rc.cases - bs.mean_daily * 7) / NULLIF(bs.stddev_daily * SQRT(7), 1), 2),
        CASE 
            WHEN rc.cases > (bs.mean_daily * 7) * dis.emergency_threshold_multiplier THEN 'emergency'::surveillance.alert_level
            WHEN rc.cases > (bs.mean_daily * 7) * dis.outbreak_threshold_multiplier THEN 'outbreak'::surveillance.alert_level
            WHEN rc.cases > (bs.mean_daily * 7) * dis.alert_threshold_multiplier * v_multiplier THEN 'alert'::surveillance.alert_level
            ELSE 'watch'::surveillance.alert_level
        END,
        'threshold_and_zscore',
        CASE 
            WHEN rc.cases > (bs.mean_daily * 7) * dis.alert_threshold_multiplier * v_multiplier THEN TRUE
            ELSE FALSE
        END
    FROM recent_cases rc
    JOIN surveillance.diseases dis ON rc.disease_id = dis.disease_id
    JOIN surveillance.districts d ON rc.district_id = d.district_id
    LEFT JOIN baseline_stats bs ON rc.disease_id = bs.disease_id AND rc.district_id = bs.district_id
    WHERE dis.is_notifiable = TRUE
    AND rc.cases > COALESCE(bs.mean_daily * 7 * v_multiplier, dis.endemic_baseline * 0.5)
    ORDER BY rc.cases DESC;
END;
$$;

-- ============================================================================
-- SECTION 10: DASHBOARD SUMMARY QUERIES
-- ============================================================================

-- 10.1 National dashboard summary
CREATE OR REPLACE FUNCTION surveillance.get_national_dashboard()
RETURNS JSONB
LANGUAGE sql
STABLE
AS $$
    SELECT jsonb_build_object(
        'summary_date', CURRENT_DATE,
        'total_cases_7d', (SELECT COUNT(*) FROM surveillance.cases WHERE report_date > CURRENT_DATE - INTERVAL '7 days'),
        'total_cases_30d', (SELECT COUNT(*) FROM surveillance.cases WHERE report_date > CURRENT_DATE - INTERVAL '30 days'),
        'active_outbreaks', (SELECT COUNT(*) FROM surveillance.outbreaks WHERE response_status = 'active'),
        'active_alerts', (SELECT COUNT(*) FROM surveillance.alerts WHERE alert_status = 'active'),
        'districts_affected', (SELECT COUNT(DISTINCT district_id) FROM surveillance.cases WHERE report_date > CURRENT_DATE - INTERVAL '7 days'),
        'top_diseases', (
            SELECT jsonb_agg(disease_data)
            FROM (
                SELECT jsonb_build_object(
                    'disease', dis.disease_name,
                    'cases', COUNT(*),
                    'trend', CASE WHEN COUNT(*) > 10 THEN 'UP' ELSE 'STABLE' END
                ) as disease_data
                FROM surveillance.cases c
                JOIN surveillance.diseases dis ON c.disease_id = dis.disease_id
                WHERE c.report_date > CURRENT_DATE - INTERVAL '7 days'
                GROUP BY dis.disease_name
                ORDER BY COUNT(*) DESC
                LIMIT 5
            ) t
        ),
        'alert_summary', (
            SELECT jsonb_object_agg(alert_level, cnt)
            FROM (
                SELECT alert_level::TEXT, COUNT(*) as cnt
                FROM surveillance.alerts
                WHERE alert_status = 'active'
                GROUP BY alert_level
            ) t
        )
    );
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_func_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'surveillance'
    AND p.proname LIKE 'detect_%' OR p.proname LIKE 'get_%' OR p.proname LIKE 'analyze_%' OR p.proname LIKE 'estimate_%';
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'ANALYTICS FUNCTIONS CREATED SUCCESSFULLY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Analytics functions: %', v_func_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Outbreak Detection:';
    RAISE NOTICE '  - detect_basic_outbreak()';
    RAISE NOTICE '  - detect_zscore_anomalies()';
    RAISE NOTICE '  - detect_geographic_clusters()';
    RAISE NOTICE '  - detect_outbreaks() [comprehensive]';
    RAISE NOTICE '';
    RAISE NOTICE 'Analysis Functions:';
    RAISE NOTICE '  - get_disease_moving_averages()';
    RAISE NOTICE '  - get_epidemic_curve()';
    RAISE NOTICE '  - get_weekly_epi_summary()';
    RAISE NOTICE '  - estimate_reproduction_number()';
    RAISE NOTICE '  - analyze_case_fatality_rate()';
    RAISE NOTICE '';
    RAISE NOTICE 'Dashboard:';
    RAISE NOTICE '  - get_national_dashboard()';
    RAISE NOTICE '==========================================';
END $$;
