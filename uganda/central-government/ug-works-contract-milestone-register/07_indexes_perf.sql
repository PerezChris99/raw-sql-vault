-- Purpose: inspect common milestone and certificate queue access paths.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_works_contract.milestones;
ANALYZE ug_works_contract.certificates;
EXPLAIN (COSTS, VERBOSE)
SELECT certificate_ref,submitted_amount,submitted_at FROM ug_works_contract.certificates
WHERE status IN ('submitted','under_review') ORDER BY submitted_at,certificate_id;
EXPLAIN (COSTS, VERBOSE)
SELECT milestone_code,planned_due_on FROM ug_works_contract.milestones
WHERE status NOT IN ('accepted','waived') AND planned_due_on<CURRENT_DATE ORDER BY planned_due_on;
