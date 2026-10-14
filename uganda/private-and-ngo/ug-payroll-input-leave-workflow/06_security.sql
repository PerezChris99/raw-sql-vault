-- Purpose: HR, payroll input clerk and payroll reviewer role separation.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_hr_reader') THEN CREATE ROLE ug_hr_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_payroll_input_clerk') THEN CREATE ROLE ug_payroll_input_clerk NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_payroll_reviewer') THEN CREATE ROLE ug_payroll_reviewer NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_hr_payroll FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_hr_payroll TO ug_hr_reader,ug_payroll_input_clerk,ug_payroll_reviewer;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_hr_payroll FROM PUBLIC;
GRANT SELECT ON ug_hr_payroll.v_leave_review_queue TO ug_hr_reader;
GRANT SELECT ON ug_hr_payroll.staff_refs,ug_hr_payroll.leave_requests,ug_hr_payroll.payroll_periods,ug_hr_payroll.payroll_inputs TO ug_payroll_input_clerk,ug_payroll_reviewer;
GRANT EXECUTE ON FUNCTION ug_hr_payroll.fn_review_leave(TEXT,TEXT,TEXT,TEXT) TO ug_payroll_reviewer;
GRANT EXECUTE ON FUNCTION ug_hr_payroll.fn_approve_period(TEXT,TEXT,TEXT) TO ug_payroll_reviewer;
REVOKE ALL ON FUNCTION ug_hr_payroll.fn_review_leave(TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_hr_payroll.fn_approve_period(TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_hr_payroll FROM PUBLIC;
-- Apply staff/office row scope, payroll export encryption, independent approval and audit monitoring before use.
