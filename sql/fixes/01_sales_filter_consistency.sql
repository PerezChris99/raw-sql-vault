-- Purpose: establish one countable-sales rule for reports.
-- Engine: PostgreSQL 15+; depends on sql/fixes/00_demo_schema.sql.
-- Rerun safety: CREATE OR REPLACE VIEW.
-- Policy note: paid/shipped/delivered is an example, not a universal accounting rule.

CREATE OR REPLACE VIEW vault_demo.v_sales_countable AS
SELECT
    s.sale_id,
    s.customer_id,
    s.amount,
    s.currency,
    s.status,
    s.created_at,
    s.updated_at
FROM vault_demo.sales AS s
WHERE s.status IN ('paid', 'shipped', 'delivered')
  AND s.is_deleted = FALSE;

COMMENT ON VIEW vault_demo.v_sales_countable IS
    'Canonical example policy for reportable sales; confirm real status semantics with the business owner.';