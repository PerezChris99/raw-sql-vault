-- Purpose: facility/batch balances, near-expiry warnings and medicine summary.
-- Engine: PostgreSQL 15+; requires schema and seed.
-- Rerun safety: CREATE OR REPLACE VIEW.

CREATE OR REPLACE VIEW medicine_demo.v_batch_stock AS
SELECT f.facility_code, f.facility_name, p.product_code, p.generic_name, p.strength,
       p.dosage_form, b.batch_id, b.batch_number, b.expiry_date, b.batch_status,
       b.received_cost, b.currency,
       COALESCE(SUM(m.quantity_delta), 0)::BIGINT AS on_hand_quantity
FROM medicine_demo.facilities f
JOIN medicine_demo.stock_movements m ON m.facility_id = f.facility_id
JOIN medicine_demo.medicine_batches b ON b.batch_id = m.batch_id
JOIN medicine_demo.medicine_products p ON p.product_id = b.product_id
GROUP BY f.facility_code, f.facility_name, p.product_code, p.generic_name, p.strength,
         p.dosage_form, b.batch_id, b.batch_number, b.expiry_date, b.batch_status,
         b.received_cost, b.currency;

CREATE OR REPLACE VIEW medicine_demo.v_expiry_watch AS
SELECT *,
       expiry_date - CURRENT_DATE AS days_until_expiry,
       CASE
           WHEN expiry_date < CURRENT_DATE THEN 'expired'
           WHEN expiry_date <= CURRENT_DATE + 30 THEN 'expires_within_30_days'
           WHEN expiry_date <= CURRENT_DATE + 90 THEN 'expires_within_90_days'
           ELSE 'in_date'
       END AS expiry_band
FROM medicine_demo.v_batch_stock
WHERE on_hand_quantity > 0;

CREATE OR REPLACE VIEW medicine_demo.v_facility_product_stock AS
SELECT facility_code, facility_name, product_code, generic_name, strength, unit_of_issue,
       SUM(on_hand_quantity) FILTER (
           WHERE batch_status = 'active' AND expiry_date >= CURRENT_DATE
       ) AS usable_stock,
       SUM(on_hand_quantity) AS total_recorded_stock,
       COUNT(*) FILTER (WHERE expiry_date < CURRENT_DATE AND on_hand_quantity > 0) AS expired_lot_count
FROM medicine_demo.v_batch_stock
JOIN medicine_demo.medicine_products USING (product_code, generic_name, strength, dosage_form)
GROUP BY facility_code, facility_name, product_code, generic_name, strength, unit_of_issue;

COMMENT ON VIEW medicine_demo.v_expiry_watch IS
    'Expiry warning by recorded batch balance; check local issue/recall procedures before taking action.';