-- Purpose: leave review queue and payroll input completeness reports.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_hr_payroll.v_leave_review_queue AS
SELECT l.leave_ref,s.staff_ref,s.employing_unit_ref,p.leave_type,l.starts_on,l.ends_on,l.requested_days,l.status,l.submitted_at
FROM ug_hr_payroll.leave_requests l JOIN ug_hr_payroll.staff_refs s USING(staff_id)
JOIN ug_hr_payroll.leave_policies p USING(policy_id)
WHERE l.status IN ('submitted','draft');

CREATE OR REPLACE VIEW ug_hr_payroll.v_payroll_input_summary AS
SELECT p.period_ref,p.period_start,p.period_end,p.status,
 COUNT(DISTINCT i.staff_id) AS staff_with_inputs,
 COUNT(i.input_id) AS input_records,
 COUNT(i.input_id) FILTER(WHERE i.input_type='correction_reference') AS correction_inputs
FROM ug_hr_payroll.payroll_periods p LEFT JOIN ug_hr_payroll.payroll_inputs i USING(period_id)
GROUP BY p.period_id,p.period_ref,p.period_start,p.period_end,p.status;

CREATE OR REPLACE VIEW ug_hr_payroll.v_period_export_queue AS
SELECT p.period_ref,p.period_start,p.period_end,p.status,p.approved_by_ref,p.approved_at,
 COUNT(i.input_id) AS input_count
FROM ug_hr_payroll.payroll_periods p LEFT JOIN ug_hr_payroll.payroll_inputs i USING(period_id)
WHERE p.status IN ('open','review','approved')
GROUP BY p.period_id,p.period_ref,p.period_start,p.period_end,p.status,p.approved_by_ref,p.approved_at;
