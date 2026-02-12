-- ============================================================================
-- Migration V004: Views
-- Education Dropout Forecaster - Analytics Views
-- PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- VIEW: School Rankings by Dropout Count (Core Query)
-- ============================================================================

CREATE OR REPLACE VIEW vw_school_dropout_rankings AS
SELECT 
    s.school_id,
    s.school_code,
    s.school_name,
    d.district_id,
    d.district_name,
    st.state_name,
    COUNT(*) AS dropout_count,
    s.enrollment,
    ROUND(COUNT(*) * 100.0 / NULLIF(s.enrollment, 0), 2) AS dropout_rate,
    ROW_NUMBER() OVER (
        PARTITION BY d.district_id 
        ORDER BY COUNT(*) DESC
    ) AS district_rank,
    RANK() OVER (
        ORDER BY COUNT(*) DESC
    ) AS overall_rank,
    DENSE_RANK() OVER (
        ORDER BY ROUND(COUNT(*) * 100.0 / NULLIF(s.enrollment, 0), 2) DESC
    ) AS rate_rank
FROM students stu
JOIN schools s ON stu.school_id = s.school_id
JOIN districts d ON s.district_id = d.district_id
JOIN states st ON d.state_id = st.state_id
WHERE stu.status = 'DROPPED'
GROUP BY s.school_id, s.school_code, s.school_name, s.enrollment,
         d.district_id, d.district_name, st.state_name;

-- ============================================================================
-- VIEW: Year-over-Year Comparison with LAG
-- ============================================================================

CREATE OR REPLACE VIEW vw_yoy_dropout_comparison AS
SELECT 
    school_id,
    school_name,
    academic_year,
    dropout_count,
    LAG(dropout_count, 1) OVER (
        PARTITION BY school_id 
        ORDER BY academic_year
    ) AS prev_year_dropouts,
    LAG(dropout_count, 2) OVER (
        PARTITION BY school_id 
        ORDER BY academic_year
    ) AS two_years_ago_dropouts,
    dropout_count - LAG(dropout_count, 1) OVER (
        PARTITION BY school_id 
        ORDER BY academic_year
    ) AS change_from_prev_year,
    ROUND(
        (dropout_count - LAG(dropout_count, 1) OVER (PARTITION BY school_id ORDER BY academic_year)) 
        * 100.0 / NULLIF(LAG(dropout_count, 1) OVER (PARTITION BY school_id ORDER BY academic_year), 0)
    , 2) AS pct_change,
    LEAD(dropout_count, 1) OVER (
        PARTITION BY school_id 
        ORDER BY academic_year
    ) AS next_year_dropouts
FROM (
    SELECT 
        s.school_id,
        s.school_name,
        stu.academic_year,
        COUNT(*) AS dropout_count
    FROM students stu
    JOIN schools s ON stu.school_id = s.school_id
    WHERE stu.status = 'DROPPED'
    GROUP BY s.school_id, s.school_name, stu.academic_year
) yearly_stats;

-- ============================================================================
-- VIEW: Running Total of Dropouts
-- ============================================================================

CREATE OR REPLACE VIEW vw_cumulative_dropouts AS
SELECT 
    de.school_id,
    s.school_name,
    de.dropout_date,
    COUNT(*) AS daily_dropouts,
    SUM(COUNT(*)) OVER (
        PARTITION BY de.school_id 
        ORDER BY de.dropout_date 
        ROWS UNBOUNDED PRECEDING
    ) AS cumulative_dropouts,
    SUM(COUNT(*)) OVER (
        PARTITION BY de.school_id, EXTRACT(YEAR FROM de.dropout_date)
        ORDER BY de.dropout_date 
        ROWS UNBOUNDED PRECEDING
    ) AS ytd_dropouts
FROM dropout_events de
JOIN schools s ON de.school_id = s.school_id
GROUP BY de.school_id, s.school_name, de.dropout_date;

-- ============================================================================
-- VIEW: Risk Score Percentiles
-- ============================================================================

CREATE OR REPLACE VIEW vw_student_risk_percentiles AS
SELECT 
    stu.student_id,
    stu.student_code,
    stu.first_name,
    stu.last_name,
    s.school_name,
    stu.grade_level,
    stu.risk_score,
    stu.risk_decile,
    NTILE(4) OVER (ORDER BY stu.risk_score DESC) AS risk_quartile,
    NTILE(100) OVER (ORDER BY stu.risk_score DESC) AS risk_percentile,
    PERCENT_RANK() OVER (ORDER BY stu.risk_score) AS percentile_rank,
    CUME_DIST() OVER (ORDER BY stu.risk_score) AS cumulative_distribution
FROM students stu
JOIN schools s ON stu.school_id = s.school_id
WHERE stu.status = 'ACTIVE'
  AND stu.risk_score > 0;

