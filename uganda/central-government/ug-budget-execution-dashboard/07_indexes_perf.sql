-- Purpose: inspect expenditure-to-commitment and period output access paths.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_budget_exec.commitments;
ANALYZE ug_budget_exec.expenditures;
ANALYZE ug_budget_exec.service_outputs;
EXPLAIN (COSTS, VERBOSE)
SELECT commitment_id,SUM(amount) FROM ug_budget_exec.expenditures WHERE commitment_id=1 GROUP BY commitment_id;
EXPLAIN (COSTS, VERBOSE)
SELECT programme_id,reporting_period,output_metric FROM ug_budget_exec.service_outputs
WHERE quality_status='verified' ORDER BY reporting_period;
