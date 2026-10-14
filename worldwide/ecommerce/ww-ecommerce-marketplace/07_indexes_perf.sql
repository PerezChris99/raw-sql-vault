-- Purpose: indexes for active stock and order-line report paths.
-- Engine: PostgreSQL 15+.
-- Validate with representative order volumes and EXPLAIN (ANALYZE, BUFFERS).

CREATE INDEX IF NOT EXISTS ix_products_active_stock
    ON shop_demo.products(stock_quantity, sku) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS ix_orders_currency_status_created
    ON shop_demo.orders(currency, status, created_at DESC);

COMMENT ON INDEX shop_demo.ix_products_active_stock IS
    'Supports low-stock scans; the best column order depends on actual selectivity.';