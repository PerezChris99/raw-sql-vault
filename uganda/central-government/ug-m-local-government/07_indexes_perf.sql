-- Candidate indexes only; measure EXPLAIN (ANALYZE, BUFFERS) on representative synthetic volume.
CREATE INDEX IF NOT EXISTS ix_lgmin_authority_year ON lgmin_demo.programmes(authority_id,fiscal_year);
CREATE INDEX IF NOT EXISTS ix_lgmin_event_time ON lgmin_demo.programme_events(happened_at DESC);