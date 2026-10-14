CREATE OR REPLACE FUNCTION subscription_demo.fn_transition_subscription(p_ref TEXT,p_to TEXT,p_note TEXT,p_actor TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,subscription_demo AS $$
DECLARE v_id BIGINT;v_from TEXT;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('trialing','active','past_due','cancelled') THEN RAISE EXCEPTION 'invalid subscription status' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor required' USING ERRCODE='22023'; END IF;
 SELECT subscription_id,status INTO v_id,v_from FROM subscription_demo.subscriptions WHERE subscription_ref=btrim(p_ref) FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'subscription not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN v_id; END IF;
 IF NOT((v_from='trialing' AND p_to IN('active','cancelled')) OR
 (v_from='active' AND p_to IN('past_due','cancelled')) OR
 (v_from='past_due' AND p_to IN('active','cancelled'))) THEN
 RAISE EXCEPTION 'subscription transition not allowed: % -> %',v_from,p_to USING ERRCODE='23514'; END IF;
 UPDATE subscription_demo.subscriptions SET status=p_to WHERE subscription_id=v_id;
 RETURN v_id;
END; $$;
CREATE OR REPLACE FUNCTION subscription_demo.fn_record_payment(p_payment_ref TEXT,p_invoice_ref TEXT,p_amount NUMERIC,p_currency CHAR(3),p_external_ref TEXT,p_idem TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,subscription_demo AS $$
DECLARE v_invoice BIGINT;v_due NUMERIC;v_currency CHAR(3);v_status TEXT;v_paid NUMERIC;v_old RECORD;v_id BIGINT;
BEGIN
 IF NULLIF(btrim(p_payment_ref),'') IS NULL OR NULLIF(btrim(p_invoice_ref),'') IS NULL OR NULLIF(btrim(p_external_ref),'') IS NULL OR NULLIF(btrim(p_idem),'') IS NULL OR p_amount IS NULL OR p_amount<=0 THEN
 RAISE EXCEPTION 'payment fields required and amount positive' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(btrim(p_idem),0));
 SELECT p.payment_id,p.amount,i.invoice_ref,p.currency,p.external_reference,p.payment_ref INTO v_old
 FROM subscription_demo.payments p JOIN subscription_demo.invoices i USING(invoice_id)
 WHERE p.idempotency_key=btrim(p_idem);
 IF FOUND THEN
  IF v_old.amount<>p_amount OR v_old.invoice_ref<>btrim(p_invoice_ref) OR v_old.currency<>p_currency OR v_old.external_reference<>btrim(p_external_ref) OR v_old.payment_ref<>btrim(p_payment_ref)
  THEN RAISE EXCEPTION 'idempotency key reused with different payment payload' USING ERRCODE='23505'; END IF;
  RETURN v_old.payment_id;
 END IF;
 SELECT invoice_id,amount_due,currency,status INTO v_invoice,v_due,v_currency,v_status
 FROM subscription_demo.invoices WHERE invoice_ref=btrim(p_invoice_ref) FOR UPDATE;
 IF NOT FOUND OR v_status NOT IN('open','failed') THEN RAISE EXCEPTION 'invoice is not payable' USING ERRCODE='23514'; END IF;
 IF p_currency<>v_currency THEN RAISE EXCEPTION 'payment currency differs from invoice currency' USING ERRCODE='22023'; END IF;
 SELECT COALESCE(SUM(amount),0) INTO v_paid FROM subscription_demo.payments WHERE invoice_id=v_invoice;
 IF v_paid+p_amount>v_due THEN RAISE EXCEPTION 'payment exceeds invoice outstanding balance' USING ERRCODE='23514'; END IF;
 INSERT INTO subscription_demo.payments(payment_ref,invoice_id,amount,currency,external_reference,idempotency_key)
 VALUES(btrim(p_payment_ref),v_invoice,p_amount,p_currency,btrim(p_external_ref),btrim(p_idem)) RETURNING payment_id INTO v_id;
 IF v_paid+p_amount=v_due THEN
  UPDATE subscription_demo.invoices SET status='paid',paid_at=clock_timestamp() WHERE invoice_id=v_invoice;
  INSERT INTO subscription_demo.invoice_events(invoice_id,previous_status,new_status,note,actor_ref)
  VALUES(v_invoice,v_status,'paid','Invoice balance fully settled by recorded payments','payment-routine');
 END IF;
 RETURN v_id;
END; $$;
REVOKE ALL ON FUNCTION subscription_demo.fn_transition_subscription(TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION subscription_demo.fn_record_payment(TEXT,TEXT,NUMERIC,CHAR,TEXT,TEXT) FROM PUBLIC;