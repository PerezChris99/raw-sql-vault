-- Purpose: approved budget, release, commitment, expenditure and output variance reporting.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_budget_exec.v_execution_summary AS
SELECT p.programme_ref,p.office_ref,p.programme_name,p.fiscal_year,p.currency_code,
 COALESCE((SELECT a.approved_amount FROM ug_budget_exec.appropriations a WHERE a.programme_id=p.programme_id ORDER BY a.version_no DESC LIMIT 1),0) AS current_appropriation,
 COALESCE((SELECT SUM(r.amount) FROM ug_budget_exec.releases r WHERE r.programme_id=p.programme_id),0) AS total_released,
 COALESCE((SELECT SUM(c.amount) FROM ug_budget_exec.commitments c WHERE c.programme_id=p.programme_id AND c.status<>'cancelled'),0) AS active_commitments,
 COALESCE((SELECT SUM(e.amount) FROM ug_budget_exec.expenditures e JOIN ug_budget_exec.commitments c USING(commitment_id)
           WHERE c.programme_id=p.programme_id),0) AS total_expenditure
FROM ug_budget_exec.programmes p;

CREATE OR REPLACE VIEW ug_budget_exec.v_budget_exceptions AS
SELECT *,current_appropriation-total_released AS unreleased_balance,
       total_released-active_commitments AS release_less_commitment,
       active_commitments-total_expenditure AS commitment_less_expenditure
FROM ug_budget_exec.v_execution_summary
WHERE total_released>current_appropriation OR active_commitments>total_released OR total_expenditure>active_commitments;

CREATE OR REPLACE VIEW ug_budget_exec.v_output_performance AS
SELECT p.programme_ref,p.programme_name,o.reporting_period,o.output_metric,o.planned_quantity,o.achieved_quantity,o.unit_code,
 CASE WHEN o.planned_quantity=0 THEN NULL ELSE round(100.0*o.achieved_quantity/o.planned_quantity,2) END AS achievement_percent,
 o.quality_status,o.source_ref
FROM ug_budget_exec.service_outputs o JOIN ug_budget_exec.programmes p USING(programme_id);
