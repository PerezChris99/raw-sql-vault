-- Purpose: 20 practical read-only medicine supply/expiry reports.
-- Engine: PostgreSQL 15+; synthetic data only.

-- 01. Full batch balance.
SELECT * FROM medicine_demo.v_batch_stock ORDER BY facility_code, product_code, expiry_date;

-- 02. Batches expired but still recorded on hand.
SELECT facility_code, product_code, batch_number, on_hand_quantity
FROM medicine_demo.v_expiry_watch WHERE expiry_band = 'expired'
ORDER BY facility_code, product_code;

-- 03. Batches expiring within 30 days.
SELECT facility_code, product_code, batch_number, expiry_date, on_hand_quantity
FROM medicine_demo.v_expiry_watch WHERE expiry_band = 'expires_within_30_days'
ORDER BY expiry_date;

-- 04. Batches expiring within 90 days.
SELECT * FROM medicine_demo.v_expiry_watch
WHERE expiry_band IN ('expires_within_30_days', 'expires_within_90_days')
ORDER BY days_until_expiry;

-- 05. Current usable stock by facility and product.
SELECT * FROM medicine_demo.v_facility_product_stock ORDER BY facility_code, product_code;

-- 06. Zero stock batches that have movement history.
SELECT b.facility_code, b.product_code, b.batch_number, b.on_hand_quantity
FROM medicine_demo.v_batch_stock b WHERE on_hand_quantity = 0;

-- 07. Ledger history by facility/batch.
SELECT f.facility_code, p.product_code, b.batch_number, m.recorded_at,
       m.movement_reason, m.quantity_delta, m.idempotency_key, m.actor_reference
FROM medicine_demo.stock_movements m
JOIN medicine_demo.facilities f USING (facility_id)
JOIN medicine_demo.medicine_batches b USING (batch_id)
JOIN medicine_demo.medicine_products p USING (product_id)
ORDER BY f.facility_code, p.product_code, b.batch_number, m.recorded_at, m.movement_id;

-- 08. Net movement by reason.
SELECT movement_reason, COUNT(*) AS event_count, SUM(quantity_delta) AS net_units
FROM medicine_demo.stock_movements GROUP BY movement_reason ORDER BY movement_reason;

-- 09. Facilities with no stock movement.
SELECT f.facility_code, f.facility_name
FROM medicine_demo.facilities f
WHERE NOT EXISTS (SELECT 1 FROM medicine_demo.stock_movements m WHERE m.facility_id = f.facility_id);

-- 10. Products with no active stock.
SELECT p.product_code, p.generic_name
FROM medicine_demo.medicine_products p
WHERE NOT EXISTS (
    SELECT 1 FROM medicine_demo.v_batch_stock b
    WHERE b.product_code = p.product_code AND b.batch_status = 'active'
      AND b.expiry_date >= CURRENT_DATE AND b.on_hand_quantity > 0
);

-- 11. Ledger totals by facility and month.
SELECT f.facility_code, date_trunc('month', m.recorded_at AT TIME ZONE 'UTC') AS utc_month,
       SUM(m.quantity_delta) AS net_units
FROM medicine_demo.stock_movements m JOIN medicine_demo.facilities f USING (facility_id)
GROUP BY f.facility_code, date_trunc('month', m.recorded_at AT TIME ZONE 'UTC')
ORDER BY utc_month, f.facility_code;

-- 12. Largest stock positions by estimated received unit cost.
SELECT facility_code, product_code, batch_number, on_hand_quantity,
       on_hand_quantity * received_cost AS indicative_stock_cost, currency
FROM medicine_demo.v_batch_stock ORDER BY indicative_stock_cost DESC;

-- 13. Batch status breakdown.
SELECT batch_status, COUNT(*) AS lots, SUM(on_hand_quantity) AS recorded_units
FROM medicine_demo.v_batch_stock GROUP BY batch_status ORDER BY batch_status;

-- 14. Audit repeated source references for manual reconciliation.
SELECT source_reference, COUNT(*) AS movements
FROM medicine_demo.stock_movements WHERE source_reference IS NOT NULL
GROUP BY source_reference HAVING COUNT(*) > 1;

-- 15. Days until expiry histogram.
SELECT expiry_band, COUNT(*) AS lot_count, SUM(on_hand_quantity) AS units
FROM medicine_demo.v_expiry_watch GROUP BY expiry_band ORDER BY expiry_band;

-- 16. Movement events by actor reference.
SELECT actor_reference, COUNT(*) AS movement_count
FROM medicine_demo.stock_movements GROUP BY actor_reference ORDER BY movement_count DESC;

-- 17. Same-product lots across facilities.
SELECT product_code, COUNT(DISTINCT facility_code) AS facilities,
       SUM(on_hand_quantity) AS recorded_units
FROM medicine_demo.v_batch_stock GROUP BY product_code ORDER BY product_code;

-- 18. Stock records requiring review: negative balance should be impossible.
SELECT * FROM medicine_demo.v_batch_stock WHERE on_hand_quantity < 0;

-- 19. Recent stock movements.
SELECT facility_id, batch_id, quantity_delta, movement_reason, recorded_at
FROM medicine_demo.stock_movements
WHERE recorded_at >= now() - INTERVAL '30 days' AND recorded_at < now()
ORDER BY recorded_at DESC;

-- 20. Expiry risk by facility, only active usable lots expiring in 90 days.
SELECT facility_code, COUNT(*) AS lots_at_risk, SUM(on_hand_quantity) AS units_at_risk
FROM medicine_demo.v_expiry_watch
WHERE batch_status = 'active' AND days_until_expiry BETWEEN 0 AND 90
GROUP BY facility_code ORDER BY units_at_risk DESC;