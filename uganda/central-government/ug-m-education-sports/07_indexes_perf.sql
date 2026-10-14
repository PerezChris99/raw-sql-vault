-- Candidate indexes only; measure with EXPLAIN before retaining.
CREATE INDEX IF NOT EXISTS ix_education_alloc_status_date ON education_demo.allocations(status,planned_dispatch_date) WHERE is_deleted=FALSE;
CREATE INDEX IF NOT EXISTS ix_education_school_asset ON education_demo.allocations(school_id,asset_id);