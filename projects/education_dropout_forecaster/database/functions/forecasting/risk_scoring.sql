-- ============================================================================
-- Risk Scoring Functions
-- Education Dropout Forecaster
-- PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- BATCH RISK SCORE CALCULATION
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_calculate_batch_risk_scores(
    p_school_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
    students_updated INTEGER,
    avg_risk_score NUMERIC,
    high_risk_count BIGINT,
    processing_time INTERVAL
) AS $$
DECLARE
    v_start_time TIMESTAMP := clock_timestamp();
    v_updated INTEGER := 0;
BEGIN
    -- Update all students in scope
    WITH risk_calc AS (
        SELECT 
            student_id,
            -- Attendance risk (weight: 25%)
            CASE 
                WHEN attendance_rate < 70 THEN 25
                WHEN attendance_rate < 80 THEN 20
                WHEN attendance_rate < 90 THEN 10
                ELSE 0
            END +
            -- GPA risk (weight: 25%)
            CASE 
                WHEN gpa < 1.5 THEN 25
                WHEN gpa < 2.0 THEN 20
                WHEN gpa < 2.5 THEN 10
                ELSE 0
            END +
            -- Discipline risk (weight: 20%)
            LEAST(disciplinary_incidents * 4, 20) +
            -- Retention risk (weight: 15%)
            CASE WHEN retained_grade THEN 15 ELSE 0 END +
            -- Socioeconomic risk (weight: 15%)
            LEAST(
                (CASE WHEN free_reduced_lunch THEN 5 ELSE 0 END) +
                (CASE WHEN homeless THEN 5 ELSE 0 END) +
                (CASE WHEN foster_care THEN 3 ELSE 0 END) +
                (CASE WHEN single_parent_household THEN 2 ELSE 0 END),
                15
            ) AS calculated_risk
        FROM students
        WHERE status = 'ACTIVE'
          AND (p_school_id IS NULL OR school_id = p_school_id)
    )
    UPDATE students s
    SET 
        risk_score = rc.calculated_risk,
        risk_decile = CASE 
            WHEN rc.calculated_risk >= 90 THEN 1
            WHEN rc.calculated_risk >= 80 THEN 2
            WHEN rc.calculated_risk >= 70 THEN 3
            WHEN rc.calculated_risk >= 60 THEN 4
            WHEN rc.calculated_risk >= 50 THEN 5
            WHEN rc.calculated_risk >= 40 THEN 6
            WHEN rc.calculated_risk >= 30 THEN 7
            WHEN rc.calculated_risk >= 20 THEN 8
            WHEN rc.calculated_risk >= 10 THEN 9
            ELSE 10
        END,
        updated_at = CURRENT_TIMESTAMP
    FROM risk_calc rc
    WHERE s.student_id = rc.student_id;
    
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    
    RETURN QUERY
    SELECT 
        v_updated::INTEGER AS students_updated,
        ROUND(AVG(risk_score), 2) AS avg_risk_score,
        COUNT(*) FILTER (WHERE risk_decile <= 3) AS high_risk_count,
        (clock_timestamp() - v_start_time)::INTERVAL AS processing_time
    FROM students
    WHERE status = 'ACTIVE'
      AND (p_school_id IS NULL OR school_id = p_school_id);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- RISK FACTOR BREAKDOWN
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_risk_factor_breakdown(
    p_student_id INTEGER
)
RETURNS TABLE (
    factor_name VARCHAR,
    factor_value NUMERIC,
    factor_weight NUMERIC,
    risk_contribution NUMERIC,
    percentile_rank NUMERIC,
    recommendation VARCHAR
) AS $$
DECLARE
    v_student RECORD;
