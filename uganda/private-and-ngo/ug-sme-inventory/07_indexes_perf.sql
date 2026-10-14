-- Purpose: candidate indexes for product movement and reporting patterns.
-- Engine: PostgreSQL 15+.
-- Unique key index is created by the unique constraint on idempotency_key.
-- Validate with EXPLAIN (ANALYZE, BUFFERS) and realistic stock-history volumes.

CREATE INDEX IF NOT EXISTS ix_stock_movements_product_latest
    ON sme_stock_demo.stock_movements(product_id, recorded_at DESC, movement_id DESC);

CREATE INDEX IF NOT EXISTS ix_products_active_category
    ON sme_stock_demo.products(category, sku) WHERE is_active = TRUE;

COMMENT ON INDEX sme_stock_demo.ix_stock_movements_product_latest IS
    'Supports product ledger history; balance SUM still scans relevant movement entries.';