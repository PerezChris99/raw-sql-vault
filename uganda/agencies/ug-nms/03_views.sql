CREATE OR REPLACE VIEW nms_demo.v_dispatch_balance AS
SELECT d.dispatch_ref,w.warehouse_code,f.facility_code,f.facility_label,d.dispatch_date,d.status,
 b.batch_code,m.medicine_code,m.medicine_label,b.expiry_date,b.batch_status AS lot_status,
 l.quantity_sent,COALESCE(r.received_qty,0)::BIGINT AS quantity_received,
 l.quantity_sent-COALESCE(r.received_qty,0) AS quantity_outstanding
FROM nms_demo.dispatches d JOIN nms_demo.warehouses w USING(warehouse_id)
JOIN nms_demo.facilities f USING(facility_id) JOIN nms_demo.dispatch_lines l USING(dispatch_id)
JOIN nms_demo.batches b USING(batch_id) JOIN nms_demo.medicines m USING(medicine_id)
LEFT JOIN(SELECT dispatch_id,batch_id,SUM(quantity_received) received_qty FROM nms_demo.receipt_entries GROUP BY dispatch_id,batch_id) r USING(dispatch_id,batch_id);
CREATE OR REPLACE VIEW nms_demo.v_dispatch_exceptions AS
SELECT * FROM nms_demo.v_dispatch_balance WHERE quantity_outstanding>0 OR lot_status<>'active' OR expiry_date<CURRENT_DATE;
CREATE OR REPLACE VIEW nms_demo.v_facility_dispatch_summary AS
SELECT facility_code,facility_label,COUNT(DISTINCT dispatch_ref) AS dispatch_count,
 SUM(quantity_sent) AS quantity_sent,SUM(quantity_received) AS quantity_received,SUM(quantity_outstanding) AS outstanding_qty
FROM nms_demo.v_dispatch_balance GROUP BY facility_code,facility_label;
COMMENT ON VIEW nms_demo.v_dispatch_exceptions IS 'Supply-chain review queue; discrepancy or lot status alone is not a misconduct finding.';