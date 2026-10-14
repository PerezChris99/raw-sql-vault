-- Purpose: document index rationale and plan review.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
-- Queue index supports status filtering and oldest-first review.
-- Event index supports per-application timeline retrieval.
-- Document and fee indexes support per-application reconciliation.
ANALYZE ug_permit.applications;
ANALYZE ug_permit.application_events;
EXPLAIN (COSTS, VERBOSE)
SELECT application_ref,submitted_at,status
FROM ug_permit.applications
WHERE status IN ('submitted','under_review','awaiting_documents')
ORDER BY status,created_at,application_id;
-- Tiny synthetic fixtures do not establish production performance.
-- Use EXPLAIN (ANALYZE, BUFFERS) with representative synthetic volume in a disposable DB.