-- ============================================================================
-- VIEW: High Risk Students (Top Decile)
-- ============================================================================

CREATE OR REPLACE VIEW vw_high_risk_students AS
SELECT 
    stu.student_id,
    stu.student_code,
    stu.first_name || ' ' || stu.last_name AS full_name,
    s.school_name,
    d.district_name,
    stu.grade_level,
    stu.gpa,
    stu.attendance_rate,
    stu.disciplinary_incidents,
    stu.risk_score,
    stu.risk_decile,
    CASE 
        WHEN stu.risk_score >= 80 THEN 'Critical'
        WHEN stu.risk_score >= 60 THEN 'High'
        WHEN stu.risk_score >= 40 THEN 'Moderate'
        ELSE 'Low'
    END AS risk_level,
    ROW_NUMBER() OVER (
        PARTITION BY s.school_id 
        ORDER BY stu.risk_score DESC
    ) AS school_rank
FROM students stu
JOIN schools s ON stu.school_id = s.school_id
JOIN districts d ON s.district_id = d.district_id
WHERE stu.status = 'ACTIVE'
  AND stu.risk_decile <= 3;  -- Top 30%

-- ============================================================================
-- VIEW: Dropout Reasons Analysis
-- ============================================================================

CREATE OR REPLACE VIEW vw_dropout_reasons_analysis AS
SELECT 
    dr.reason_code,
    dr.reason_name,
    dr.risk_weight,
    dr.is_preventable,
    COUNT(*) AS total_dropouts,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS reason_rank,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
    SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC ROWS UNBOUNDED PRECEDING) AS running_total,
    ROUND(
        SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC ROWS UNBOUNDED PRECEDING) * 100.0 
        / SUM(COUNT(*)) OVER ()
    , 2) AS cumulative_pct
FROM students stu
JOIN dropout_reasons dr ON stu.dropout_reason_id = dr.reason_id
WHERE stu.status = 'DROPPED'
GROUP BY dr.reason_id, dr.reason_code, dr.reason_name, dr.risk_weight, dr.is_preventable;

-- ============================================================================
-- VIEW: Moving Average of Dropout Rate
-- ============================================================================

