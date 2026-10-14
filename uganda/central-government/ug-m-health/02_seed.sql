-- Purpose: seed fictional facilities, products and opening stock movements.
-- Engine: PostgreSQL 15+; requires 01_schema.sql.
-- Rerun safety: stable identifiers and idempotency keys.

INSERT INTO medicine_demo.facilities(facility_code, facility_name, facility_type)
VALUES
    ('DEMO-HF-001', 'Synthetic Health Facility North', 'health_centre'),
    ('DEMO-HF-002', 'Synthetic Referral Facility East', 'hospital')
ON CONFLICT (facility_code) DO NOTHING;

INSERT INTO medicine_demo.medicine_products(product_code, generic_name, strength, dosage_form, unit_of_issue)
VALUES
    ('DEMO-MED-001', 'Synthetic analgesic', '500 mg', 'tablet', 'tablet'),
    ('DEMO-MED-002', 'Synthetic oral rehydration salts', 'standard sachet', 'sachet', 'sachet')
ON CONFLICT (product_code) DO NOTHING;

INSERT INTO medicine_demo.medicine_batches(product_id, batch_number, expiry_date, received_cost, currency)
SELECT p.product_id, v.batch_number, v.expiry_date, v.received_cost, 'UGX'
FROM (VALUES
    ('DEMO-MED-001', 'DEMO-LOT-A', DATE '2027-12-31', 50.00),
    ('DEMO-MED-001', 'DEMO-LOT-EXPIRED', DATE '2024-12-31', 35.00),
    ('DEMO-MED-002', 'DEMO-LOT-B', DATE '2027-06-30', 1800.00)
) AS v(product_code, batch_number, expiry_date, received_cost)
JOIN medicine_demo.medicine_products p ON p.product_code = v.product_code
ON CONFLICT (product_id, batch_number) DO NOTHING;

INSERT INTO medicine_demo.stock_movements
    (facility_id, batch_id, quantity_delta, movement_reason, idempotency_key, source_reference, actor_reference)
SELECT f.facility_id, b.batch_id, v.quantity_delta, 'receipt', v.idempotency_key, 'synthetic-opening-stock', 'seed-script'
FROM (VALUES
    ('DEMO-HF-001', 'DEMO-MED-001', 'DEMO-LOT-A', 100, 'SEED-MED-HF1-A'),
    ('DEMO-HF-001', 'DEMO-MED-001', 'DEMO-LOT-EXPIRED', 20, 'SEED-MED-HF1-EXPIRED'),
    ('DEMO-HF-002', 'DEMO-MED-002', 'DEMO-LOT-B', 30, 'SEED-MED-HF2-B')
) AS v(facility_code, product_code, batch_number, quantity_delta, idempotency_key)
JOIN medicine_demo.facilities f ON f.facility_code = v.facility_code
JOIN medicine_demo.medicine_products p ON p.product_code = v.product_code
JOIN medicine_demo.medicine_batches b ON b.product_id = p.product_id AND b.batch_number = v.batch_number
ON CONFLICT (idempotency_key) DO NOTHING;