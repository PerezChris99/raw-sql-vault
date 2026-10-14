CREATE OR REPLACE FUNCTION finance_demo.fn_record_release(p_ref TEXT,p_line_code TEXT,p_date DATE,p_amount NUMERIC,p_source_ref TEXT,p_idem TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,finance_demo AS $$
DECLARE v_line BIGINT;v_fy INTEGER;v_ceiling NUMERIC;v_status TEXT;v_total NUMERIC;v_old RECORD;v_id BIGINT;
BEGIN
 IF NULLIF(btrim(p_ref),'') IS NULL OR NULLIF(btrim(p_line_code),'') IS NULL OR NULLIF(btrim(p_source_ref),'') IS NULL OR NULLIF(btrim(p_idem),'') IS NULL OR p_date IS NULL OR p_amount IS NULL OR p_amount<=0
 THEN RAISE EXCEPTION 'release fields must be provided and amount positive' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(btrim(p_idem),0));
 SELECT x.release_id,x.amount_ugx,b.budget_line_code,x.release_date,x.release_ref,x.source_document_ref INTO v_old
 FROM finance_demo.releases x JOIN finance_demo.budget_lines b USING(budget_line_id) WHERE x.idempotency_key=btrim(p_idem);
 IF FOUND THEN
  IF v_old.amount_ugx<>p_amount OR v_old.budget_line_code<>btrim(p_line_code) OR v_old.release_date<>p_date OR v_old.release_ref<>btrim(p_ref) OR v_old.source_document_ref<>btrim(p_source_ref) THEN
   RAISE EXCEPTION 'idempotency key reused with different release payload' USING ERRCODE='23505';
  END IF;
  RETURN v_old.release_id;
 END IF;
 SELECT budget_line_id,fiscal_year_start,approved_ceiling_ugx,line_status INTO v_line,v_fy,v_ceiling,v_status
 FROM finance_demo.budget_lines WHERE budget_line_code=btrim(p_line_code) FOR UPDATE;
 IF NOT FOUND OR v_status<>'active' THEN RAISE EXCEPTION 'active budget line not found' USING ERRCODE='P0002'; END IF;
 IF p_date<make_date(v_fy,7,1) OR p_date>=make_date(v_fy+1,7,1) THEN RAISE EXCEPTION 'release date outside configured fiscal year' USING ERRCODE='22007'; END IF;
 SELECT COALESCE(SUM(amount_ugx),0) INTO v_total FROM finance_demo.releases WHERE budget_line_id=v_line;
 IF v_total+p_amount>v_ceiling THEN RAISE EXCEPTION 'release would exceed approved ceiling' USING ERRCODE='23514'; END IF;
 INSERT INTO finance_demo.releases(release_ref,budget_line_id,release_date,amount_ugx,source_document_ref,idempotency_key)
 VALUES(btrim(p_ref),v_line,p_date,p_amount,btrim(p_source_ref),btrim(p_idem)) RETURNING release_id INTO v_id;
 RETURN v_id;
END; $$;
CREATE OR REPLACE FUNCTION finance_demo.fn_record_expenditure(p_ref TEXT,p_line_code TEXT,p_date DATE,p_amount NUMERIC,p_type TEXT,p_source_ref TEXT,p_idem TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,finance_demo AS $$
DECLARE v_line BIGINT;v_fy INTEGER;v_status TEXT;v_released NUMERIC;v_spent NUMERIC;v_old RECORD;v_id BIGINT;
BEGIN
 IF NULLIF(btrim(p_ref),'') IS NULL OR NULLIF(btrim(p_line_code),'') IS NULL OR NULLIF(btrim(p_source_ref),'') IS NULL OR NULLIF(btrim(p_idem),'') IS NULL OR p_date IS NULL OR p_amount IS NULL OR p_amount<=0
 THEN RAISE EXCEPTION 'expenditure fields must be provided and amount positive' USING ERRCODE='22023'; END IF;
 IF p_type IS NULL OR p_type NOT IN('goods','services','payroll_aggregate','transfer','other') THEN RAISE EXCEPTION 'invalid expenditure type' USING ERRCODE='22023'; END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(btrim(p_idem),0));
 SELECT x.expenditure_id,x.amount_ugx,b.budget_line_code,x.expenditure_date,x.expenditure_ref,x.source_document_ref,x.expenditure_type INTO v_old
 FROM finance_demo.expenditures x JOIN finance_demo.budget_lines b USING(budget_line_id) WHERE x.idempotency_key=btrim(p_idem);
 IF FOUND THEN
  IF v_old.amount_ugx<>p_amount OR v_old.budget_line_code<>btrim(p_line_code) OR v_old.expenditure_date<>p_date OR v_old.expenditure_ref<>btrim(p_ref) OR v_old.source_document_ref<>btrim(p_source_ref) OR v_old.expenditure_type<>p_type THEN
   RAISE EXCEPTION 'idempotency key reused with different expenditure payload' USING ERRCODE='23505';
  END IF;
  RETURN v_old.expenditure_id;
 END IF;
 SELECT budget_line_id,fiscal_year_start,line_status INTO v_line,v_fy,v_status FROM finance_demo.budget_lines WHERE budget_line_code=btrim(p_line_code) FOR UPDATE;
 IF NOT FOUND OR v_status<>'active' THEN RAISE EXCEPTION 'active budget line not found' USING ERRCODE='P0002'; END IF;
 IF p_date<make_date(v_fy,7,1) OR p_date>=make_date(v_fy+1,7,1) THEN RAISE EXCEPTION 'expenditure date outside configured fiscal year' USING ERRCODE='22007'; END IF;
 SELECT COALESCE(SUM(amount_ugx),0) INTO v_released FROM finance_demo.releases WHERE budget_line_id=v_line;
 SELECT COALESCE(SUM(amount_ugx),0) INTO v_spent FROM finance_demo.expenditures WHERE budget_line_id=v_line;
 IF v_spent+p_amount>v_released THEN RAISE EXCEPTION 'expenditure would exceed recorded releases' USING ERRCODE='23514'; END IF;
 INSERT INTO finance_demo.expenditures(expenditure_ref,budget_line_id,expenditure_date,amount_ugx,expenditure_type,source_document_ref,idempotency_key)
 VALUES(btrim(p_ref),v_line,p_date,p_amount,p_type,btrim(p_source_ref),btrim(p_idem)) RETURNING expenditure_id INTO v_id;
 RETURN v_id;
END; $$;
REVOKE ALL ON FUNCTION finance_demo.fn_record_release(TEXT,TEXT,DATE,NUMERIC,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION finance_demo.fn_record_expenditure(TEXT,TEXT,DATE,NUMERIC,TEXT,TEXT,TEXT) FROM PUBLIC;