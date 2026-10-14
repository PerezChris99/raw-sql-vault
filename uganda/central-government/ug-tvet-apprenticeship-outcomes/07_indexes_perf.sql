-- Purpose: inspect cohort outcome and placement overlap lookup plans.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_tvet.enrolments;
ANALYZE ug_tvet.placements;
ANALYZE ug_tvet.assessments;
EXPLAIN (COSTS, VERBOSE)
SELECT cohort_id,status,COUNT(*) FROM ug_tvet.enrolments WHERE cohort_id=1 GROUP BY cohort_id,status;
EXPLAIN (COSTS, VERBOSE)
SELECT enrolment_id,starts_on,ends_on FROM ug_tvet.placements WHERE enrolment_id=1 AND status IN ('planned','active');
