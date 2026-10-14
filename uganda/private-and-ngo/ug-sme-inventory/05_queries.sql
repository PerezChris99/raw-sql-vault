-- Purpose: read-only inventory queries using the signed stock ledger.
-- Engine: PostgreSQL 15+; synthetic data only.

-- 01. Catalogue and stock.
SELECT * FROM sme_stock_demo.v_stock_on_hand ORDER BY sku;

-- 02. Reorder alerts.
SELECT sku, product_name, quantity_on_hand, reorder_level
FROM sme_stock_demo.v_reorder_alerts ORDER BY quantity_on_hand, sku;

-- 03. Zero or negative balance exceptions.
SELECT sku, quantity_on_hand FROM sme_stock_demo.v_stock_on_hand WHERE quantity_on_hand <= 0;

-- 04. Total estimated stock cost by category.
SELECT category, currency, SUM(stock_cost_estimate) AS cost_estimate
FROM sme_stock_demo.v_stock_on_hand WHERE is_active
GROUP BY category, currency ORDER BY category, currency;

-- 05. Product margins as absolute amounts (not audited gross profit).
SELECT sku, unit_price - unit_cost AS unit_margin, currency
FROM sme_stock_demo.products WHERE is_active ORDER BY unit_margin DESC;

-- 06. Movement history for each SKU.
SELECT p.sku, m.recorded_at, m.reason, m.quantity_delta, m.source_ref, m.actor_ref
FROM sme_stock_demo.stock_movements m JOIN sme_stock_demo.products p USING (product_id)
ORDER BY p.sku, m.recorded_at, m.movement_id;

-- 07. Movement count and net movement by reason.
SELECT reason, COUNT(*) AS movement_count, SUM(quantity_delta) AS net_units
FROM sme_stock_demo.stock_movements GROUP BY reason ORDER BY reason;

-- 08. Products without a movement event.
SELECT p.sku, p.product_name FROM sme_stock_demo.products p
WHERE NOT EXISTS (SELECT 1 FROM sme_stock_demo.stock_movements m WHERE m.product_id = p.product_id);

-- 09. Top products by current stock-cost estimate.
SELECT sku, stock_cost_estimate FROM sme_stock_demo.v_stock_on_hand
ORDER BY stock_cost_estimate DESC LIMIT 10;

-- 10. Daily movement net by SKU.
SELECT p.sku, (m.recorded_at AT TIME ZONE 'UTC')::date AS utc_day,
       SUM(m.quantity_delta) AS net_units
FROM sme_stock_demo.stock_movements m JOIN sme_stock_demo.products p USING (product_id)
GROUP BY p.sku, (m.recorded_at AT TIME ZONE 'UTC')::date ORDER BY utc_day, p.sku;

-- 11. Seven-day net movement per SKU by observed day.
WITH daily AS (
    SELECT product_id, (recorded_at AT TIME ZONE 'UTC')::date AS day,
           SUM(quantity_delta) AS net_units
    FROM sme_stock_demo.stock_movements GROUP BY product_id, (recorded_at AT TIME ZONE 'UTC')::date
)
SELECT p.sku, d.day,
       SUM(d.net_units) OVER (
           PARTITION BY d.product_id ORDER BY d.day::timestamp
           RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW
       ) AS trailing_7_calendar_days
FROM daily d JOIN sme_stock_demo.products p USING (product_id);

-- 12. Duplicate source reference review (not proof of duplicate movement).
SELECT source_ref, COUNT(*) AS rows
FROM sme_stock_demo.stock_movements
WHERE source_ref IS NOT NULL GROUP BY source_ref HAVING COUNT(*) > 1;

-- 13. Reason totals by month.
SELECT date_trunc('month', recorded_at AT TIME ZONE 'UTC') AS utc_month,
       reason, SUM(quantity_delta) AS net_units
FROM sme_stock_demo.stock_movements GROUP BY 1, reason ORDER BY 1, reason;

-- 14. Products grouped into reorder bands.
SELECT sku, quantity_on_hand, reorder_level,
       CASE WHEN quantity_on_hand = 0 THEN 'out_of_stock'
            WHEN quantity_on_hand <= reorder_level THEN 'reorder'
            WHEN quantity_on_hand <= reorder_level * 2 THEN 'watch'
            ELSE 'healthy' END AS stock_band
FROM sme_stock_demo.v_stock_on_hand WHERE is_active ORDER BY sku;

-- 15. Last movement date.
SELECT p.sku, MAX(m.recorded_at) AS last_movement_at
FROM sme_stock_demo.products p LEFT JOIN sme_stock_demo.stock_movements m USING (product_id)
GROUP BY p.sku ORDER BY last_movement_at NULLS FIRST;

-- 16. Net units by category.
SELECT p.category, SUM(m.quantity_delta) AS units
FROM sme_stock_demo.products p JOIN sme_stock_demo.stock_movements m USING (product_id)
GROUP BY p.category ORDER BY units DESC;

-- 17. Idempotency key collisions should be impossible due to UNIQUE.
SELECT idempotency_key, COUNT(*) FROM sme_stock_demo.stock_movements
GROUP BY idempotency_key HAVING COUNT(*) > 1;

-- 18. Products with current stock below the average product balance.
SELECT sku, quantity_on_hand
FROM sme_stock_demo.v_stock_on_hand
WHERE quantity_on_hand < (SELECT AVG(quantity_on_hand) FROM sme_stock_demo.v_stock_on_hand)
ORDER BY quantity_on_hand;

-- 19. Movement actor volume.
SELECT actor_ref, COUNT(*) AS events
FROM sme_stock_demo.stock_movements GROUP BY actor_ref ORDER BY events DESC;

-- 20. Approximate next replenishment quantity to reach twice the reorder level.
SELECT sku, GREATEST(2 * reorder_level - quantity_on_hand, 0) AS suggested_units
FROM sme_stock_demo.v_stock_on_hand
WHERE quantity_on_hand <= reorder_level ORDER BY suggested_units DESC;