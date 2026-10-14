-- Purpose: support common warehouse and point-in-time access paths.
-- Engine: PostgreSQL 15+.
-- The unique constraints already supply indexes for source identifiers.
-- Measure plans with realistic volumes before keeping additional indexes.

CREATE INDEX IF NOT EXISTS ix_staging_sales_batch
    ON analytics_demo.staging_sales(batch_id, source_system, source_sale_id);

CREATE INDEX IF NOT EXISTS ix_feature_values_latest_entity
    ON analytics_demo.feature_values(entity_type, entity_id, feature_name, feature_timestamp DESC, source_available_at DESC);

COMMENT ON INDEX analytics_demo.ix_staging_sales_batch IS
    'Supports batch validation and retries; compare with staging write overhead.';