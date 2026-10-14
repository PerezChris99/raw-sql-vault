-- Purpose: confidential leave and payroll input reporting.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Leave requests awaiting review (restricted HR access).
SELECT * FROM ug_hr_payroll.v_leave_review_queue ORDER BY starts_on,leave_ref;
-- 02. Payroll input counts by period.
SELECT * FROM ug_hr_payroll.v_payroll_input_summary ORDER BY period_start;
-- 03. Approved period export queue.
SELECT * FROM ug_hr_payroll.v_period_export_queue ORDER BY period_start;
-- 04. Inputs missing approval/source evidence (should return zero).
SELECT input_ref FROM ug_hr_payroll.payroll_inputs
WHERE approved_by_ref IS NULL OR evidence_ref IS NULL OR source_reference IS NULL;
-- 05. Leave decisions with no evidence (should return zero).
SELECT leave_ref FROM ug_hr_payroll.leave_requests
WHERE status IN ('approved','rejected','taken') AND (reviewed_by_ref IS NULL OR review_evidence_ref IS NULL);
