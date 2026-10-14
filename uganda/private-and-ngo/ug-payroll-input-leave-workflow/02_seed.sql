-- Purpose: synthetic staff, leave policy and payroll period fixtures. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_hr_payroll.staff_refs(staff_ref,employing_unit_ref,role_ref,employment_type,start_date)
VALUES('UGSTAFF-DEMO-01','SYN-UNIT-01','SYN-ROLE-01','permanent',DATE '2024-01-01')
ON CONFLICT(staff_ref) DO NOTHING;
INSERT INTO ug_hr_payroll.leave_policies(policy_ref,leave_type,annual_entitlement_days,requires_evidence,effective_from)
VALUES('SYN-LEAVE-POLICY-ANNUAL','annual',21,FALSE,DATE '2026-01-01')
ON CONFLICT(policy_ref) DO NOTHING;
INSERT INTO ug_hr_payroll.payroll_periods(period_ref,period_start,period_end)
VALUES('UGPAY-P-DEMO-001',DATE '2026-10-01',DATE '2026-10-31')
ON CONFLICT(period_ref) DO NOTHING;
