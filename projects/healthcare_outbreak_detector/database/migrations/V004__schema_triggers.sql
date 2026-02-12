-- ============================================================================
-- Migration: V004__schema_triggers.sql
-- Purpose: Create triggers for automated data management
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- UPDATED_AT TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
DO $$
DECLARE
    t TEXT;
BEGIN
    FOR t IN 
        SELECT table_name FROM information_schema.columns 
        WHERE table_schema = 'surveillance' 
        AND column_name = 'updated_at'
    LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS trg_%s_update_timestamp ON surveillance.%I;
            CREATE TRIGGER trg_%s_update_timestamp
                BEFORE UPDATE ON surveillance.%I
                FOR EACH ROW
                EXECUTE FUNCTION surveillance.update_timestamp();
        ', t, t, t, t);
    END LOOP;
END $$;

-- ============================================================================
-- PATIENT CODE AUTO-GENERATION
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.generate_patient_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.patient_code IS NULL THEN
        NEW.patient_code := 'PT-' || 
            TO_CHAR(CURRENT_DATE, 'YYYY') || '-' ||
            LPAD(nextval('surveillance.patient_code_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS surveillance.patient_code_seq START 1;

CREATE TRIGGER trg_patient_code_generate
    BEFORE INSERT ON surveillance.patients
    FOR EACH ROW
    EXECUTE FUNCTION surveillance.generate_patient_code();

-- ============================================================================
-- CASE NUMBER AUTO-GENERATION
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.generate_case_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.case_number IS NULL THEN
        NEW.case_number := 'CS-' || 
            TO_CHAR(CURRENT_DATE, 'YYYY') || '-' ||
            LPAD(nextval('surveillance.case_number_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS surveillance.case_number_seq START 1;

CREATE TRIGGER trg_case_number_generate
    BEFORE INSERT ON surveillance.cases
    FOR EACH ROW
    EXECUTE FUNCTION surveillance.generate_case_number();

-- ============================================================================
-- PATIENT SEARCH VECTOR
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.update_patient_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := to_tsvector('english',
        COALESCE(NEW.first_name, '') || ' ' ||
        COALESCE(NEW.last_name, '') || ' ' ||
        COALESCE(NEW.patient_code, '') || ' ' ||
        COALESCE(NEW.phone, '') || ' ' ||
        COALESCE(NEW.national_id, '') || ' ' ||
        COALESCE(NEW.village, '')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_patient_search_vector
    BEFORE INSERT OR UPDATE ON surveillance.patients
    FOR EACH ROW
    EXECUTE FUNCTION surveillance.update_patient_search_vector();

-- ============================================================================
-- AGE CALCULATION FROM DOB
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.calculate_patient_age()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.date_of_birth IS NOT NULL AND NEW.age_years IS NULL THEN
        NEW.age_years := EXTRACT(YEAR FROM age(NEW.date_of_birth))::INTEGER;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_patient_calculate_age
    BEFORE INSERT OR UPDATE ON surveillance.patients
    FOR EACH ROW
    EXECUTE FUNCTION surveillance.calculate_patient_age();

-- ============================================================================
-- AUDIT LOGGING TRIGGER
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.audit_trigger_function()
RETURNS TRIGGER AS $$
DECLARE
    v_old_data JSONB;
    v_new_data JSONB;
    v_record_id TEXT;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);
        -- Get primary key value
        v_record_id := CASE 
            WHEN v_new_data ? 'case_id' THEN (v_new_data->>'case_id')
            WHEN v_new_data ? 'patient_id' THEN (v_new_data->>'patient_id')
            WHEN v_new_data ? 'alert_id' THEN (v_new_data->>'alert_id')
            WHEN v_new_data ? 'outbreak_id' THEN (v_new_data->>'outbreak_id')
            ELSE 'unknown'
        END;
        
        INSERT INTO surveillance.audit_log (table_name, record_id, operation, old_values, new_values, changed_by)
        VALUES (TG_TABLE_NAME, v_record_id, TG_OP, v_old_data, v_new_data, current_user);
        RETURN NEW;
        
    ELSIF TG_OP = 'DELETE' THEN
        v_old_data := to_jsonb(OLD);
        v_record_id := CASE 
            WHEN v_old_data ? 'case_id' THEN (v_old_data->>'case_id')
            WHEN v_old_data ? 'patient_id' THEN (v_old_data->>'patient_id')
            ELSE 'unknown'
        END;
        
        INSERT INTO surveillance.audit_log (table_name, record_id, operation, old_values, changed_by)
        VALUES (TG_TABLE_NAME, v_record_id, TG_OP, v_old_data, current_user);
        RETURN OLD;
        
    ELSIF TG_OP = 'INSERT' THEN
        v_new_data := to_jsonb(NEW);
        v_record_id := CASE 
            WHEN v_new_data ? 'case_id' THEN (v_new_data->>'case_id')
            WHEN v_new_data ? 'patient_id' THEN (v_new_data->>'patient_id')
            ELSE 'unknown'
        END;
        
        INSERT INTO surveillance.audit_log (table_name, record_id, operation, new_values, changed_by)
        VALUES (TG_TABLE_NAME, v_record_id, TG_OP, v_new_data, current_user);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit triggers to critical tables
CREATE TRIGGER trg_cases_audit
    AFTER INSERT OR UPDATE OR DELETE ON surveillance.cases
    FOR EACH ROW EXECUTE FUNCTION surveillance.audit_trigger_function();

CREATE TRIGGER trg_patients_audit
    AFTER INSERT OR UPDATE OR DELETE ON surveillance.patients
    FOR EACH ROW EXECUTE FUNCTION surveillance.audit_trigger_function();

CREATE TRIGGER trg_outbreaks_audit
    AFTER INSERT OR UPDATE OR DELETE ON surveillance.outbreaks
    FOR EACH ROW EXECUTE FUNCTION surveillance.audit_trigger_function();

CREATE TRIGGER trg_alerts_audit
    AFTER INSERT OR UPDATE OR DELETE ON surveillance.alerts
    FOR EACH ROW EXECUTE FUNCTION surveillance.audit_trigger_function();

-- ============================================================================
-- SPECIMEN CODE AUTO-GENERATION
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.generate_specimen_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.specimen_code IS NULL THEN
        NEW.specimen_code := 'SPEC-' || 
            TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' ||
            LPAD(nextval('surveillance.specimen_code_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS surveillance.specimen_code_seq START 1;

CREATE TRIGGER trg_specimen_code_generate
    BEFORE INSERT ON surveillance.specimens
    FOR EACH ROW
    EXECUTE FUNCTION surveillance.generate_specimen_code();

-- ============================================================================
-- LAB TEST CODE AUTO-GENERATION
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.generate_test_code()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.test_code IS NULL THEN
        NEW.test_code := 'TEST-' || 
            TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' ||
            LPAD(nextval('surveillance.test_code_seq')::TEXT, 6, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE IF NOT EXISTS surveillance.test_code_seq START 1;

CREATE TRIGGER trg_test_code_generate
    BEFORE INSERT ON surveillance.lab_tests
    FOR EACH ROW
    EXECUTE FUNCTION surveillance.generate_test_code();
