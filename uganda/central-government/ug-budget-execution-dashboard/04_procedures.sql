-- Purpose: record a bounded expenditure against a commitment with idempotency and evidence.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_budget_exec.fn_record_expenditure(
 p_expenditure_ref TEXT,p_idempotency_key TEXT,p_commitment_ref TEXT,p_amount NUMERIC,
 p_payment_reference TEXT,p_paid_on DATE,p_actor_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_budget_exec AS $$
DECLARE c ug_budget_exec.commitments%ROWTYPE; v_spent NUMERIC(16,2); v_id BIGINT;
BEGIN
 IF p_amount IS NULL OR p_amount<=0 OR p_paid_on IS NULL OR length(btrim(COALESCE(p_actor_ref,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Positive amount, date, actor and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO c FROM ug_budget_exec.commitments WHERE commitment_ref=p_commitment_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Commitment not found' USING ERRCODE='no_data_found'; END IF;
 IF c.status NOT IN ('open','partially_settled') THEN RAISE EXCEPTION 'Commitment is not payable' USING ERRCODE='check_violation'; END IF;
 SELECT COALESCE(SUM(amount),0) INTO v_spent FROM ug_budget_exec.expenditures WHERE commitment_id=c.commitment_id;
 IF v_spent+p_amount>c.amount THEN RAISE EXCEPTION 'Expenditure exceeds commitment balance' USING ERRCODE='check_violation'; END IF;
 INSERT INTO ug_budget_exec.expenditures(expenditure_ref,idempotency_key,commitment_id,amount,payment_reference,paid_on,recorded_by_ref,evidence_ref)
 VALUES(p_expenditure_ref,p_idempotency_key,c.commitment_id,p_amount,p_payment_reference,p_paid_on,p_actor_ref,p_evidence_ref)
 RETURNING expenditure_id INTO v_id;
 UPDATE ug_budget_exec.commitments SET status=CASE WHEN v_spent+p_amount=c.amount THEN 'settled' ELSE 'partially_settled' END
 WHERE commitment_id=c.commitment_id;
 RETURN v_id;
END; $$;
