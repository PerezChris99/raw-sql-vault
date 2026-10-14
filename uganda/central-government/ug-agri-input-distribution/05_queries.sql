-- Purpose: stock and distribution oversight queries.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seeds and views.
-- All example references are synthetic; use bound parameters in applications.

-- 01. Current balance by lot.
SELECT lot_ref,product_code,product_name,unit_code,warehouse_ref,current_balance,lot_status
FROM ug_agri_inputs.v_lot_balance ORDER BY product_code,lot_ref;

-- 02. Lots approaching expiry.
SELECT lot_ref,product_code,warehouse_ref,current_balance,expires_on,days_until_expiry
FROM ug_agri_inputs.v_expiry_risk ORDER BY days_until_expiry,lot_ref;

-- 03. Distribution receipts needing reconciliation.
SELECT * FROM ug_agri_inputs.v_distribution_reconciliation
WHERE reconciliation_status<>'matched' ORDER BY movement_ref;

-- 04. Movement history for a lot.
SELECT m.movement_at,m.movement_type,m.quantity,m.recipient_ref,m.source_document_ref,m.reason,m.recorded_by
FROM ug_agri_inputs.stock_movements m JOIN ug_agri_inputs.lots l USING(lot_id)
WHERE l.lot_ref='UGLOT-DEMO-001' ORDER BY m.movement_at,m.movement_id;

-- 05. Stock balance by product and warehouse.
SELECT product_code,product_name,warehouse_ref,unit_code,SUM(current_balance) AS stock_balance
FROM ug_agri_inputs.v_lot_balance GROUP BY product_code,product_name,warehouse_ref,unit_code
ORDER BY product_code,warehouse_ref;

-- 06. Lots with negative balances (should return zero).
SELECT lot_ref,current_balance FROM ug_agri_inputs.v_lot_balance WHERE current_balance<0;

-- 07. Stock write-offs by reason.
SELECT reason,COUNT(*) AS movements,SUM(quantity) AS quantity_written_off
FROM ug_agri_inputs.stock_movements WHERE movement_type='writeoff'
GROUP BY reason ORDER BY quantity_written_off DESC;

-- 08. Issued quantities by recipient reference.
SELECT recipient_ref,COUNT(*) AS deliveries,SUM(quantity) AS total_quantity
FROM ug_agri_inputs.stock_movements WHERE movement_type='issued'
GROUP BY recipient_ref ORDER BY total_quantity DESC;

-- 09. Receipts that report less than issued.
SELECT * FROM ug_agri_inputs.v_distribution_reconciliation WHERE reconciliation_status='short_receipt';

-- 10. Movement counts by type and month.
SELECT date_trunc('month',movement_at)::date AS movement_month,movement_type,COUNT(*) AS movement_count,SUM(quantity) AS total_quantity
FROM ug_agri_inputs.stock_movements GROUP BY date_trunc('month',movement_at)::date,movement_type
ORDER BY movement_month,movement_type;
