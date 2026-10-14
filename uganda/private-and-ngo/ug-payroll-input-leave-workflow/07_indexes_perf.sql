-- Purpose: inspect leave overlap and period input lookups.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_hr_payroll.leave_requests;
ANALYZE ug_hr_payroll.payroll_inputs;
EXPLAIN (COSTS, VERBOSE)
SELECT leave_ref,starts_on,ends_on FROM ug_hr_payroll.leave_requests
WHERE status='submitted' AND starts_on<=DATE '2026-10-31' AND ends_on>=DATE '2026-10-01';
EXPLAIN (COSTS, VERBOSE)
SELECT staff_id,input_type,COUNT(*) FROM ug_hr_payroll.payroll_inputs WHERE period_id=1 GROUP BY staff_id,input_type;
