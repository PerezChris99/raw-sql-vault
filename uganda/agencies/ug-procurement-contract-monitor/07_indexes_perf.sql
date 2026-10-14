-- Purpose: inspect award disclosure and deliverable exception access paths.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_procurement.notices;
ANALYZE ug_procurement.contract_deliverables;
ANALYZE ug_procurement.contract_variations;
EXPLAIN (COSTS, VERBOSE)
SELECT deliverable_code,due_on FROM ug_procurement.contract_deliverables
WHERE status NOT IN ('accepted','waived') AND due_on<CURRENT_DATE ORDER BY due_on;
EXPLAIN (COSTS, VERBOSE)
SELECT variation_ref,value_delta FROM ug_procurement.contract_variations
WHERE status='requested' ORDER BY variation_id;
