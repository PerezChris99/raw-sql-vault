-- PostgreSQL 15+; all test writes roll back.
BEGIN;
DO $test$
DECLARE v_dispatch BIGINT;v_batch BIGINT;v_receipt_a BIGINT;v_receipt_b BIGINT;v_received BIGINT;v_status TEXT;
BEGIN
 INSERT INTO nms_demo.dispatches(dispatch_ref,warehouse_id,facility_id,dispatch_date,status,dispatch_document_ref)
 SELECT 'TEST-AUTOPILOT-NMS',w.warehouse_id,f.facility_id,CURRENT_DATE,'dispatched','TEST-DN'
 FROM nms_demo.warehouses w CROSS JOIN nms_demo.facilities f WHERE w.warehouse_code='DEMO-WH-001' AND f.facility_code='DEMO-FAC-001'
 ON CONFLICT(dispatch_ref) DO UPDATE SET status='dispatched'
 RETURNING dispatch_id INTO v_dispatch;
 SELECT batch_id INTO v_batch FROM nms_demo.batches WHERE batch_code='DEMO-LOT-A';
 INSERT INTO nms_demo.dispatch_lines(dispatch_id,batch_id,quantity_sent) VALUES(v_dispatch,v_batch,10)
 ON CONFLICT(dispatch_id,batch_id) DO UPDATE SET quantity_sent=10;
 DELETE FROM nms_demo.receipt_entries WHERE dispatch_id=v_dispatch;
 DELETE FROM nms_demo.dispatch_events WHERE dispatch_id=v_dispatch;
 v_receipt_a:=nms_demo.fn_record_receipt('TEST-NMS-REC-1','TEST-AUTOPILOT-NMS','DEMO-LOT-A',6,'TEST-GRN-1','TEST-NMS-IDEM-1',FALSE);
 v_receipt_b:=nms_demo.fn_record_receipt('TEST-NMS-REC-1','TEST-AUTOPILOT-NMS','DEMO-LOT-A',6,'TEST-GRN-1','TEST-NMS-IDEM-1',FALSE);
 IF v_receipt_a<>v_receipt_b THEN RAISE EXCEPTION 'ASSERT receipt idempotency failed'; END IF;
 BEGIN
  PERFORM nms_demo.fn_record_receipt('TEST-NMS-REC-OVER','TEST-AUTOPILOT-NMS','DEMO-LOT-A',5,'TEST-GRN-OVER','TEST-NMS-IDEM-OVER',FALSE);
  RAISE EXCEPTION 'ASSERT over-receipt accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM nms_demo.fn_record_receipt('TEST-NMS-REC-2','TEST-AUTOPILOT-NMS','DEMO-LOT-A',4,'TEST-GRN-2','TEST-NMS-IDEM-2',TRUE);
 SELECT SUM(quantity_received) INTO v_received FROM nms_demo.receipt_entries WHERE dispatch_id=v_dispatch AND batch_id=v_batch;
 SELECT status INTO v_status FROM nms_demo.dispatches WHERE dispatch_id=v_dispatch;
 IF v_received<>10 OR v_status<>'received' THEN RAISE EXCEPTION 'ASSERT final receipt reconciliation failed'; END IF;
END; $test$;
ROLLBACK;