CREATE OR REPLACE VIEW vw_dropout_moving_avg AS
SELECT 
    district_id,
    district_name,
    report_month,
    monthly_dropouts,
    AVG(monthly_dropouts) OVER (
        PARTITION BY district_id 
        ORDER BY report_month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3m,
    AVG(monthly_dropouts) OVER (
        PARTITION BY district_id 
        ORDER BY report_month 
        ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
    ) AS moving_avg_6m,
    AVG(monthly_dropouts) OVER (
        PARTITION BY district_id 
        ORDER BY report_month 
        ROWS BETWEEN 11 PRECEDING AND CURRENT ROW
    ) AS moving_avg_12m
FROM (
    SELECT 
        d.district_id,
        d.district_name,
        DATE_TRUNC('month', de.dropout_date) AS report_month,
        COUNT(*) AS monthly_dropouts
    FROM dropout_events de
    JOIN districts d ON de.district_id = d.district_id
    GROUP BY d.district_id, d.district_name, DATE_TRUNC('month', de.dropout_date)
) monthly_stats;

-- ============================================================================
-- VIEW: District Summary with Window Functions
-- ============================================================================

CREATE OR REPLACE VIEW vw_district_summary AS
SELECT 
    d.district_id,
    d.district_name,
    st.state_name,
    d.total_schools,
    d.total_students,
    COUNT(DISTINCT CASE WHEN stu.status = 'DROPPED' THEN stu.student_id END) AS total_dropouts,
    ROUND(
        COUNT(DISTINCT CASE WHEN stu.status = 'DROPPED' THEN stu.student_id END) * 100.0 
        / NULLIF(d.total_students, 0)
    , 2) AS dropout_rate,
    ROW_NUMBER() OVER (
        PARTITION BY st.state_id 
        ORDER BY COUNT(DISTINCT CASE WHEN stu.status = 'DROPPED' THEN stu.student_id END) DESC
    ) AS state_rank,
    NTILE(5) OVER (
        ORDER BY COUNT(DISTINCT CASE WHEN stu.status = 'DROPPED' THEN stu.student_id END) * 100.0 
                 / NULLIF(d.total_students, 0) DESC
    ) AS risk_quintile
FROM districts d
JOIN states st ON d.state_id = st.state_id
LEFT JOIN schools s ON d.district_id = s.district_id
LEFT JOIN students stu ON s.school_id = stu.school_id
GROUP BY d.district_id, d.district_name, st.state_id, st.state_name, 
         d.total_schools, d.total_students;

-- ============================================================================
-- VIEW: Grade Level Analysis
-- ============================================================================

CREATE OR REPLACE VIEW vw_grade_level_analysis AS
SELECT 
    grade_level,
    COUNT(*) AS total_dropouts,
    ROUND(AVG(gpa), 2) AS avg_gpa_at_dropout,
    ROUND(AVG(attendance_rate), 2) AS avg_attendance_at_dropout,
    ROUND(AVG(risk_score), 2) AS avg_risk_score,
    ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS dropout_rank,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_total,
    FIRST_VALUE(grade_level) OVER (ORDER BY COUNT(*) DESC) AS highest_dropout_grade,
    LAST_VALUE(grade_level) OVER (
        ORDER BY COUNT(*) DESC 
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS lowest_dropout_grade
FROM students
WHERE status = 'DROPPED'
GROUP BY grade_level
ORDER BY grade_level;

-- ============================================================================
-- VIEW: Intervention Effectiveness
-- ============================================================================

CREATE OR REPLACE VIEW vw_intervention_effectiveness AS
WITH intervention_outcomes AS (
    SELECT 
        i.intervention_type_id,
        it.type_name,
        stu.student_id,
        CASE WHEN stu.status = 'DROPPED' THEN 0 ELSE 1 END AS retained
    FROM interventions i
    JOIN intervention_types it ON i.intervention_type_id = it.intervention_type_id
    JOIN students stu ON i.student_id = stu.student_id
)
SELECT 
    intervention_type_id,
    type_name,
    COUNT(*) AS total_interventions,
    SUM(retained) AS students_retained,
    COUNT(*) - SUM(retained) AS students_dropped,
    ROUND(SUM(retained) * 100.0 / COUNT(*), 2) AS retention_rate,
    RANK() OVER (ORDER BY SUM(retained) * 100.0 / COUNT(*) DESC) AS effectiveness_rank
FROM intervention_outcomes
GROUP BY intervention_type_id, type_name;

-- ============================================================================
-- MATERIALIZED VIEW: School Rankings Snapshot
-- ============================================================================

CREATE MATERIALIZED VIEW mv_school_rankings AS
SELECT 
    s.school_id,
    s.school_name,
    d.district_id,
    d.district_name,
    stu.academic_year,
    COUNT(*) AS dropout_count,
    ROUND(COUNT(*) * 100.0 / NULLIF(s.enrollment, 0), 2) AS dropout_rate,
    ROW_NUMBER() OVER (
        PARTITION BY d.district_id, stu.academic_year 
        ORDER BY COUNT(*) DESC
    ) AS district_rank
FROM students stu
JOIN schools s ON stu.school_id = s.school_id
JOIN districts d ON s.district_id = d.district_id
WHERE stu.status = 'DROPPED'
GROUP BY s.school_id, s.school_name, d.district_id, d.district_name, 
         stu.academic_year, s.enrollment;

CREATE UNIQUE INDEX idx_mv_school_rankings ON mv_school_rankings(school_id, academic_year);

-- ============================================================================
-- MATERIALIZED VIEW: Risk Distribution Snapshot
-- ============================================================================

CREATE MATERIALIZED VIEW mv_risk_distribution AS
SELECT 
    s.school_id,
    s.school_name,
    d.district_id,
    d.district_name,
    stu.risk_decile,
    COUNT(*) AS student_count,
    ROUND(AVG(stu.risk_score), 2) AS avg_risk_score,
    ROUND(AVG(stu.gpa), 2) AS avg_gpa,
    ROUND(AVG(stu.attendance_rate), 2) AS avg_attendance
FROM students stu
JOIN schools s ON stu.school_id = s.school_id
JOIN districts d ON s.district_id = d.district_id
WHERE stu.status = 'ACTIVE'
GROUP BY s.school_id, s.school_name, d.district_id, d.district_name, stu.risk_decile;

CREATE UNIQUE INDEX idx_mv_risk_distribution ON mv_risk_distribution(school_id, risk_decile);

-- ============================================================================
-- Refresh Functions
-- ============================================================================

CREATE OR REPLACE FUNCTION refresh_analytics_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_school_rankings;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_risk_distribution;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- View Summary
-- ============================================================================
-- Regular Views: 10
--   vw_school_dropout_rankings - Core ranking query
--   vw_yoy_dropout_comparison - Year-over-year with LAG/LEAD
--   vw_cumulative_dropouts - Running totals
--   vw_student_risk_percentiles - NTILE and PERCENT_RANK
--   vw_high_risk_students - Top risk decile
--   vw_dropout_reasons_analysis - Reason breakdown
--   vw_dropout_moving_avg - Moving averages
--   vw_district_summary - District-level stats
--   vw_grade_level_analysis - Grade-level breakdown
--   vw_intervention_effectiveness - Intervention outcomes
--
-- Materialized Views: 2
--   mv_school_rankings - Cached rankings
--   mv_risk_distribution - Cached risk distribution
-- ============================================================================
