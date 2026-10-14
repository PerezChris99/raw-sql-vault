-- Purpose: candidate indexes for lot expiry, facility stock and audit queries.
-- Engine: PostgreSQL 15+; idempotent DDL.
-- Confirm with EXPLAIN (ANALYZE, BUFFERS) on representative synthetic volumes.
CREATE INDEX IF NOT EXISTS ix_medicine_products_active
    ON medicine_demo.medicine_products(product_code) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS ix_medicine_batches_active_expiry
    ON medicine_demo.medicine_batches(expiry_date, product_id)
    WHERE batch_status = 'active';
CREATE INDEX IF NOT EXISTS ix_stock_movements_facility_time
    ON medicine_demo.stock_movements(facility_id, recorded_at DESC);
COMMENT ON INDEX medicine_demo.ix_medicine_batches_active_expiry IS
    'Candidate for active lot/expiry dashboards; validate against actual query plans.';