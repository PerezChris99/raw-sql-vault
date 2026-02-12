-- ============================================================================
-- Analytics Functions: Dropout Analysis
-- Education Dropout Forecaster
-- PostgreSQL 14+ - Window Functions Showcase
-- ============================================================================

-- ============================================================================
-- CORE QUERY: School Rankings by District (Per Specification)
-- ============================================================================

-- Function: Get schools ranked by dropout count within each district
CREATE OR REPLACE FUNCTION fn_school_dropout_rankings(
    p_academic_year INTEGER DEFAULT NULL,
    p_district_id INTEGER DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    school_id INTEGER,
    school_name VARCHAR,
    district_name VARCHAR,
    dropout_count BIGINT,
    dropout_rate NUMERIC,
    district_rank BIGINT,
    overall_rank BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.school_id,
        s.school_name,
        d.district_name,
        COUNT(*)::BIGINT AS dropout_count,
        ROUND(COUNT(*) * 100.0 / NULLIF(s.enrollment, 0), 2) AS dropout_rate,
        ROW_NUMBER() OVER (
            PARTITION BY d.district_id 
            ORDER BY COUNT(*) DESC
        )::BIGINT AS district_rank,
        RANK() OVER (
            ORDER BY COUNT(*) DESC
        )::BIGINT AS overall_rank
    FROM students st
    JOIN schools s ON st.school_id = s.school_id
    JOIN districts d ON s.district_id = d.district_id
    WHERE st.status = 'DROPPED'
      AND (p_academic_year IS NULL OR st.academic_year = p_academic_year)
      AND (p_district_id IS NULL OR d.district_id = p_district_id)
    GROUP BY s.school_id, s.school_name, d.district_id, d.district_name, s.enrollment
    ORDER BY d.district_name, district_rank
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- YEAR-OVER-YEAR COMPARISON with LAG/LEAD
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_yoy_comparison(
    p_school_id INTEGER DEFAULT NULL,
    p_district_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
    school_id INTEGER,
    school_name VARCHAR,
    academic_year INTEGER,
    dropout_count BIGINT,
    prev_year_dropouts BIGINT,
    next_year_dropouts BIGINT,
    change_from_prev INTEGER,
    pct_change NUMERIC,
    trend VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH yearly_stats AS (
        SELECT 
            s.school_id,
            s.school_name,
            st.academic_year,
            COUNT(*)::BIGINT AS dropouts
        FROM students st
        JOIN schools s ON st.school_id = s.school_id
        WHERE st.status = 'DROPPED'
          AND (p_school_id IS NULL OR s.school_id = p_school_id)
          AND (p_district_id IS NULL OR s.district_id = p_district_id)
        GROUP BY s.school_id, s.school_name, st.academic_year
    )
    SELECT 
        ys.school_id,
        ys.school_name,
        ys.academic_year,
        ys.dropouts AS dropout_count,
        LAG(ys.dropouts, 1) OVER (
            PARTITION BY ys.school_id 
            ORDER BY ys.academic_year
        ) AS prev_year_dropouts,
        LEAD(ys.dropouts, 1) OVER (
            PARTITION BY ys.school_id 
            ORDER BY ys.academic_year
        ) AS next_year_dropouts,
        (ys.dropouts - LAG(ys.dropouts, 1) OVER (PARTITION BY ys.school_id ORDER BY ys.academic_year))::INTEGER AS change_from_prev,
        ROUND(
            (ys.dropouts - LAG(ys.dropouts, 1) OVER (PARTITION BY ys.school_id ORDER BY ys.academic_year)) 
            * 100.0 / NULLIF(LAG(ys.dropouts, 1) OVER (PARTITION BY ys.school_id ORDER BY ys.academic_year), 0)
        , 2) AS pct_change,
        CASE 
            WHEN ys.dropouts > LAG(ys.dropouts, 1) OVER (PARTITION BY ys.school_id ORDER BY ys.academic_year) THEN 'INCREASING'
            WHEN ys.dropouts < LAG(ys.dropouts, 1) OVER (PARTITION BY ys.school_id ORDER BY ys.academic_year) THEN 'DECREASING'
            ELSE 'STABLE'
        END AS trend
    FROM yearly_stats ys
    ORDER BY ys.school_id, ys.academic_year;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- RUNNING TOTALS with SUM OVER
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_cumulative_dropouts(
    p_school_id INTEGER,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS TABLE (
    dropout_date DATE,
    daily_count BIGINT,
    cumulative_total BIGINT,
    ytd_total BIGINT,
    rolling_7day BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH daily_dropouts AS (
        SELECT 
            de.dropout_date,
            COUNT(*)::BIGINT AS daily_count
        FROM dropout_events de
        WHERE de.school_id = p_school_id
          AND (p_start_date IS NULL OR de.dropout_date >= p_start_date)
          AND (p_end_date IS NULL OR de.dropout_date <= p_end_date)
        GROUP BY de.dropout_date
    )
    SELECT 
        dd.dropout_date,
        dd.daily_count,
        SUM(dd.daily_count) OVER (
            ORDER BY dd.dropout_date 
            ROWS UNBOUNDED PRECEDING
        )::BIGINT AS cumulative_total,
        SUM(dd.daily_count) OVER (
            PARTITION BY EXTRACT(YEAR FROM dd.dropout_date)
            ORDER BY dd.dropout_date 
            ROWS UNBOUNDED PRECEDING
        )::BIGINT AS ytd_total,
        SUM(dd.daily_count) OVER (
            ORDER BY dd.dropout_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        )::BIGINT AS rolling_7day
    FROM daily_dropouts dd
    ORDER BY dd.dropout_date;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- PERCENTILE ANALYSIS with NTILE
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_risk_percentiles(
    p_school_id INTEGER DEFAULT NULL,
    p_district_id INTEGER DEFAULT NULL,
    p_risk_threshold NUMERIC DEFAULT 0
)
RETURNS TABLE (
    student_id INTEGER,
    student_name VARCHAR,
    school_name VARCHAR,
    grade_level INTEGER,
    risk_score NUMERIC,
    risk_quartile INTEGER,
    risk_decile INTEGER,
    risk_percentile INTEGER,
    percentile_rank NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        st.student_id,
        (st.first_name || ' ' || st.last_name)::VARCHAR AS student_name,
        s.school_name,
        st.grade_level,
        st.risk_score,
        NTILE(4) OVER (ORDER BY st.risk_score DESC)::INTEGER AS risk_quartile,
        NTILE(10) OVER (ORDER BY st.risk_score DESC)::INTEGER AS risk_decile,
        NTILE(100) OVER (ORDER BY st.risk_score DESC)::INTEGER AS risk_percentile,
        ROUND(PERCENT_RANK() OVER (ORDER BY st.risk_score) * 100, 2) AS percentile_rank
    FROM students st
    JOIN schools s ON st.school_id = s.school_id
    WHERE st.status = 'ACTIVE'
      AND st.risk_score >= p_risk_threshold
      AND (p_school_id IS NULL OR st.school_id = p_school_id)
      AND (p_district_id IS NULL OR s.district_id = p_district_id)
    ORDER BY st.risk_score DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- MOVING AVERAGES with AVG OVER
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_dropout_moving_averages(
    p_district_id INTEGER DEFAULT NULL,
    p_months INTEGER DEFAULT 12
)
RETURNS TABLE (
    district_id INTEGER,
    district_name VARCHAR,
    report_month DATE,
    monthly_dropouts BIGINT,
    moving_avg_3m NUMERIC,
    moving_avg_6m NUMERIC,
    moving_avg_12m NUMERIC,
    trend_direction VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH monthly_stats AS (
        SELECT 
            d.district_id,
            d.district_name,
            DATE_TRUNC('month', de.dropout_date)::DATE AS report_month,
            COUNT(*)::BIGINT AS monthly_dropouts
        FROM dropout_events de
        JOIN districts d ON de.district_id = d.district_id
        WHERE (p_district_id IS NULL OR d.district_id = p_district_id)
          AND de.dropout_date >= CURRENT_DATE - (p_months || ' months')::INTERVAL
        GROUP BY d.district_id, d.district_name, DATE_TRUNC('month', de.dropout_date)
    )
    SELECT 
        ms.district_id,
        ms.district_name,
        ms.report_month,
        ms.monthly_dropouts,
        ROUND(AVG(ms.monthly_dropouts) OVER (
            PARTITION BY ms.district_id 
            ORDER BY ms.report_month 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2) AS moving_avg_3m,
        ROUND(AVG(ms.monthly_dropouts) OVER (
            PARTITION BY ms.district_id 
            ORDER BY ms.report_month 
            ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
        ), 2) AS moving_avg_6m,
        ROUND(AVG(ms.monthly_dropouts) OVER (
            PARTITION BY ms.district_id 
            ORDER BY ms.report_month 
            ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
        ), 2) AS moving_avg_12m,
        CASE 
            WHEN ms.monthly_dropouts > AVG(ms.monthly_dropouts) OVER (
                PARTITION BY ms.district_id ORDER BY ms.report_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ) * 1.1 THEN 'UP'
            WHEN ms.monthly_dropouts < AVG(ms.monthly_dropouts) OVER (
                PARTITION BY ms.district_id ORDER BY ms.report_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ) * 0.9 THEN 'DOWN'
            ELSE 'STABLE'
        END::VARCHAR AS trend_direction
    FROM monthly_stats ms
    ORDER BY ms.district_id, ms.report_month;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- FIRST/LAST VALUE Analysis
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_school_dropout_extremes(
    p_academic_year INTEGER DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER
)
RETURNS TABLE (
    district_id INTEGER,
    district_name VARCHAR,
    school_count BIGINT,
    total_dropouts BIGINT,
    avg_dropout_rate NUMERIC,
    highest_school VARCHAR,
    highest_dropout_count BIGINT,
    lowest_school VARCHAR,
    lowest_dropout_count BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH school_stats AS (
        SELECT 
            d.district_id,
            d.district_name,
            s.school_id,
            s.school_name,
            COUNT(*)::BIGINT AS dropout_count
        FROM students st
        JOIN schools s ON st.school_id = s.school_id
        JOIN districts d ON s.district_id = d.district_id
        WHERE st.status = 'DROPPED'
          AND st.academic_year = p_academic_year
        GROUP BY d.district_id, d.district_name, s.school_id, s.school_name
    )
    SELECT DISTINCT
        ss.district_id,
        ss.district_name,
        COUNT(*) OVER (PARTITION BY ss.district_id)::BIGINT AS school_count,
        SUM(ss.dropout_count) OVER (PARTITION BY ss.district_id)::BIGINT AS total_dropouts,
        ROUND(AVG(ss.dropout_count) OVER (PARTITION BY ss.district_id), 2) AS avg_dropout_rate,
        FIRST_VALUE(ss.school_name) OVER (
            PARTITION BY ss.district_id 
            ORDER BY ss.dropout_count DESC
        ) AS highest_school,
        FIRST_VALUE(ss.dropout_count) OVER (
            PARTITION BY ss.district_id 
            ORDER BY ss.dropout_count DESC
        ) AS highest_dropout_count,
        LAST_VALUE(ss.school_name) OVER (
            PARTITION BY ss.district_id 
            ORDER BY ss.dropout_count DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS lowest_school,
        LAST_VALUE(ss.dropout_count) OVER (
            PARTITION BY ss.district_id 
            ORDER BY ss.dropout_count DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) AS lowest_dropout_count
    FROM school_stats ss
    ORDER BY ss.district_name;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DENSE_RANK for Reason Analysis
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_dropout_reason_rankings(
    p_academic_year INTEGER DEFAULT NULL
)
RETURNS TABLE (
    reason_code VARCHAR,
    reason_name VARCHAR,
    is_preventable BOOLEAN,
    total_dropouts BIGINT,
    rank_position BIGINT,
    dense_rank_position BIGINT,
    pct_of_total NUMERIC,
    cumulative_pct NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        dr.reason_code,
        dr.reason_name,
        dr.is_preventable,
        COUNT(*)::BIGINT AS total_dropouts,
        RANK() OVER (ORDER BY COUNT(*) DESC)::BIGINT AS rank_position,
        DENSE_RANK() OVER (ORDER BY COUNT(*) DESC)::BIGINT AS dense_rank_position,
        ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
        ROUND(
            SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC ROWS UNBOUNDED PRECEDING) * 100.0 
            / SUM(COUNT(*)) OVER ()
        , 2) AS cumulative_pct
    FROM students st
    JOIN dropout_reasons dr ON st.dropout_reason_id = dr.reason_id
    WHERE st.status = 'DROPPED'
      AND (p_academic_year IS NULL OR st.academic_year = p_academic_year)
    GROUP BY dr.reason_id, dr.reason_code, dr.reason_name, dr.is_preventable
    ORDER BY rank_position;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- AT-RISK STUDENT IDENTIFICATION
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_identify_at_risk_students(
    p_school_id INTEGER DEFAULT NULL,
    p_risk_decile_threshold INTEGER DEFAULT 3,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    student_id INTEGER,
    student_code VARCHAR,
    full_name VARCHAR,
    school_name VARCHAR,
    grade_level INTEGER,
    gpa NUMERIC,
    attendance_rate NUMERIC,
    disciplinary_incidents INTEGER,
    risk_score NUMERIC,
    risk_decile INTEGER,
    school_risk_rank BIGINT,
    district_risk_rank BIGINT,
    recommended_interventions TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        st.student_id,
        st.student_code,
        (st.first_name || ' ' || st.last_name)::VARCHAR AS full_name,
        s.school_name,
        st.grade_level,
        st.gpa,
        st.attendance_rate,
        st.disciplinary_incidents,
        st.risk_score,
        st.risk_decile,
        ROW_NUMBER() OVER (
            PARTITION BY st.school_id 
            ORDER BY st.risk_score DESC
        )::BIGINT AS school_risk_rank,
        ROW_NUMBER() OVER (
            PARTITION BY s.district_id 
            ORDER BY st.risk_score DESC
        )::BIGINT AS district_risk_rank,
        ARRAY_REMOVE(ARRAY[
            CASE WHEN st.gpa < 2.0 THEN 'TUTORING' END,
            CASE WHEN st.attendance_rate < 80 THEN 'ATTENDANCE_PLAN' END,
            CASE WHEN st.disciplinary_incidents > 3 THEN 'BEHAVIOR_PLAN' END,
            CASE WHEN st.free_reduced_lunch THEN 'FINANCIAL_AID' END,
            CASE WHEN st.foster_care OR st.homeless THEN 'COUNSELING' END
        ], NULL)::TEXT[] AS recommended_interventions
    FROM students st
    JOIN schools s ON st.school_id = s.school_id
    WHERE st.status = 'ACTIVE'
      AND st.risk_decile <= p_risk_decile_threshold
      AND (p_school_id IS NULL OR st.school_id = p_school_id)
    ORDER BY st.risk_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- GRADE LEVEL TRANSITION ANALYSIS
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_grade_transition_dropout_risk()
RETURNS TABLE (
    grade_level INTEGER,
    dropout_count BIGINT,
    prev_grade_dropouts BIGINT,
    next_grade_dropouts BIGINT,
    grade_rank BIGINT,
    dropout_rate NUMERIC,
    is_transition_grade BOOLEAN,
    risk_level VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH grade_stats AS (
        SELECT 
            st.grade_level,
            COUNT(*)::BIGINT AS dropout_count
        FROM students st
        WHERE st.status = 'DROPPED'
        GROUP BY st.grade_level
    )
    SELECT 
        gs.grade_level,
        gs.dropout_count,
        LAG(gs.dropout_count, 1) OVER (ORDER BY gs.grade_level) AS prev_grade_dropouts,
        LEAD(gs.dropout_count, 1) OVER (ORDER BY gs.grade_level) AS next_grade_dropouts,
        ROW_NUMBER() OVER (ORDER BY gs.dropout_count DESC)::BIGINT AS grade_rank,
        ROUND(gs.dropout_count * 100.0 / SUM(gs.dropout_count) OVER (), 2) AS dropout_rate,
        gs.grade_level IN (6, 9)::BOOLEAN AS is_transition_grade,  -- Middle/High school transitions
        CASE 
            WHEN NTILE(3) OVER (ORDER BY gs.dropout_count DESC) = 1 THEN 'HIGH'
            WHEN NTILE(3) OVER (ORDER BY gs.dropout_count DESC) = 2 THEN 'MEDIUM'
            ELSE 'LOW'
        END::VARCHAR AS risk_level
    FROM grade_stats gs
    ORDER BY gs.grade_level;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COHORT ANALYSIS
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_cohort_survival_analysis(
    p_enrollment_year INTEGER,
    p_school_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
    school_id INTEGER,
    school_name VARCHAR,
    cohort_year INTEGER,
    years_since_enrollment INTEGER,
    students_remaining BIGINT,
    students_dropped BIGINT,
    cumulative_dropped BIGINT,
    survival_rate NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH cohort AS (
        SELECT 
            st.school_id,
            s.school_name,
            p_enrollment_year AS cohort_year,
            EXTRACT(YEAR FROM st.dropout_date)::INTEGER - p_enrollment_year AS years_since_enrollment,
            COUNT(*)::BIGINT AS students_dropped
        FROM students st
        JOIN schools s ON st.school_id = s.school_id
        WHERE EXTRACT(YEAR FROM st.enrolled_date) = p_enrollment_year
          AND st.status = 'DROPPED'
          AND (p_school_id IS NULL OR st.school_id = p_school_id)
        GROUP BY st.school_id, s.school_name, EXTRACT(YEAR FROM st.dropout_date)
    ),
    cohort_size AS (
        SELECT 
            st.school_id,
            COUNT(*)::BIGINT AS initial_size
        FROM students st
        WHERE EXTRACT(YEAR FROM st.enrolled_date) = p_enrollment_year
          AND (p_school_id IS NULL OR st.school_id = p_school_id)
        GROUP BY st.school_id
    )
    SELECT 
        c.school_id,
        c.school_name,
        c.cohort_year,
        c.years_since_enrollment,
        (cs.initial_size - SUM(c.students_dropped) OVER (
            PARTITION BY c.school_id ORDER BY c.years_since_enrollment ROWS UNBOUNDED PRECEDING
        ))::BIGINT AS students_remaining,
        c.students_dropped,
        SUM(c.students_dropped) OVER (
            PARTITION BY c.school_id ORDER BY c.years_since_enrollment ROWS UNBOUNDED PRECEDING
        )::BIGINT AS cumulative_dropped,
        ROUND(
            (cs.initial_size - SUM(c.students_dropped) OVER (
                PARTITION BY c.school_id ORDER BY c.years_since_enrollment ROWS UNBOUNDED PRECEDING
            )) * 100.0 / cs.initial_size
        , 2) AS survival_rate
    FROM cohort c
    JOIN cohort_size cs ON c.school_id = cs.school_id
    ORDER BY c.school_id, c.years_since_enrollment;
END;
$$ LANGUAGE plpgsql;
