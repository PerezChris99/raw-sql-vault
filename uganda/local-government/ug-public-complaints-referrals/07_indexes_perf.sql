-- Purpose: query-plan baseline for triage and referral queues.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
ANALYZE ug_public_case.cases;
ANALYZE ug_public_case.referrals;
EXPLAIN (COSTS, VERBOSE)
SELECT case_ref,severity,due_at FROM ug_public_case.cases
WHERE status NOT IN ('closed','withdrawn','resolved')
ORDER BY severity,due_at;
-- Benchmark with representative synthetic case volumes; never use real complaint narratives as fixtures.
