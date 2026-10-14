-- 20 read-only reports on synthetic distribution records.
-- 01 Shipment balances.
SELECT * FROM nms_demo.v_dispatch_balance ORDER BY dispatch_ref,batch_code;
-- 02 Dispatch discrepancies and expiry/recall exceptions.
SELECT * FROM nms_demo.v_dispatch_exceptions ORDER BY dispatch_date,dispatch_ref,batch_code;
-- 03 Receipt summary by facility.
SELECT * FROM nms_demo.v_facility_dispatch_summary ORDER BY facility_code;
-- 04 Lots expiring in 90 days.
SELECT batch_code,expiry_date FROM nms_demo.batches WHERE expiry_date<CURRENT_DATE+90 ORDER BY expiry_date;
-- 05 Recalled/quarantined batch list.
SELECT batch_code,batch_status,source_reference FROM nms_demo.batches WHERE batch_status<>'active';
-- 06 Planned dispatches still not shipped.
SELECT dispatch_ref,dispatch_date FROM nms_demo.dispatches WHERE status='planned';
-- 07 Dispatched quantity by medicine.
SELECT medicine_code,SUM(quantity_sent),SUM(quantity_received) FROM nms_demo.v_dispatch_balance GROUP BY medicine_code;
-- 08 Dispatch event history.
SELECT d.dispatch_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM nms_demo.dispatch_events e JOIN nms_demo.dispatches d USING(dispatch_id) ORDER BY d.dispatch_ref,e.happened_at;
-- 09 Receipt entries by dispatch/lot.
SELECT d.dispatch_ref,b.batch_code,r.receipt_ref,r.quantity_received,r.received_at FROM nms_demo.receipt_entries r JOIN nms_demo.dispatches d USING(dispatch_id) JOIN nms_demo.batches b USING(batch_id) ORDER BY d.dispatch_ref,b.batch_code,r.received_at;
-- 10 Facility with no dispatch.
SELECT facility_code FROM nms_demo.facilities f WHERE NOT EXISTS(SELECT 1 FROM nms_demo.dispatches d WHERE d.facility_id=f.facility_id);
-- 11 Dispatches with outstanding quantities.
SELECT DISTINCT dispatch_ref,facility_code FROM nms_demo.v_dispatch_balance WHERE quantity_outstanding>0;
-- 12 Outstanding quantities by warehouse.
SELECT warehouse_code,SUM(quantity_outstanding) FROM nms_demo.v_dispatch_balance GROUP BY warehouse_code;
-- 13 Received percentage by dispatch.
SELECT dispatch_ref,SUM(quantity_received)::numeric/NULLIF(SUM(quantity_sent),0)*100 received_pct FROM nms_demo.v_dispatch_balance GROUP BY dispatch_ref;
-- 14 Batches never dispatched.
SELECT batch_code FROM nms_demo.batches b WHERE NOT EXISTS(SELECT 1 FROM nms_demo.dispatch_lines l WHERE l.batch_id=b.batch_id);
-- 15 Dispatch counts by status.
SELECT status,COUNT(*) FROM nms_demo.dispatches GROUP BY status;
-- 16 Largest dispatch-line quantities.
SELECT dispatch_ref,batch_code,quantity_sent FROM nms_demo.v_dispatch_balance ORDER BY quantity_sent DESC LIMIT 10;
-- 17 Duplicate receipt idempotency keys (should be empty).
SELECT idempotency_key,COUNT(*) FROM nms_demo.receipt_entries GROUP BY idempotency_key HAVING COUNT(*)>1;
-- 18 Batches with expiry before shipment date.
SELECT d.dispatch_ref,b.batch_code FROM nms_demo.dispatches d JOIN nms_demo.dispatch_lines l USING(dispatch_id) JOIN nms_demo.batches b USING(batch_id) WHERE b.expiry_date<d.dispatch_date;
-- 19 Dispatches by UTC month.
SELECT date_trunc('month',dispatch_date)::date dispatch_month,COUNT(*) FROM nms_demo.dispatches GROUP BY 1 ORDER BY 1;
-- 20 Lines with receipt above sent quantity (should be impossible through routine).
SELECT dispatch_ref,batch_code FROM nms_demo.v_dispatch_balance WHERE quantity_received>quantity_sent;