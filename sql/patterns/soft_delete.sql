-- Purpose: illustrate a partial index for live customer records.
-- Engine: PostgreSQL 15+; requires vault_demo.customers.
-- Rerun safety: CREATE INDEX IF NOT EXISTS.
-- Queries must explicitly exclude deleted rows. The index does not do that for them.

CREATE INDEX IF NOT EXISTS ix_customers_live_display_name
    ON vault_demo.customers(display_name)
    WHERE is_deleted = FALSE;

COMMENT ON INDEX vault_demo.ix_customers_live_display_name IS
    'Supports lookup among logically active demo customers; verify usefulness with EXPLAIN.';