-- Purpose: document queue indexes and inspect application review access paths.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
ANALYZE ug_bursary.applications;
ANALYZE ug_bursary.disbursements;
EXPLAIN (COSTS, VERBOSE)
SELECT application_ref,status,submitted_at
FROM ug_bursary.applications
WHERE status IN ('submitted','under_review','awaiting_documents')
ORDER BY submitted_at,application_id;
-- Use representative synthetic volume for performance benchmarks; fixture sizes are not a benchmark.
