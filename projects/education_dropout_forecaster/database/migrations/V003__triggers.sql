-- ============================================================================
-- Migration V003: Triggers
-- Education Dropout Forecaster - Automation & Audit
-- PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- UPDATED_AT TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to tables with updated_at
CREATE TRIGGER trg_districts_updated
    BEFORE UPDATE ON districts
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_schools_updated
    BEFORE UPDATE ON schools
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_students_updated
    BEFORE UPDATE ON students
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER trg_interventions_updated
    BEFORE UPDATE ON interventions
    FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ============================================================================
-- AUTO-GENERATE STUDENT CODE
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_student_code()
RETURNS TRIGGER AS $$
DECLARE
    school_code VARCHAR(20);
    seq_num INTEGER;
BEGIN
    IF NEW.student_code IS NULL OR NEW.student_code = '' THEN
        SELECT s.school_code INTO school_code
        FROM schools s WHERE s.school_id = NEW.school_id;
        
        SELECT COUNT(*) + 1 INTO seq_num
        FROM students WHERE school_id = NEW.school_id;
        
        NEW.student_code := school_code || '-' || 
                           TO_CHAR(NEW.academic_year, 'FM0000') || '-' ||
                           LPAD(seq_num::TEXT, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_student_code_generate
    BEFORE INSERT ON students
    FOR EACH ROW EXECUTE FUNCTION generate_student_code();

-- ============================================================================
-- DROPOUT EVENT LOGGING
-- ============================================================================

CREATE OR REPLACE FUNCTION log_dropout_event()
RETURNS TRIGGER AS $$
DECLARE
    v_district_id INTEGER;
    v_interventions INTEGER;
BEGIN
    -- Only trigger when status changes to DROPPED
    IF NEW.status = 'DROPPED' AND (OLD.status IS NULL OR OLD.status != 'DROPPED') THEN
        -- Get district_id
        SELECT district_id INTO v_district_id
        FROM schools WHERE school_id = NEW.school_id;
        
        -- Count interventions received
        SELECT COUNT(*) INTO v_interventions
        FROM interventions WHERE student_id = NEW.student_id;
        
        -- Insert dropout event record
        INSERT INTO dropout_events (
            student_id,
            school_id,
            district_id,
            academic_year,
            dropout_date,
            reason_id,
            grade_level,
            gpa_at_dropout,
            attendance_at_dropout,
            risk_score_at_dropout,
            interventions_received
        ) VALUES (
            NEW.student_id,
            NEW.school_id,
            v_district_id,
            NEW.academic_year,
            COALESCE(NEW.dropout_date, CURRENT_DATE),
            NEW.dropout_reason_id,
            NEW.grade_level,
            NEW.gpa,
            NEW.attendance_rate,
            NEW.risk_score,
            v_interventions
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_student_dropout_log
    AFTER UPDATE ON students
    FOR EACH ROW EXECUTE FUNCTION log_dropout_event();

-- ============================================================================
-- RISK SCORE CALCULATION
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_risk_score()
RETURNS TRIGGER AS $$
DECLARE
    v_attendance_risk DECIMAL(5,2) := 0;
    v_gpa_risk DECIMAL(5,2) := 0;
    v_discipline_risk DECIMAL(5,2) := 0;
    v_retention_risk DECIMAL(5,2) := 0;
    v_socio_risk DECIMAL(5,2) := 0;
    v_total_risk DECIMAL(5,2);
BEGIN
    -- Attendance risk (weight: 25%)
    IF NEW.attendance_rate IS NOT NULL THEN
        v_attendance_risk := CASE 
            WHEN NEW.attendance_rate < 70 THEN 25
            WHEN NEW.attendance_rate < 80 THEN 20
            WHEN NEW.attendance_rate < 90 THEN 10
            ELSE 0
        END;
    END IF;
    
    -- GPA risk (weight: 25%)
    IF NEW.gpa IS NOT NULL THEN
        v_gpa_risk := CASE 
            WHEN NEW.gpa < 1.5 THEN 25
            WHEN NEW.gpa < 2.0 THEN 20
            WHEN NEW.gpa < 2.5 THEN 10
            ELSE 0
        END;
    END IF;
    
    -- Discipline risk (weight: 20%)
    v_discipline_risk := LEAST(NEW.disciplinary_incidents * 4, 20);
    
    -- Prior retention risk (weight: 15%)
    IF NEW.retained_grade THEN
        v_retention_risk := 15;
    END IF;
    
    -- Socioeconomic risk (weight: 15%)
    IF NEW.free_reduced_lunch THEN v_socio_risk := v_socio_risk + 5; END IF;
    IF NEW.homeless THEN v_socio_risk := v_socio_risk + 5; END IF;
    IF NEW.foster_care THEN v_socio_risk := v_socio_risk + 3; END IF;
    IF NEW.single_parent_household THEN v_socio_risk := v_socio_risk + 2; END IF;
    v_socio_risk := LEAST(v_socio_risk, 15);
    
    -- Calculate total (0-100 scale)
    v_total_risk := v_attendance_risk + v_gpa_risk + v_discipline_risk + 
                    v_retention_risk + v_socio_risk;
    
    NEW.risk_score := v_total_risk;
    NEW.risk_decile := CASE 
        WHEN v_total_risk >= 90 THEN 1
        WHEN v_total_risk >= 80 THEN 2
        WHEN v_total_risk >= 70 THEN 3
        WHEN v_total_risk >= 60 THEN 4
        WHEN v_total_risk >= 50 THEN 5
        WHEN v_total_risk >= 40 THEN 6
        WHEN v_total_risk >= 30 THEN 7
        WHEN v_total_risk >= 20 THEN 8
        WHEN v_total_risk >= 10 THEN 9
        ELSE 10
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_student_risk_calculate
    BEFORE INSERT OR UPDATE OF gpa, attendance_rate, disciplinary_incidents, 
                              retained_grade, free_reduced_lunch, homeless, 
                              foster_care, single_parent_household
    ON students
    FOR EACH ROW EXECUTE FUNCTION calculate_risk_score();

-- ============================================================================
-- SCHOOL ENROLLMENT COUNTER
-- ============================================================================

CREATE OR REPLACE FUNCTION update_school_enrollment()
RETURNS TRIGGER AS $$
BEGIN
    -- Update enrollment count for affected school(s)
    IF TG_OP = 'INSERT' THEN
        UPDATE schools SET enrollment = (
            SELECT COUNT(*) FROM students 
            WHERE school_id = NEW.school_id AND status = 'ACTIVE'
        ) WHERE school_id = NEW.school_id;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.school_id != NEW.school_id OR OLD.status != NEW.status THEN
            UPDATE schools SET enrollment = (
                SELECT COUNT(*) FROM students 
                WHERE school_id = OLD.school_id AND status = 'ACTIVE'
            ) WHERE school_id = OLD.school_id;
            
            UPDATE schools SET enrollment = (
                SELECT COUNT(*) FROM students 
                WHERE school_id = NEW.school_id AND status = 'ACTIVE'
            ) WHERE school_id = NEW.school_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE schools SET enrollment = (
            SELECT COUNT(*) FROM students 
            WHERE school_id = OLD.school_id AND status = 'ACTIVE'
        ) WHERE school_id = OLD.school_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enrollment_update
    AFTER INSERT OR UPDATE OR DELETE ON students
    FOR EACH ROW EXECUTE FUNCTION update_school_enrollment();

-- ============================================================================
-- DISTRICT SCHOOL COUNTER
-- ============================================================================

CREATE OR REPLACE FUNCTION update_district_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        UPDATE districts SET 
            total_schools = (
                SELECT COUNT(*) FROM schools 
                WHERE district_id = NEW.district_id AND is_active = TRUE
            ),
            total_students = (
                SELECT COALESCE(SUM(enrollment), 0) FROM schools 
                WHERE district_id = NEW.district_id AND is_active = TRUE
            )
        WHERE district_id = NEW.district_id;
        
        IF TG_OP = 'UPDATE' AND OLD.district_id != NEW.district_id THEN
            UPDATE districts SET 
                total_schools = (
                    SELECT COUNT(*) FROM schools 
                    WHERE district_id = OLD.district_id AND is_active = TRUE
                ),
                total_students = (
                    SELECT COALESCE(SUM(enrollment), 0) FROM schools 
                    WHERE district_id = OLD.district_id AND is_active = TRUE
                )
            WHERE district_id = OLD.district_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE districts SET 
            total_schools = (
                SELECT COUNT(*) FROM schools 
                WHERE district_id = OLD.district_id AND is_active = TRUE
            ),
            total_students = (
                SELECT COALESCE(SUM(enrollment), 0) FROM schools 
                WHERE district_id = OLD.district_id AND is_active = TRUE
            )
        WHERE district_id = OLD.district_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_district_counts_update
    AFTER INSERT OR UPDATE OR DELETE ON schools
    FOR EACH ROW EXECUTE FUNCTION update_district_counts();

-- ============================================================================
-- ATTENDANCE RATE SYNC
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_attendance_rate()
RETURNS TRIGGER AS $$
DECLARE
    v_total_days INTEGER;
    v_present_days INTEGER;
    v_rate DECIMAL(5,2);
BEGIN
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'present' OR status = 'tardy')
    INTO v_total_days, v_present_days
    FROM attendance
    WHERE student_id = NEW.student_id;
    
    IF v_total_days > 0 THEN
        v_rate := (v_present_days * 100.0) / v_total_days;
        
        UPDATE students 
        SET attendance_rate = v_rate
        WHERE student_id = NEW.student_id;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_attendance_rate_sync
    AFTER INSERT OR UPDATE OR DELETE ON attendance
    FOR EACH ROW EXECUTE FUNCTION sync_attendance_rate();

-- ============================================================================
-- GPA SYNC
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_gpa()
RETURNS TRIGGER AS $$
DECLARE
    v_gpa DECIMAL(3,2);
BEGIN
    SELECT ROUND(AVG(grade_value / 25.0), 2) INTO v_gpa  -- Convert 0-100 to 0-4 scale
    FROM grades
    WHERE student_id = NEW.student_id
      AND academic_year = (SELECT MAX(academic_year) FROM grades WHERE student_id = NEW.student_id);
    
    IF v_gpa IS NOT NULL THEN
        UPDATE students SET gpa = v_gpa WHERE student_id = NEW.student_id;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_gpa_sync
    AFTER INSERT OR UPDATE ON grades
    FOR EACH ROW EXECUTE FUNCTION sync_gpa();

-- ============================================================================
-- DISCIPLINARY INCIDENT COUNTER
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_disciplinary_count()
RETURNS TRIGGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF TG_OP = 'DELETE' THEN
        SELECT COUNT(*) INTO v_count
        FROM disciplinary_records WHERE student_id = OLD.student_id;
        UPDATE students SET disciplinary_incidents = v_count WHERE student_id = OLD.student_id;
    ELSE
        SELECT COUNT(*) INTO v_count
        FROM disciplinary_records WHERE student_id = NEW.student_id;
        UPDATE students SET disciplinary_incidents = v_count WHERE student_id = NEW.student_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_disciplinary_count_sync
    AFTER INSERT OR UPDATE OR DELETE ON disciplinary_records
    FOR EACH ROW EXECUTE FUNCTION sync_disciplinary_count();

-- ============================================================================
-- AUDIT LOGGING
-- ============================================================================

CREATE OR REPLACE FUNCTION audit_student_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, action, new_values)
        VALUES ('students', NEW.student_id, 'INSERT', row_to_json(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_values, new_values)
        VALUES ('students', NEW.student_id, 'UPDATE', row_to_json(OLD), row_to_json(NEW));
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_values)
        VALUES ('students', OLD.student_id, 'DELETE', row_to_json(OLD));
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_student_audit
    AFTER INSERT OR UPDATE OR DELETE ON students
    FOR EACH ROW EXECUTE FUNCTION audit_student_changes();

-- ============================================================================
-- RISK SCORE HISTORY
-- ============================================================================

CREATE OR REPLACE FUNCTION log_risk_score_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.risk_score IS DISTINCT FROM NEW.risk_score THEN
        INSERT INTO risk_score_history (student_id, calculated_date, risk_score, risk_factors)
        VALUES (
            NEW.student_id,
            CURRENT_DATE,
            NEW.risk_score,
            jsonb_build_object(
                'gpa', NEW.gpa,
                'attendance_rate', NEW.attendance_rate,
                'disciplinary_incidents', NEW.disciplinary_incidents,
                'retained_grade', NEW.retained_grade,
                'free_reduced_lunch', NEW.free_reduced_lunch,
                'homeless', NEW.homeless,
                'foster_care', NEW.foster_care,
                'single_parent_household', NEW.single_parent_household
            )
        );
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_risk_score_history
    AFTER UPDATE OF risk_score ON students
    FOR EACH ROW EXECUTE FUNCTION log_risk_score_change();
