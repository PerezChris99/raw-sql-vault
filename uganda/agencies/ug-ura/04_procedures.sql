CREATE OR REPLACE FUNCTION ura_demo.fn_transition_filing(p_ref TEXT,p_to TEXT,p_note TEXT,p_actor TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ura_demo AS $$
DECLARE v_id BIGINT;v_from TEXT;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('draft','filed','assessed','amended','closed','disputed') THEN RAISE EXCEPTION 'invalid filing status' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor required' USING ERRCODE='22023'; END IF;
 SELECT filing_id,status INTO v_id,v_from FROM ura_demo.filings WHERE filing_ref=btrim(p_ref) FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'filing not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN v_id; END IF;
 IF NOT((v_from='draft' AND p_to IN('filed','closed')) OR
 (v_from='filed' AND p_to IN('assessed','amended','disputed')) OR
 (v_from='assessed' AND p_to IN('amended','closed','disputed')) OR
 (v_from='amended' AND p_to IN('filed','assessed','disputed')) OR
 (v_from='disputed' AND p_to IN('assessed','amended','closed'))) THEN
 RAISE EXCEPTION 'filing transition not allowed: % -> %',v_from,p_to USING ERRCODE='23514'; END IF;
 UPDATE ura_demo.filings SET status=p_to WHERE filing_id=v_id;
 INSERT INTO ura_demo.filing_events(filing_id,previous_status,new_status,note,actor_ref)
 VALUES(v_id,v_from,p_to,btrim(p_note),btrim(p_actor));
 RETURN v_id;
END; $$;
CREATE OR REPLACE FUNCTION ura_demo.fn_record_payment(p_payment_ref TEXT,p_filing_ref TEXT,p_date DATE,p_amount NUMERIC,p_currency CHAR(3),p_channel TEXT,p_external_ref TEXT,p_idem TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ura_demo AS $$
DECLARE v_filing BIGINT;v_due NUMERIC;v_currency CHAR(3);v_status TEXT;v_paid NUMERIC;v_old RECORD;v_id BIGINT;
BEGIN
 IF NULLIF(btrim(p_payment_ref),'') IS NULL OR NULLIF(btrim(p_filing_ref),'') IS NULL OR NULLIF(btrim(p_external_ref),'') IS NULL OR NULLIF(btrim(p_idem),'') IS NULL OR p_date IS NULL OR p_amount IS NULL OR p_amount<=0 THEN
 RAISE EXCEPTION 'payment fields required and amount positive' USING ERRCODE='22023'; END IF;
 IF p_channel IS NULL OR p_channel NOT IN('bank_transfer','mobile_money_batch','bank_slip','other') THEN RAISE EXCEPTION 'invalid payment channel' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(btrim(p_idem),0));
 SELECT p.payment_id,p.amount,f.filing_ref,p.currency,p.channel,p.external_reference,p.payment_ref,p.payment_date INTO v_old
 FROM ura_demo.payments p JOIN ura_demo.filings f USING(filing_id) WHERE p.idempotency_key=btrim(p_idem);
 IF FOUND THEN
  IF v_old.amount<>p_amount OR v_old.filing_ref<>btrim(p_filing_ref) OR v_old.currency<>p_currency OR v_old.channel<>p_channel OR v_old.external_reference<>btrim(p_external_ref) OR v_old.payment_ref<>btrim(p_payment_ref) OR v_old.payment_date<>p_date THEN
   RAISE EXCEPTION 'idempotency key reused with different payment payload' USING ERRCODE='23505'; END IF;
  RETURN v_old.payment_id;
 END IF;
 SELECT filing_id,assessed_payable,currency,status INTO v_filing,v_due,v_currency,v_status FROM ura_demo.filings WHERE filing_ref=btrim(p_filing_ref) FOR UPDATE;
 IF NOT FOUND OR v_status NOT IN('assessed','amended','disputed') THEN RAISE EXCEPTION 'filing not in a payable state' USING ERRCODE='23514'; END IF;
 IF p_currency<>v_currency THEN RAISE EXCEPTION 'payment currency does not match filing currency' USING ERRCODE='22023'; END IF;
 SELECT COALESCE(SUM(amount),0) INTO v_paid FROM ura_demo.payments WHERE filing_id=v_filing;
 IF v_paid+p_amount>v_due THEN RAISE EXCEPTION 'payment exceeds assessed payable balance' USING ERRCODE='23514'; END IF;
 INSERT INTO ura_demo.payments(payment_ref,filing_id,payment_date,amount,currency,channel,external_reference,idempotency_key)
 VALUES(btrim(p_payment_ref),v_filing,p_date,p_amount,p_currency,p_channel,btrim(p_external_ref),btrim(p_idem)) RETURNING payment_id INTO v_id;
 RETURN v_id;
END; $$;
REVOKE ALL ON FUNCTION ura_demo.fn_transition_filing(TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ura_demo.fn_record_payment(TEXT,TEXT,DATE,NUMERIC,CHAR,TEXT,TEXT,TEXT) FROM PUBLIC;