BEGIN
    SELECT * INTO v_student FROM students WHERE student_id = p_student_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Student % not found', p_student_id;
    END IF;
    
    RETURN QUERY
    SELECT 
        f.factor_name::VARCHAR,
        f.factor_value,
        f.factor_weight,
        f.risk_contribution,
        ROUND(PERCENT_RANK() OVER (ORDER BY f.risk_contribution) * 100, 2) AS percentile_rank,
        f.recommendation::VARCHAR
    FROM (
        VALUES 
            ('Attendance Rate', 
             v_student.attendance_rate, 
             25.0::NUMERIC,
             CASE 
                 WHEN v_student.attendance_rate < 70 THEN 25
                 WHEN v_student.attendance_rate < 80 THEN 20
                 WHEN v_student.attendance_rate < 90 THEN 10
                 ELSE 0
             END::NUMERIC,
             CASE WHEN v_student.attendance_rate < 80 THEN 'Implement attendance monitoring plan' ELSE 'No action needed' END),
            ('GPA', 
             v_student.gpa, 
             25.0::NUMERIC,
             CASE 
                 WHEN v_student.gpa < 1.5 THEN 25
                 WHEN v_student.gpa < 2.0 THEN 20
                 WHEN v_student.gpa < 2.5 THEN 10
                 ELSE 0
             END::NUMERIC,
             CASE WHEN v_student.gpa < 2.0 THEN 'Enroll in tutoring program' ELSE 'No action needed' END),
            ('Disciplinary Incidents', 
             v_student.disciplinary_incidents::NUMERIC, 
             20.0::NUMERIC,
             LEAST(v_student.disciplinary_incidents * 4, 20)::NUMERIC,
             CASE WHEN v_student.disciplinary_incidents > 3 THEN 'Implement behavior intervention plan' ELSE 'No action needed' END),
            ('Grade Retention', 
             (CASE WHEN v_student.retained_grade THEN 1 ELSE 0 END)::NUMERIC, 
             15.0::NUMERIC,
             (CASE WHEN v_student.retained_grade THEN 15 ELSE 0 END)::NUMERIC,
             CASE WHEN v_student.retained_grade THEN 'Credit recovery program recommended' ELSE 'No action needed' END),
            ('Free/Reduced Lunch', 
             (CASE WHEN v_student.free_reduced_lunch THEN 1 ELSE 0 END)::NUMERIC, 
             5.0::NUMERIC,
             (CASE WHEN v_student.free_reduced_lunch THEN 5 ELSE 0 END)::NUMERIC,
             CASE WHEN v_student.free_reduced_lunch THEN 'Check for financial aid eligibility' ELSE 'No action needed' END),
            ('Homeless Status', 
             (CASE WHEN v_student.homeless THEN 1 ELSE 0 END)::NUMERIC, 
             5.0::NUMERIC,
             (CASE WHEN v_student.homeless THEN 5 ELSE 0 END)::NUMERIC,
             CASE WHEN v_student.homeless THEN 'Connect with housing support services' ELSE 'No action needed' END),
            ('Foster Care', 
             (CASE WHEN v_student.foster_care THEN 1 ELSE 0 END)::NUMERIC, 
             3.0::NUMERIC,
             (CASE WHEN v_student.foster_care THEN 3 ELSE 0 END)::NUMERIC,
             CASE WHEN v_student.foster_care THEN 'Assign dedicated counselor' ELSE 'No action needed' END),
            ('Single Parent Household', 
             (CASE WHEN v_student.single_parent_household THEN 1 ELSE 0 END)::NUMERIC, 
             2.0::NUMERIC,
             (CASE WHEN v_student.single_parent_household THEN 2 ELSE 0 END)::NUMERIC,
             'Ensure parent engagement outreach')
    ) AS f(factor_name, factor_value, factor_weight, risk_contribution, recommendation)
    ORDER BY f.risk_contribution DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- RISK TREND ANALYSIS
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_risk_trend_analysis(
    p_student_id INTEGER,
    p_months INTEGER DEFAULT 6
)
RETURNS TABLE (
    calculated_date DATE,
    risk_score NUMERIC,
    prev_score NUMERIC,
    score_change NUMERIC,
    trend VARCHAR,
    moving_avg NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        rsh.calculated_date,
        rsh.risk_score,
        LAG(rsh.risk_score, 1) OVER (ORDER BY rsh.calculated_date) AS prev_score,
        rsh.risk_score - LAG(rsh.risk_score, 1) OVER (ORDER BY rsh.calculated_date) AS score_change,
        CASE 
            WHEN rsh.risk_score > LAG(rsh.risk_score, 1) OVER (ORDER BY rsh.calculated_date) THEN 'INCREASING'
            WHEN rsh.risk_score < LAG(rsh.risk_score, 1) OVER (ORDER BY rsh.calculated_date) THEN 'DECREASING'
            ELSE 'STABLE'
        END::VARCHAR AS trend,
        ROUND(AVG(rsh.risk_score) OVER (
            ORDER BY rsh.calculated_date 
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ), 2) AS moving_avg
    FROM risk_score_history rsh
    WHERE rsh.student_id = p_student_id
      AND rsh.calculated_date >= CURRENT_DATE - (p_months || ' months')::INTERVAL
    ORDER BY rsh.calculated_date;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- COMPARATIVE RISK ANALYSIS
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_comparative_risk(
    p_student_id INTEGER
)
RETURNS TABLE (
    comparison_group VARCHAR,
    student_rank BIGINT,
    total_in_group BIGINT,
    percentile INTEGER,
    avg_group_score NUMERIC,
    student_score NUMERIC,
    score_diff NUMERIC
) AS $$
DECLARE
    v_student RECORD;
BEGIN
    SELECT * INTO v_student 
    FROM students s
    JOIN schools sc ON s.school_id = sc.school_id
    WHERE s.student_id = p_student_id;
    
    -- Compare within school
    RETURN QUERY
    SELECT 
        'Same School'::VARCHAR AS comparison_group,
        (SELECT COUNT(*) + 1 FROM students 
         WHERE school_id = v_student.school_id 
           AND status = 'ACTIVE' 
           AND risk_score > v_student.risk_score)::BIGINT AS student_rank,
        (SELECT COUNT(*) FROM students 
         WHERE school_id = v_student.school_id 
           AND status = 'ACTIVE')::BIGINT AS total_in_group,
        NTILE(100) OVER (ORDER BY v_student.risk_score DESC)::INTEGER AS percentile,
        (SELECT ROUND(AVG(risk_score), 2) FROM students 
         WHERE school_id = v_student.school_id AND status = 'ACTIVE') AS avg_group_score,
        v_student.risk_score AS student_score,
        v_student.risk_score - (SELECT AVG(risk_score) FROM students 
         WHERE school_id = v_student.school_id AND status = 'ACTIVE') AS score_diff;
    
    -- Compare within grade level
    RETURN QUERY
    SELECT 
        'Same Grade Level'::VARCHAR,
        (SELECT COUNT(*) + 1 FROM students 
         WHERE grade_level = v_student.grade_level 
           AND status = 'ACTIVE' 
           AND risk_score > v_student.risk_score)::BIGINT,
        (SELECT COUNT(*) FROM students 
         WHERE grade_level = v_student.grade_level 
           AND status = 'ACTIVE')::BIGINT,
        NTILE(100) OVER (ORDER BY v_student.risk_score DESC)::INTEGER,
        (SELECT ROUND(AVG(risk_score), 2) FROM students 
         WHERE grade_level = v_student.grade_level AND status = 'ACTIVE'),
        v_student.risk_score,
        v_student.risk_score - (SELECT AVG(risk_score) FROM students 
         WHERE grade_level = v_student.grade_level AND status = 'ACTIVE');
    
    -- Compare within district
    RETURN QUERY
    SELECT 
        'Same District'::VARCHAR,
        (SELECT COUNT(*) + 1 FROM students st
         JOIN schools sc ON st.school_id = sc.school_id
         WHERE sc.district_id = v_student.district_id 
           AND st.status = 'ACTIVE' 
           AND st.risk_score > v_student.risk_score)::BIGINT,
        (SELECT COUNT(*) FROM students st
         JOIN schools sc ON st.school_id = sc.school_id
         WHERE sc.district_id = v_student.district_id 
           AND st.status = 'ACTIVE')::BIGINT,
        NTILE(100) OVER (ORDER BY v_student.risk_score DESC)::INTEGER,
        (SELECT ROUND(AVG(st.risk_score), 2) FROM students st
         JOIN schools sc ON st.school_id = sc.school_id
         WHERE sc.district_id = v_student.district_id AND st.status = 'ACTIVE'),
        v_student.risk_score,
        v_student.risk_score - (SELECT AVG(st.risk_score) FROM students st
         JOIN schools sc ON st.school_id = sc.school_id
         WHERE sc.district_id = v_student.district_id AND st.status = 'ACTIVE');
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- EARLY WARNING SYSTEM
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_early_warning_alerts(
    p_school_id INTEGER DEFAULT NULL,
    p_days_lookback INTEGER DEFAULT 30
)
RETURNS TABLE (
    alert_type VARCHAR,
    student_id INTEGER,
    student_name VARCHAR,
    school_name VARCHAR,
    grade_level INTEGER,
    alert_detail VARCHAR,
    risk_score NUMERIC,
    priority INTEGER
) AS $$
BEGIN
    -- Attendance alerts
    RETURN QUERY
    SELECT 
        'ATTENDANCE_DECLINE'::VARCHAR AS alert_type,
        s.student_id,
        (s.first_name || ' ' || s.last_name)::VARCHAR AS student_name,
        sc.school_name,
        s.grade_level,
        FORMAT('Attendance dropped to %.1f%% (threshold: 80%%)', s.attendance_rate)::VARCHAR AS alert_detail,
        s.risk_score,
        CASE WHEN s.attendance_rate < 70 THEN 1 ELSE 2 END AS priority
    FROM students s
    JOIN schools sc ON s.school_id = sc.school_id
    WHERE s.status = 'ACTIVE'
      AND s.attendance_rate < 80
      AND (p_school_id IS NULL OR s.school_id = p_school_id);
    
    -- GPA alerts
    RETURN QUERY
    SELECT 
        'GPA_CRITICAL'::VARCHAR,
        s.student_id,
        (s.first_name || ' ' || s.last_name)::VARCHAR,
        sc.school_name,
        s.grade_level,
        FORMAT('GPA dropped to %.2f (threshold: 2.0)', s.gpa)::VARCHAR,
        s.risk_score,
        CASE WHEN s.gpa < 1.5 THEN 1 ELSE 2 END
    FROM students s
    JOIN schools sc ON s.school_id = sc.school_id
    WHERE s.status = 'ACTIVE'
      AND s.gpa < 2.0
      AND (p_school_id IS NULL OR s.school_id = p_school_id);
    
    -- Discipline alerts
    RETURN QUERY
    SELECT 
        'DISCIPLINE_SPIKE'::VARCHAR,
        s.student_id,
        (s.first_name || ' ' || s.last_name)::VARCHAR,
        sc.school_name,
        s.grade_level,
        FORMAT('%s disciplinary incidents in last %s days', 
               (SELECT COUNT(*) FROM disciplinary_records dr 
                WHERE dr.student_id = s.student_id 
                  AND dr.incident_date >= CURRENT_DATE - p_days_lookback),
               p_days_lookback)::VARCHAR,
        s.risk_score,
        1
    FROM students s
    JOIN schools sc ON s.school_id = sc.school_id
    WHERE s.status = 'ACTIVE'
      AND (p_school_id IS NULL OR s.school_id = p_school_id)
      AND (SELECT COUNT(*) FROM disciplinary_records dr 
           WHERE dr.student_id = s.student_id 
             AND dr.incident_date >= CURRENT_DATE - p_days_lookback) >= 3;
    
    -- Risk score alerts
    RETURN QUERY
    SELECT 
        'HIGH_RISK_SCORE'::VARCHAR,
        s.student_id,
        (s.first_name || ' ' || s.last_name)::VARCHAR,
        sc.school_name,
        s.grade_level,
        FORMAT('Risk score is %.1f (decile %s)', s.risk_score, s.risk_decile)::VARCHAR,
        s.risk_score,
        CASE WHEN s.risk_decile = 1 THEN 1 ELSE 2 END
    FROM students s
    JOIN schools sc ON s.school_id = sc.school_id
    WHERE s.status = 'ACTIVE'
      AND s.risk_decile <= 2
      AND (p_school_id IS NULL OR s.school_id = p_school_id);
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INTERVENTION EFFECTIVENESS SCORING
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_intervention_effectiveness()
RETURNS TABLE (
    intervention_type VARCHAR,
    total_students BIGINT,
    students_retained BIGINT,
    students_dropped BIGINT,
    retention_rate NUMERIC,
    effectiveness_rank BIGINT,
    avg_risk_before NUMERIC,
    avg_risk_after NUMERIC,
    risk_reduction NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH intervention_outcomes AS (
        SELECT 
            it.type_name,
            s.student_id,
            CASE WHEN s.status = 'ACTIVE' OR s.status = 'GRADUATED' THEN 1 ELSE 0 END AS retained,
            (SELECT rsh.risk_score FROM risk_score_history rsh 
             WHERE rsh.student_id = s.student_id 
               AND rsh.calculated_date <= i.start_date 
             ORDER BY rsh.calculated_date DESC LIMIT 1) AS risk_before,
            s.risk_score AS risk_current
        FROM interventions i
        JOIN intervention_types it ON i.intervention_type_id = it.intervention_type_id
        JOIN students s ON i.student_id = s.student_id
        WHERE i.status IN ('completed', 'active')
    )
    SELECT 
        io.type_name::VARCHAR AS intervention_type,
        COUNT(*)::BIGINT AS total_students,
        SUM(io.retained)::BIGINT AS students_retained,
        (COUNT(*) - SUM(io.retained))::BIGINT AS students_dropped,
        ROUND(SUM(io.retained) * 100.0 / COUNT(*), 2) AS retention_rate,
        RANK() OVER (ORDER BY SUM(io.retained) * 100.0 / COUNT(*) DESC)::BIGINT AS effectiveness_rank,
        ROUND(AVG(io.risk_before), 2) AS avg_risk_before,
        ROUND(AVG(io.risk_current), 2) AS avg_risk_after,
        ROUND(AVG(io.risk_before) - AVG(io.risk_current), 2) AS risk_reduction
    FROM intervention_outcomes io
    GROUP BY io.type_name
    ORDER BY retention_rate DESC;
END;
$$ LANGUAGE plpgsql;
