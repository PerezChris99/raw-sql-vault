CREATE OR REPLACE FUNCTION nms_demo.fn_record_receipt(p_receipt_ref TEXT,p_dispatch_ref TEXT,p_batch_code TEXT,p_quantity INTEGER,p_document_ref TEXT,p_idem TEXT,p_final BOOLEAN DEFAULT FALSE)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,nms_demo AS $$
DECLARE v_dispatch BIGINT;v_batch BIGINT;v_status TEXT;v_sent INTEGER;v_received BIGINT;v_lot_status TEXT;v_expiry DATE;v_old RECORD;v_id BIGINT;v_new_status TEXT;
BEGIN
 IF NULLIF(btrim(p_receipt_ref),'') IS NULL OR NULLIF(btrim(p_dispatch_ref),'') IS NULL OR NULLIF(btrim(p_batch_code),'') IS NULL OR NULLIF(btrim(p_document_ref),'') IS NULL OR NULLIF(btrim(p_idem),'') IS NULL OR p_quantity IS NULL OR p_quantity<=0 THEN
 RAISE EXCEPTION 'receipt fields required and quantity positive' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(btrim(p_idem),0));
 SELECT r.receipt_id,r.quantity_received,d.dispatch_ref,b.batch_code,r.receipt_document_ref,r.receipt_ref INTO v_old
 FROM nms_demo.receipt_entries r JOIN nms_demo.dispatches d USING(dispatch_id) JOIN nms_demo.batches b USING(batch_id)
 WHERE r.idempotency_key=btrim(p_idem);
 IF FOUND THEN
  IF v_old.quantity_received<>p_quantity OR v_old.dispatch_ref<>btrim(p_dispatch_ref) OR v_old.batch_code<>btrim(p_batch_code) OR v_old.receipt_document_ref<>btrim(p_document_ref) OR v_old.receipt_ref<>btrim(p_receipt_ref) THEN
   RAISE EXCEPTION 'idempotency key reused with different receipt payload' USING ERRCODE='23505';
  END IF;
  RETURN v_old.receipt_id;
 END IF;
 SELECT d.dispatch_id,d.status,l.batch_id,l.quantity_sent,b.batch_status,b.expiry_date
 INTO v_dispatch,v_status,v_batch,v_sent,v_lot_status,v_expiry
 FROM nms_demo.dispatches d JOIN nms_demo.dispatch_lines l USING(dispatch_id)
 JOIN nms_demo.batches b USING(batch_id)
 WHERE d.dispatch_ref=btrim(p_dispatch_ref) AND b.batch_code=btrim(p_batch_code)
 FOR UPDATE OF d,l,b;
 IF NOT FOUND OR v_status NOT IN('dispatched','disputed') THEN RAISE EXCEPTION 'active dispatched lot not found' USING ERRCODE='P0002'; END IF;
 IF v_lot_status<>'active' OR v_expiry<CURRENT_DATE THEN RAISE EXCEPTION 'cannot receive a recalled, quarantined or expired lot as usable stock' USING ERRCODE='23514'; END IF;
 SELECT COALESCE(SUM(quantity_received),0) INTO v_received FROM nms_demo.receipt_entries WHERE dispatch_id=v_dispatch AND batch_id=v_batch;
 IF v_received+p_quantity>v_sent THEN RAISE EXCEPTION 'receipt would exceed dispatched quantity' USING ERRCODE='23514'; END IF;
 INSERT INTO nms_demo.receipt_entries(receipt_ref,dispatch_id,batch_id,quantity_received,receipt_document_ref,idempotency_key)
 VALUES(btrim(p_receipt_ref),v_dispatch,v_batch,p_quantity,btrim(p_document_ref),btrim(p_idem)) RETURNING receipt_id INTO v_id;
 SELECT COALESCE(SUM(quantity_received),0) INTO v_received FROM nms_demo.receipt_entries WHERE dispatch_id=v_dispatch AND batch_id=v_batch;
 IF p_final THEN
  IF EXISTS(SELECT 1 FROM nms_demo.dispatch_lines l WHERE l.dispatch_id=v_dispatch AND
    (SELECT COALESCE(SUM(r.quantity_received),0) FROM nms_demo.receipt_entries r WHERE r.dispatch_id=l.dispatch_id AND r.batch_id=l.batch_id)<>l.quantity_sent) THEN
   v_new_status:='disputed';
  ELSE v_new_status:='received'; END IF;
  UPDATE nms_demo.dispatches SET status=v_new_status WHERE dispatch_id=v_dispatch;
  INSERT INTO nms_demo.dispatch_events(dispatch_id,previous_status,new_status,note,actor_ref)
  VALUES(v_dispatch,v_status,v_new_status,'Final receipt reconciliation recorded','receipt-routine');
 END IF;
 RETURN v_id;
END; $$;
REVOKE ALL ON FUNCTION nms_demo.fn_record_receipt(TEXT,TEXT,TEXT,INTEGER,TEXT,TEXT,BOOLEAN) FROM PUBLIC;