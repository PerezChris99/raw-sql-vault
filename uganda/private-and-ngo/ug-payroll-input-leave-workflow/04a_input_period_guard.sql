-- Purpose: freeze payroll input rows after a period leaves the open/review state.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_hr_payroll.fn_guard_payroll_input_write()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path=pg_catalog,ug_hr_payroll AS $$
DECLARE v_period_id BIGINT; v_status TEXT;
BEGIN
 v_period_id:=CASE WHEN TG_OP='DELETE' THEN OLD.period_id ELSE NEW.period_id END;
 SELECT status INTO v_status FROM ug_hr_payroll.payroll_periods WHERE period_id=v_period_id FOR UPDATE;
 IF v_status NOT IN ('open','review') THEN
  RAISE EXCEPTION 'Payroll inputs are frozen once the period is approved or exported' USING ERRCODE='check_violation';
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END; $$;
DROP TRIGGER IF EXISTS trg_guard_payroll_input_write ON ug_hr_payroll.payroll_inputs;
CREATE TRIGGER trg_guard_payroll_input_write
BEFORE INSERT OR UPDATE OR DELETE ON ug_hr_payroll.payroll_inputs
FOR EACH ROW EXECUTE FUNCTION ug_hr_payroll.fn_guard_payroll_input_write();
