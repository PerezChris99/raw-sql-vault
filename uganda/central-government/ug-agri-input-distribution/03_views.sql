-- Purpose: current lot balances, expiry risk and distribution reconciliation.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_agri_inputs.v_lot_balance AS
SELECT l.lot_id,l.lot_ref,p.product_code,p.product_name,p.input_type,p.unit_code,l.warehouse_ref,
       l.received_on,l.expires_on,l.lot_status,
       COALESCE(SUM(CASE WHEN m.movement_type IN ('received','returned') THEN m.quantity
                         WHEN m.movement_type IN ('issued','writeoff') THEN -m.quantity ELSE 0 END),0)::NUMERIC(14,3) AS current_balance
FROM ug_agri_inputs.lots l
JOIN ug_agri_inputs.input_products p USING(product_id)
LEFT JOIN ug_agri_inputs.stock_movements m USING(lot_id)
GROUP BY l.lot_id,l.lot_ref,p.product_code,p.product_name,p.input_type,p.unit_code,l.warehouse_ref,l.received_on,l.expires_on,l.lot_status;

CREATE OR REPLACE VIEW ug_agri_inputs.v_expiry_risk AS
SELECT *,(expires_on-CURRENT_DATE) AS days_until_expiry
FROM ug_agri_inputs.v_lot_balance
WHERE expires_on IS NOT NULL AND expires_on<=CURRENT_DATE+30 AND current_balance>0 AND lot_status='available';

CREATE OR REPLACE VIEW ug_agri_inputs.v_distribution_reconciliation AS
SELECT m.movement_ref,m.lot_id,m.recipient_ref,m.quantity AS issued_quantity,
       r.receipt_ref,r.received_quantity,r.received_at,r.evidence_reference,
       CASE WHEN r.receipt_id IS NULL THEN 'receipt_missing'
            WHEN r.received_quantity<m.quantity THEN 'short_receipt'
            WHEN r.received_quantity>m.quantity THEN 'quantity_mismatch'
            ELSE 'matched' END AS reconciliation_status
FROM ug_agri_inputs.stock_movements m
LEFT JOIN ug_agri_inputs.distribution_receipts r USING(movement_id)
WHERE m.movement_type='issued';
