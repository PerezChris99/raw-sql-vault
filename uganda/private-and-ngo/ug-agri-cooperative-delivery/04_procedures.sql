CREATE OR REPLACE FUNCTION coop_demo.fn_transition_delivery(p_id BIGINT,p_to TEXT,p_note TEXT,p_actor TEXT,p_grade_ref TEXT DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,coop_demo AS $$
DECLARE v_from TEXT;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('received','quality_checked','approved','rejected') THEN RAISE EXCEPTION 'invalid delivery status' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor required' USING ERRCODE='22023'; END IF;
 SELECT status INTO v_from FROM coop_demo.deliveries WHERE delivery_id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'delivery not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN p_id; END IF;
 IF NOT((v_from='received' AND p_to IN('quality_checked','rejected')) OR
 (v_from='quality_checked' AND p_to IN('approved','rejected'))) THEN
 RAISE EXCEPTION 'delivery transition not allowed: % -> %',v_from,p_to USING ERRCODE='23514'; END IF;
 IF p_to='quality_checked' AND NULLIF(btrim(p_grade_ref),'') IS NULL THEN RAISE EXCEPTION 'quality check needs grade reference' USING ERRCODE='22023'; END IF;
 UPDATE coop_demo.deliveries SET status=p_to,grade_ref=COALESCE(NULLIF(btrim(p_grade_ref),''),grade_ref),
 approved_by_ref=CASE WHEN p_to='approved' THEN btrim(p_actor) ELSE approved_by_ref END,
 approved_at=CASE WHEN p_to='approved' THEN clock_timestamp() ELSE approved_at END,
 quality_note=COALESCE(quality_note,btrim(p_note)) WHERE delivery_id=p_id;
 INSERT INTO coop_demo.delivery_events(delivery_id,previous_status,new_status,event_note,actor_ref,grade_ref)
 VALUES(p_id,v_from,p_to,btrim(p_note),btrim(p_actor),NULLIF(btrim(p_grade_ref),''));
 RETURN p_id;
END; $$;
CREATE OR REPLACE FUNCTION coop_demo.fn_record_payment(p_ref TEXT,p_delivery_ref TEXT,p_amount NUMERIC,p_channel TEXT,p_external_ref TEXT,p_idem TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,coop_demo AS $$
DECLARE v_delivery BIGINT;v_payable NUMERIC;v_status TEXT;v_paid NUMERIC;v_old RECORD;v_id BIGINT;
BEGIN
 IF NULLIF(btrim(p_ref),'') IS NULL OR NULLIF(btrim(p_delivery_ref),'') IS NULL OR NULLIF(btrim(p_external_ref),'') IS NULL OR NULLIF(btrim(p_idem),'') IS NULL OR p_amount IS NULL OR p_amount<=0
 THEN RAISE EXCEPTION 'payment fields required and amount must be positive' USING ERRCODE='22023'; END IF;
 IF p_channel IS NULL OR p_channel NOT IN('bank_transfer','mobile_money_batch','cash_receipt','other') THEN RAISE EXCEPTION 'invalid payment channel' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(btrim(p_idem),0));
 SELECT p.payment_id,p.amount_ugx,d.delivery_ref,p.channel,p.external_reference,p.payment_ref INTO v_old
 FROM coop_demo.payments p JOIN coop_demo.deliveries d USING(delivery_id) WHERE p.idempotency_key=btrim(p_idem);
 IF FOUND THEN
  IF v_old.amount_ugx<>p_amount OR v_old.delivery_ref<>btrim(p_delivery_ref) OR v_old.channel<>p_channel OR v_old.external_reference<>btrim(p_external_ref) OR v_old.payment_ref<>btrim(p_ref) THEN
   RAISE EXCEPTION 'idempotency key reused with different payment payload' USING ERRCODE='23505';
  END IF;
  RETURN v_old.payment_id;
 END IF;
 SELECT delivery_id,payable_ugx,status INTO v_delivery,v_payable,v_status
 FROM coop_demo.deliveries WHERE delivery_ref=btrim(p_delivery_ref) FOR UPDATE;
 IF NOT FOUND OR v_status<>'approved' THEN RAISE EXCEPTION 'approved delivery not found' USING ERRCODE='P0002'; END IF;
 SELECT COALESCE(SUM(amount_ugx),0) INTO v_paid FROM coop_demo.payments WHERE delivery_id=v_delivery;
 IF v_paid+p_amount>v_payable THEN RAISE EXCEPTION 'payment exceeds approved payable balance' USING ERRCODE='23514'; END IF;
 INSERT INTO coop_demo.payments(payment_ref,delivery_id,amount_ugx,channel,external_reference,idempotency_key)
 VALUES(btrim(p_ref),v_delivery,p_amount,p_channel,btrim(p_external_ref),btrim(p_idem)) RETURNING payment_id INTO v_id;
 RETURN v_id;
END; $$;
REVOKE ALL ON FUNCTION coop_demo.fn_transition_delivery(BIGINT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION coop_demo.fn_record_payment(TEXT,TEXT,NUMERIC,TEXT,TEXT,TEXT) FROM PUBLIC;