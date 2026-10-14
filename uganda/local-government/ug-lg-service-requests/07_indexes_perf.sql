-- Purpose: queue indexes for the measured request/report patterns.
-- Engine: PostgreSQL 15+; safe to re-run.
-- Validate with EXPLAIN (ANALYZE, BUFFERS) using realistic synthetic volume.

CREATE INDEX IF NOT EXISTS ix_service_open_locality_due
    ON service_demo.service_requests(locality_id, due_at, priority)
    WHERE is_deleted = FALSE AND status NOT IN ('resolved', 'cancelled');

CREATE INDEX IF NOT EXISTS ix_service_resolved_at
    ON service_demo.service_requests(resolved_at DESC)
    WHERE status = 'resolved' AND is_deleted = FALSE;

COMMENT ON INDEX service_demo.ix_service_open_locality_due IS
    'Candidate for locality-scoped open queue; retain only when plans justify it.';