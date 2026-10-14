-- Purpose: candidate indexes for common reporting access patterns.
-- Engine: PostgreSQL 15+.
-- Rerun safety: CREATE INDEX IF NOT EXISTS.
-- Keep indexes only if EXPLAIN (ANALYZE, BUFFERS) on representative synthetic
-- data demonstrates value relative to storage and write overhead.

CREATE INDEX IF NOT EXISTS ix_programme_actions_active_owner_due
    ON opm_demo.programme_actions(owner_department_id, due_date, action_id)
    WHERE is_deleted = FALSE AND status NOT IN ('done', 'cancelled');

CREATE INDEX IF NOT EXISTS ix_action_events_recent
    ON opm_demo.action_events(happened_at DESC, action_id);

COMMENT ON INDEX opm_demo.ix_programme_actions_active_owner_due IS
    'Supports open-action reporting by owner and due date; validate with EXPLAIN.';