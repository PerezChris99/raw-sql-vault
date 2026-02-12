-- ============================================================================
-- Migration V002: Indexes
-- Education Dropout Forecaster - Performance Optimization
-- PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- STUDENT INDEXES
-- ============================================================================

-- Primary lookup patterns
CREATE INDEX idx_students_school ON students(school_id);
CREATE INDEX idx_students_status ON students(status);
CREATE INDEX idx_students_school_status ON students(school_id, status);
CREATE INDEX idx_students_school_year ON students(school_id, academic_year);

-- Window function support (ORDER BY columns)
CREATE INDEX idx_students_dropout_date ON students(dropout_date) WHERE dropout_date IS NOT NULL;
CREATE INDEX idx_students_school_dropout ON students(school_id, dropout_date DESC) WHERE status = 'DROPPED';

-- Risk analysis
CREATE INDEX idx_students_risk_score ON students(risk_score DESC) WHERE risk_score > 0;
CREATE INDEX idx_students_risk_decile ON students(risk_decile);
CREATE INDEX idx_students_attendance_rate ON students(attendance_rate);
CREATE INDEX idx_students_gpa ON students(gpa);

-- Demographic filtering
CREATE INDEX idx_students_grade_level ON students(grade_level);
CREATE INDEX idx_students_free_lunch ON students(free_reduced_lunch) WHERE free_reduced_lunch = TRUE;
CREATE INDEX idx_students_special_ed ON students(special_education) WHERE special_education = TRUE;

-- Full name search (using pg_trgm)
CREATE INDEX idx_students_name_trgm ON students USING gin (
    (first_name || ' ' || last_name) gin_trgm_ops
);

-- ============================================================================
-- SCHOOL/DISTRICT INDEXES
-- ============================================================================

CREATE INDEX idx_schools_district ON schools(district_id);
CREATE INDEX idx_schools_type ON schools(type_id);
CREATE INDEX idx_schools_active ON schools(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_schools_enrollment ON schools(enrollment DESC);

CREATE INDEX idx_districts_state ON districts(state_id);

-- ============================================================================
-- ATTENDANCE INDEXES
-- ============================================================================

CREATE INDEX idx_attendance_student ON attendance(student_id);
CREATE INDEX idx_attendance_date ON attendance(attendance_date DESC);
CREATE INDEX idx_attendance_student_date ON attendance(student_id, attendance_date DESC);
CREATE INDEX idx_attendance_status ON attendance(status);

-- For absence rate calculations
CREATE INDEX idx_attendance_absences ON attendance(student_id, attendance_date)
    WHERE status = 'absent';

-- ============================================================================
-- GRADES INDEXES
-- ============================================================================

CREATE INDEX idx_grades_student ON grades(student_id);
CREATE INDEX idx_grades_subject ON grades(subject_id);
CREATE INDEX idx_grades_student_year ON grades(student_id, academic_year);
CREATE INDEX idx_grades_failing ON grades(student_id) WHERE is_passing = FALSE;

-- ============================================================================
-- DISCIPLINARY INDEXES
-- ============================================================================

CREATE INDEX idx_disciplinary_student ON disciplinary_records(student_id);
CREATE INDEX idx_disciplinary_date ON disciplinary_records(incident_date DESC);
CREATE INDEX idx_disciplinary_type ON disciplinary_records(incident_type_id);
CREATE INDEX idx_disciplinary_severity ON disciplinary_records(student_id, incident_type_id);

-- ============================================================================
-- INTERVENTION INDEXES
-- ============================================================================

CREATE INDEX idx_interventions_student ON interventions(student_id);
CREATE INDEX idx_interventions_type ON interventions(intervention_type_id);
CREATE INDEX idx_interventions_active ON interventions(student_id, status) WHERE status = 'active';
CREATE INDEX idx_interventions_dates ON interventions(start_date, end_date);

-- ============================================================================
-- ANALYTICS INDEXES
-- ============================================================================

CREATE INDEX idx_annual_stats_school_year ON annual_school_stats(school_id, academic_year);
CREATE INDEX idx_annual_stats_year ON annual_school_stats(academic_year);
CREATE INDEX idx_annual_stats_dropout_rate ON annual_school_stats(dropout_rate DESC);

CREATE INDEX idx_risk_history_student ON risk_score_history(student_id);
CREATE INDEX idx_risk_history_date ON risk_score_history(calculated_date DESC);

CREATE INDEX idx_dropout_events_school ON dropout_events(school_id);
CREATE INDEX idx_dropout_events_district ON dropout_events(district_id);
CREATE INDEX idx_dropout_events_year ON dropout_events(academic_year);
CREATE INDEX idx_dropout_events_date ON dropout_events(dropout_date DESC);
CREATE INDEX idx_dropout_events_reason ON dropout_events(reason_id);

-- Composite for window function partitioning
CREATE INDEX idx_dropout_events_district_year ON dropout_events(district_id, academic_year, dropout_date DESC);
CREATE INDEX idx_dropout_events_school_year ON dropout_events(school_id, academic_year);

-- ============================================================================
-- AUDIT LOG INDEX
-- ============================================================================

CREATE INDEX idx_audit_table ON audit_log(table_name);
CREATE INDEX idx_audit_record ON audit_log(table_name, record_id);
CREATE INDEX idx_audit_date ON audit_log(changed_at DESC);

-- ============================================================================
-- PARTIAL INDEXES FOR COMMON FILTERS
-- ============================================================================

-- Active students only
CREATE INDEX idx_students_active ON students(school_id, grade_level) 
    WHERE status = 'ACTIVE';

-- Dropped students only (for dropout analysis)
CREATE INDEX idx_students_dropped ON students(school_id, dropout_date, dropout_reason_id) 
    WHERE status = 'DROPPED';

-- High-risk students
CREATE INDEX idx_students_high_risk ON students(school_id, risk_score DESC) 
    WHERE risk_score >= 50;

-- Title I schools
CREATE INDEX idx_schools_title1 ON schools(district_id) 
    WHERE is_title_i = TRUE;

-- ============================================================================
-- COVERING INDEXES FOR COMMON QUERIES
-- ============================================================================

-- School rankings query
CREATE INDEX idx_students_ranking_cover ON students(school_id, status, academic_year)
    INCLUDE (dropout_date, dropout_reason_id, grade_level);

-- Risk analysis query
CREATE INDEX idx_students_risk_cover ON students(school_id, risk_score DESC)
    INCLUDE (first_name, last_name, grade_level, gpa, attendance_rate);

-- ============================================================================
-- INDEX STATISTICS
-- ============================================================================
-- Run after data load:
-- ANALYZE students;
-- ANALYZE attendance;
-- ANALYZE grades;
-- ANALYZE disciplinary_records;
-- ANALYZE annual_school_stats;
-- ANALYZE dropout_events;
