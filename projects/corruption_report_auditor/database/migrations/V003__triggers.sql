-- ============================================================================
-- Corruption Report Auditor - Triggers
-- Version: V003
-- Description: Automated triggers for data integrity and temporal tracking
-- ============================================================================

-- ============================================================================
-- Updated At Trigger
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with updated_at
CREATE TRIGGER trg_reports_updated_at
    BEFORE UPDATE ON reports
    FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

CREATE TRIGGER trg_departments_updated_at
    BEFORE UPDATE ON departments
    FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

CREATE TRIGGER trg_officers_updated_at
    BEFORE UPDATE ON officers
    FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

CREATE TRIGGER trg_daily_stats_updated_at
    BEFORE UPDATE ON daily_statistics
    FOR EACH ROW EXECUTE FUNCTION fn_update_updated_at();

-- ============================================================================
-- Report Number Generation
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_set_report_number()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.report_number IS NULL THEN
        NEW.report_number = fn_generate_report_number();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reports_set_number
    BEFORE INSERT ON reports
    FOR EACH ROW EXECUTE FUNCTION fn_set_report_number();

-- ============================================================================
-- Status Change History Tracking
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_track_status_change()
RETURNS TRIGGER AS $$
DECLARE
    v_time_in_status INTERVAL;
BEGIN
    -- Only track if status actually changed
    IF OLD.status_id IS DISTINCT FROM NEW.status_id THEN
        -- Calculate time in previous status
        SELECT CURRENT_TIMESTAMP - MAX(sh.changed_at)
        INTO v_time_in_status
        FROM status_history sh
        WHERE sh.report_id = NEW.report_id;
        
        -- If no history, use reported_date
        IF v_time_in_status IS NULL THEN
            v_time_in_status = CURRENT_TIMESTAMP - OLD.reported_date;
        END IF;
        
        -- Insert history record
        INSERT INTO status_history (
            report_id, 
            old_status_id, 
            new_status_id, 
            changed_at,
            changed_by,
            time_in_previous_status
        ) VALUES (
            NEW.report_id,
            OLD.status_id,
            NEW.status_id,
            CURRENT_TIMESTAMP,
            NEW.updated_by,
            v_time_in_status
        );
        
        -- Update last activity date
        NEW.last_activity_date = CURRENT_TIMESTAMP;
        
        -- Set resolution date if moving to terminal status
        IF EXISTS (SELECT 1 FROM statuses WHERE status_id = NEW.status_id AND is_terminal = TRUE) THEN
            IF NEW.resolution_date IS NULL THEN
                NEW.resolution_date = CURRENT_TIMESTAMP;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reports_status_change
    BEFORE UPDATE ON reports
    FOR EACH ROW EXECUTE FUNCTION fn_track_status_change();

-- ============================================================================
-- SLA Target Date Calculation
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_calculate_target_resolution()
RETURNS TRIGGER AS $$
DECLARE
    v_sla_days INTEGER;
BEGIN
    -- Get SLA days from category
    SELECT sla_days INTO v_sla_days
    FROM categories
    WHERE category_id = NEW.category_id;
    
    -- Adjust by priority (critical = 50%, low = 150% of normal SLA)
    v_sla_days = v_sla_days * (0.5 + (NEW.priority - 1) * 0.25);
    
    -- Set target resolution date
    NEW.target_resolution_date = (NEW.reported_date + (v_sla_days || ' days')::INTERVAL)::DATE;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reports_set_target_date
    BEFORE INSERT ON reports
    FOR EACH ROW EXECUTE FUNCTION fn_calculate_target_resolution();

-- ============================================================================
-- Case Action Activity Update
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_update_report_activity()
RETURNS TRIGGER AS $$
BEGIN
    -- Update last activity date on report
    UPDATE reports
    SET last_activity_date = CURRENT_TIMESTAMP
    WHERE report_id = NEW.report_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_case_actions_update_activity
    AFTER INSERT ON case_actions
    FOR EACH ROW EXECUTE FUNCTION fn_update_report_activity();

CREATE TRIGGER trg_escalations_update_activity
    AFTER INSERT ON escalations
    FOR EACH ROW EXECUTE FUNCTION fn_update_report_activity();

CREATE TRIGGER trg_evidence_update_activity
    AFTER INSERT ON evidence
    FOR EACH ROW EXECUTE FUNCTION fn_update_report_activity();

-- ============================================================================
-- Daily Statistics Aggregation
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_update_daily_statistics()
RETURNS TRIGGER AS $$
DECLARE
    v_stat_date DATE;
BEGIN
    -- Determine which date to update based on operation
    IF TG_OP = 'DELETE' THEN
        v_stat_date = OLD.reported_date::DATE;
    ELSE
        v_stat_date = NEW.reported_date::DATE;
    END IF;
    
    -- Upsert daily statistics
    INSERT INTO daily_statistics (stat_date, new_reports, resolved_reports, total_open_reports)
    SELECT 
        v_stat_date,
        COUNT(*) FILTER (WHERE reported_date::DATE = v_stat_date),
        COUNT(*) FILTER (WHERE resolution_date::DATE = v_stat_date),
        COUNT(*) FILTER (WHERE status_id IN (
            SELECT status_id FROM statuses WHERE is_terminal = FALSE
        ))
    FROM reports
    ON CONFLICT (stat_date) DO UPDATE SET
        new_reports = EXCLUDED.new_reports,
        resolved_reports = EXCLUDED.resolved_reports,
        total_open_reports = EXCLUDED.total_open_reports,
        updated_at = CURRENT_TIMESTAMP;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reports_update_daily_stats
    AFTER INSERT OR UPDATE OR DELETE ON reports
    FOR EACH ROW EXECUTE FUNCTION fn_update_daily_statistics();

