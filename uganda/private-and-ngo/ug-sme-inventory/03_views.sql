-- Purpose: calculate current stock from immutable movement deltas.
-- Engine: PostgreSQL 15+; requires 01_schema.sql.
-- Rerun safety: CREATE OR REPLACE VIEW.

CREATE OR REPLACE VIEW sme_stock_demo.v_stock_on_hand AS
SELECT p.product_id, p.sku, p.product_name, p.category, p.unit_of_measure,
       p.unit_cost, p.unit_price, p.currency, p.reorder_level,
       COALESCE(SUM(m.quantity_delta), 0)::BIGINT AS quantity_on_hand,
       COALESCE(SUM(m.quantity_delta), 0)::NUMERIC * p.unit_cost AS stock_cost_estimate,
       p.is_active
FROM sme_stock_demo.products p
LEFT JOIN sme_stock_demo.stock_movements m ON m.product_id = p.product_id
GROUP BY p.product_id, p.sku, p.product_name, p.category, p.unit_of_measure,
         p.unit_cost, p.unit_price, p.currency, p.reorder_level, p.is_active;

CREATE OR REPLACE VIEW sme_stock_demo.v_reorder_alerts AS
SELECT *
FROM sme_stock_demo.v_stock_on_hand
WHERE is_active = TRUE AND quantity_on_hand <= reorder_level;

COMMENT ON VIEW sme_stock_demo.v_stock_on_hand IS
    'Balance derived from the signed stock movement ledger; reconcile before financial close.';