CREATE OR REPLACE FUNCTION ngo_demo.fn_transition_milestone(p_ref TEXT,p_to TEXT,p_note TEXT,p_actor TEXT,p_evidence TEXT DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ngo_demo AS $$
DECLARE v_id BIGINT;v_from TEXT;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('planned','submitted','verified','delayed','waived') THEN RAISE EXCEPTION 'invalid milestone status' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor required' USING ERRCODE='22023'; END IF;
 IF p_to='verified' AND NULLIF(btrim(p_evidence),'') IS NULL THEN RAISE EXCEPTION 'verification requires evidence ref' USING ERRCODE='22023'; END IF;
 SELECT milestone_id,status INTO v_id,v_from FROM ngo_demo.milestones WHERE milestone_ref=btrim(p_ref) FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'milestone not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN v_id; END IF;
 IF NOT((v_from='planned' AND p_to IN('submitted','delayed','waived')) OR
 (v_from='submitted' AND p_to IN('verified','delayed')) OR
 (v_from='delayed' AND p_to IN('submitted','waived'))) THEN
 RAISE EXCEPTION 'milestone transition not allowed: % -> %',v_from,p_to USING ERRCODE='23514'; END IF;
 UPDATE ngo_demo.milestones SET status=p_to,
 evidence_ref=COALESCE(NULLIF(btrim(p_evidence),''),evidence_ref),
 verified_by_ref=CASE WHEN p_to='verified' THEN btrim(p_actor) ELSE verified_by_ref END,
 verified_at=CASE WHEN p_to='verified' THEN clock_timestamp() ELSE verified_at END WHERE milestone_id=v_id;
 INSERT INTO ngo_demo.milestone_events(milestone_id,previous_status,new_status,note,actor_ref)
 VALUES(v_id,v_from,p_to,btrim(p_note),btrim(p_actor));
 RETURN v_id;
END; $$;
CREATE OR REPLACE FUNCTION ngo_demo.fn_record_expenditure(p_ref TEXT,p_grant_ref TEXT,p_date DATE,p_amount NUMERIC,p_currency CHAR(3),p_category TEXT,p_source TEXT,p_idem TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ngo_demo AS $$
DECLARE v_grant BIGINT;v_ceiling NUMERIC;v_currency CHAR(3);v_status TEXT;v_spent NUMERIC;v_old RECORD;v_id BIGINT;
BEGIN
 IF NULLIF(btrim(p_ref),'') IS NULL OR NULLIF(btrim(p_grant_ref),'') IS NULL OR NULLIF(btrim(p_source),'') IS NULL OR NULLIF(btrim(p_idem),'') IS NULL OR p_date IS NULL OR p_amount IS NULL OR p_amount<=0 THEN RAISE EXCEPTION 'expenditure fields required and amount positive' USING ERRCODE='22023'; END IF;
 IF p_category IS NULL OR p_category NOT IN('personnel_aggregate','supplies','transport','service_contract','grant_transfer','other') THEN RAISE EXCEPTION 'invalid expenditure category' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(btrim(p_idem),0));
 SELECT e.expenditure_id,e.amount,e.currency,e.expense_category,e.source_document_ref,e.expenditure_ref,g.grant_ref,e.expense_date INTO v_old
 FROM ngo_demo.expenditures e JOIN ngo_demo.grants g USING(grant_id) WHERE e.idempotency_key=btrim(p_idem);
 IF FOUND THEN
  IF v_old.amount<>p_amount OR v_old.currency<>p_currency OR v_old.expense_category<>p_category OR v_old.source_document_ref<>btrim(p_source) OR v_old.expenditure_ref<>btrim(p_ref) OR v_old.grant_ref<>btrim(p_grant_ref) OR v_old.expense_date<>p_date THEN
   RAISE EXCEPTION 'idempotency key reused with different expenditure payload' USING ERRCODE='23505'; END IF;
  RETURN v_old.expenditure_id;
 END IF;
 SELECT grant_id,award_ceiling,grant_currency,status INTO v_grant,v_ceiling,v_currency,v_status
 FROM ngo_demo.grants WHERE grant_ref=btrim(p_grant_ref) FOR UPDATE;
 IF NOT FOUND OR v_status<>'active' THEN RAISE EXCEPTION 'active grant not found' USING ERRCODE='P0002'; END IF;
 IF p_currency<>v_currency THEN RAISE EXCEPTION 'expenditure currency differs from grant currency' USING ERRCODE='22023'; END IF;
 IF p_date<(SELECT start_date FROM ngo_demo.grants WHERE grant_id=v_grant) OR p_date>(SELECT end_date FROM ngo_demo.grants WHERE grant_id=v_grant) THEN RAISE EXCEPTION 'expense date outside grant term' USING ERRCODE='22007'; END IF;
 SELECT COALESCE(SUM(amount),0) INTO v_spent FROM ngo_demo.expenditures WHERE grant_id=v_grant;
 IF v_spent+p_amount>v_ceiling THEN RAISE EXCEPTION 'expenditure exceeds grant ceiling' USING ERRCODE='23514'; END IF;
 INSERT INTO ngo_demo.expenditures(expenditure_ref,grant_id,expense_date,expense_category,amount,currency,source_document_ref,idempotency_key)
 VALUES(btrim(p_ref),v_grant,p_date,p_category,p_amount,p_currency,btrim(p_source),btrim(p_idem)) RETURNING expenditure_id INTO v_id;
 RETURN v_id;
END; $$;
REVOKE ALL ON FUNCTION ngo_demo.fn_transition_milestone(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ngo_demo.fn_record_expenditure(TEXT,TEXT,DATE,NUMERIC,CHAR,TEXT,TEXT,TEXT) FROM PUBLIC;