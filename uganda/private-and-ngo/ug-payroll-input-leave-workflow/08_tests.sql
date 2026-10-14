-- Purpose: assertions for evidence-backed leave decisions and period approval gate.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_staff BIGINT; v_policy BIGINT; v_period BIGINT; v_count BIGINT;
BEGIN
 SELECT staff_id INTO v_staff FROM ug_hr_payroll.staff_refs WHERE staff_ref='UGSTAFF-DEMO-01';
 SELECT policy_id INTO v_policy FROM ug_hr_payroll.leave_policies WHERE policy_ref='SYN-LEAVE-POLICY-ANNUAL';
 INSERT INTO ug_hr_payroll.leave_requests(leave_ref,staff_id,policy_id,starts_on,ends_on,requested_days,reason_redacted)
 VALUES('UGLV-DEMO-001',v_staff,v_policy,DATE '2026-10-20',DATE '2026-10-22',3,'Synthetic planned leave')
 ;
 BEGIN
  PERFORM ug_hr_payroll.fn_review_leave('UGLV-DEMO-001','approved','SYN-HR-REVIEWER',NULL);
  RAISE EXCEPTION 'ASSERT leave without evidence was approved';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM ug_hr_payroll.fn_review_leave('UGLV-DEMO-001','approved','SYN-HR-REVIEWER','SYN-LEAVE-DECISION-001');
 SELECT COUNT(*) INTO v_count FROM ug_hr_payroll.leave_requests WHERE leave_ref='UGLV-DEMO-001' AND status='approved';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT valid leave decision missing'; END IF;
 SELECT period_id INTO v_period FROM ug_hr_payroll.payroll_periods WHERE period_ref='UGPAY-P-DEMO-001';
 PERFORM ug_hr_payroll.fn_approve_period('UGPAY-P-DEMO-001','SYN-PAYROLL-REVIEWER','SYN-PAYROLL-APPROVAL-001');
 SELECT COUNT(*) INTO v_count FROM ug_hr_payroll.payroll_periods WHERE period_id=v_period AND status='approved';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT period approval missing'; END IF;
END; $test$;
ROLLBACK;