-- ============================================================================
-- Audit Logging
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_audit_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_changed_fields TEXT[] := '{}';
    v_old_values JSONB;
    v_new_values JSONB;
    v_key TEXT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_new_values = row_to_json(NEW)::JSONB - 'created_at' - 'updated_at';
        INSERT INTO audit_log (table_name, record_id, operation, new_values, performed_by, performed_at)
        VALUES (TG_TABLE_NAME, NEW.report_id, TG_OP, v_new_values, NEW.created_by, CURRENT_TIMESTAMP);
        
    ELSIF TG_OP = 'UPDATE' THEN
        v_old_values = row_to_json(OLD)::JSONB - 'created_at' - 'updated_at';
        v_new_values = row_to_json(NEW)::JSONB - 'created_at' - 'updated_at';
        
        -- Find changed fields
        FOR v_key IN SELECT jsonb_object_keys(v_new_values)
        LOOP
            IF v_old_values->v_key IS DISTINCT FROM v_new_values->v_key THEN
                v_changed_fields = array_append(v_changed_fields, v_key);
            END IF;
        END LOOP;
        
        -- Only log if there are actual changes
        IF array_length(v_changed_fields, 1) > 0 THEN
            INSERT INTO audit_log (table_name, record_id, operation, old_values, new_values, changed_fields, performed_by, performed_at)
            VALUES (TG_TABLE_NAME, NEW.report_id, TG_OP, v_old_values, v_new_values, v_changed_fields, NEW.updated_by, CURRENT_TIMESTAMP);
        END IF;
        
    ELSIF TG_OP = 'DELETE' THEN
        v_old_values = row_to_json(OLD)::JSONB - 'created_at' - 'updated_at';
        INSERT INTO audit_log (table_name, record_id, operation, old_values, performed_at)
        VALUES (TG_TABLE_NAME, OLD.report_id, TG_OP, v_old_values, CURRENT_TIMESTAMP);
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reports_audit
    AFTER INSERT OR UPDATE OR DELETE ON reports
    FOR EACH ROW EXECUTE FUNCTION fn_audit_changes();

-- ============================================================================
-- Escalation Priority Bump
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_escalation_priority_bump()
RETURNS TRIGGER AS $$
BEGIN
    -- Store the before priority
    NEW.priority_before = (SELECT priority FROM reports WHERE report_id = NEW.report_id);
    
    -- Bump priority by 1 level (minimum 1)
    UPDATE reports
    SET priority = GREATEST(1, priority - 1),
        updated_at = CURRENT_TIMESTAMP
    WHERE report_id = NEW.report_id;
    
    -- Store the after priority
    NEW.priority_after = (SELECT priority FROM reports WHERE report_id = NEW.report_id);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_escalations_priority_bump
    BEFORE INSERT ON escalations
    FOR EACH ROW EXECUTE FUNCTION fn_escalation_priority_bump();

-- ============================================================================
-- Prevent Terminal State Reversal
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_prevent_terminal_reversal()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if old status was terminal
    IF EXISTS (SELECT 1 FROM statuses WHERE status_id = OLD.status_id AND is_terminal = TRUE) THEN
        -- Only allow if new status is also terminal (e.g., reopened -> dismissed)
        IF NOT EXISTS (SELECT 1 FROM statuses WHERE status_id = NEW.status_id AND is_terminal = TRUE) THEN
            -- Allow reopening by creating a new report referencing the old one
            RAISE EXCEPTION 'Cannot reopen a closed case. Create a follow-up report instead.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: Enable this trigger only if business rules require it
-- CREATE TRIGGER trg_reports_no_terminal_reversal
--     BEFORE UPDATE ON reports
--     FOR EACH ROW EXECUTE FUNCTION fn_prevent_terminal_reversal();

-- ============================================================================
-- SLA Breach Alert (Notifies when approaching SLA)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_check_sla_breach()
RETURNS TRIGGER AS $$
DECLARE
    v_days_remaining INTEGER;
BEGIN
    -- Only check for non-terminal statuses
    IF NOT EXISTS (SELECT 1 FROM statuses WHERE status_id = NEW.status_id AND is_terminal = TRUE) THEN
        v_days_remaining = NEW.target_resolution_date - CURRENT_DATE;
        
        -- Raise notice if within 3 days of SLA breach
        IF v_days_remaining <= 3 AND v_days_remaining >= 0 THEN
            RAISE NOTICE 'SLA WARNING: Report % has only % days until SLA breach', 
                NEW.report_number, v_days_remaining;
        ELSIF v_days_remaining < 0 THEN
            RAISE NOTICE 'SLA BREACH: Report % is % days past SLA target', 
                NEW.report_number, ABS(v_days_remaining);
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reports_check_sla
    AFTER INSERT OR UPDATE ON reports
    FOR EACH ROW EXECUTE FUNCTION fn_check_sla_breach();
