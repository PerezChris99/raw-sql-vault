-- Purpose: budget execution and output reporting with transparent definitions.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Execution summary.
SELECT * FROM ug_budget_exec.v_execution_summary ORDER BY fiscal_year,programme_ref;
-- 02. Financial control exceptions.
SELECT * FROM ug_budget_exec.v_budget_exceptions ORDER BY programme_ref;
-- 03. Programme output achievement; only source-verified records should be used for official reporting.
SELECT * FROM ug_budget_exec.v_output_performance ORDER BY reporting_period,programme_ref,output_metric;
-- 04. Expenditure trace to commitment and source evidence.
SELECT p.programme_ref,c.commitment_ref,e.expenditure_ref,e.amount,e.payment_reference,e.paid_on,e.evidence_ref
FROM ug_budget_exec.expenditures e JOIN ug_budget_exec.commitments c USING(commitment_id)
JOIN ug_budget_exec.programmes p USING(programme_id) ORDER BY e.paid_on,e.expenditure_ref;
-- 05. Multiple appropriation versions; never overwrite prior approved amounts.
SELECT p.programme_ref,a.version_no,a.approved_amount,a.effective_on,a.approved_by_ref,a.evidence_ref
FROM ug_budget_exec.appropriations a JOIN ug_budget_exec.programmes p USING(programme_id)
ORDER BY p.programme_ref,a.version_no;
-- 06. Outputs not yet quality-reviewed.
SELECT * FROM ug_budget_exec.service_outputs WHERE quality_status='unreviewed' ORDER BY reporting_period,output_ref;
-- 07. Duplicate payment source references (unique constraint should prevent these).
SELECT payment_reference,COUNT(*) FROM ug_budget_exec.expenditures GROUP BY payment_reference HAVING COUNT(*)>1;
