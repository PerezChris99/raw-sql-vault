-- Purpose: human review of loan applications and idempotent, balance-bounded loan transactions.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_sacco.fn_review_loan_application(
 p_application_ref TEXT,p_decision TEXT,p_decided_amount NUMERIC,p_actor_ref TEXT,p_reason_redacted TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_sacco AS $$
DECLARE a ug_sacco.loan_applications%ROWTYPE; v_loan BIGINT;
BEGIN
 IF p_decision NOT IN ('approved','rejected') OR length(btrim(COALESCE(p_actor_ref,'')))=0
 OR length(btrim(COALESCE(p_reason_redacted,'')))=0 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Decision, actor, reason and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO a FROM ug_sacco.loan_applications WHERE application_ref=p_application_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Loan application not found' USING ERRCODE='no_data_found'; END IF;
 IF a.status NOT IN ('submitted','under_review') THEN RAISE EXCEPTION 'Application is not reviewable' USING ERRCODE='check_violation'; END IF;
 IF p_decision='approved' AND (p_decided_amount IS NULL OR p_decided_amount<=0 OR p_decided_amount>a.requested_amount) THEN
  RAISE EXCEPTION 'Approved principal must be positive and not exceed requested amount' USING ERRCODE='check_violation';
 END IF;
 UPDATE ug_sacco.loan_applications SET status=p_decision,decided_amount=CASE WHEN p_decision='approved' THEN p_decided_amount ELSE NULL END,
 decision_by_ref=p_actor_ref,decision_reason_redacted=p_reason_redacted,decision_evidence_ref=p_evidence_ref,decided_at=clock_timestamp()
 WHERE application_id=a.application_id;
 IF p_decision='approved' THEN
  INSERT INTO ug_sacco.loans(loan_ref,application_id,member_id,approved_principal)
  VALUES('UGSAC-LOAN-'||substr(a.application_ref,10),a.application_id,a.member_id,p_decided_amount)
  RETURNING loan_id INTO v_loan;
 ELSE v_loan:=a.application_id; END IF;
 RETURN v_loan;
END; $$;

CREATE OR REPLACE FUNCTION ug_sacco.fn_record_loan_transaction(
 p_txn_ref TEXT,p_idempotency_key TEXT,p_loan_ref TEXT,p_txn_type TEXT,p_amount NUMERIC,
 p_external_ref TEXT,p_occurred_at TIMESTAMPTZ,p_actor_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_sacco AS $$
DECLARE l ug_sacco.loans%ROWTYPE; v_balance NUMERIC(16,2); v_disbursed NUMERIC(16,2); v_id BIGINT;
BEGIN
 IF p_txn_type NOT IN ('disbursement','repayment','principal_correction_credit','principal_correction_debit')
 OR p_amount IS NULL OR p_amount<=0 OR p_occurred_at IS NULL OR length(btrim(COALESCE(p_actor_ref,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Valid transaction type, positive amount, date, actor and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO l FROM ug_sacco.loans WHERE loan_ref=p_loan_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Loan not found' USING ERRCODE='no_data_found'; END IF;
 SELECT COALESCE(SUM(CASE WHEN txn_type IN ('disbursement','principal_correction_debit') THEN amount
                          WHEN txn_type IN ('repayment','principal_correction_credit') THEN -amount END),0)
 INTO v_balance FROM ug_sacco.loan_transactions WHERE loan_id=l.loan_id;
 SELECT COALESCE(SUM(amount),0) INTO v_disbursed FROM ug_sacco.loan_transactions WHERE loan_id=l.loan_id AND txn_type='disbursement';
 IF p_txn_type='disbursement' AND (v_disbursed>0 OR p_amount>l.approved_principal) THEN
  RAISE EXCEPTION 'Disbursement already recorded or exceeds approved principal' USING ERRCODE='check_violation';
 END IF;
 IF p_txn_type IN ('repayment','principal_correction_credit') AND p_amount>v_balance THEN
  RAISE EXCEPTION 'Repayment/correction exceeds outstanding principal' USING ERRCODE='check_violation';
 END IF;
 IF p_txn_type='principal_correction_debit' AND v_balance+p_amount>l.approved_principal THEN
  RAISE EXCEPTION 'Principal correction exceeds approved principal' USING ERRCODE='check_violation';
 END IF;
 INSERT INTO ug_sacco.loan_transactions(txn_ref,idempotency_key,loan_id,txn_type,amount,external_reference,occurred_at,recorded_by_ref,evidence_ref)
 VALUES(p_txn_ref,p_idempotency_key,l.loan_id,p_txn_type,p_amount,p_external_ref,p_occurred_at,p_actor_ref,p_evidence_ref)
 RETURNING loan_txn_id INTO v_id;
 UPDATE ug_sacco.loans SET
  disbursed_at=CASE WHEN p_txn_type='disbursement' THEN p_occurred_at ELSE disbursed_at END,
  disbursement_reference=CASE WHEN p_txn_type='disbursement' THEN p_external_ref ELSE disbursement_reference END,
  status=CASE WHEN p_txn_type='disbursement' THEN 'active'
              WHEN p_txn_type='repayment' AND v_balance-p_amount=0 THEN 'settled' ELSE status END
 WHERE loan_id=l.loan_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION ug_sacco.fn_record_savings_transaction(
 p_txn_ref TEXT,p_idempotency_key TEXT,p_account_ref TEXT,p_txn_type TEXT,p_amount NUMERIC,
 p_external_reference TEXT,p_occurred_at TIMESTAMPTZ,p_actor_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_sacco AS $$
DECLARE a ug_sacco.savings_accounts%ROWTYPE; v_balance NUMERIC(16,2); v_id BIGINT;
BEGIN
 IF p_txn_type NOT IN ('deposit','withdrawal','correction_credit','correction_debit')
 OR p_amount IS NULL OR p_amount<=0 OR p_occurred_at IS NULL
 OR length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Valid transaction type, amount, date, actor and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO a FROM ug_sacco.savings_accounts WHERE account_ref=p_account_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Savings account not found' USING ERRCODE='no_data_found'; END IF;
 IF a.status<>'open' THEN RAISE EXCEPTION 'Savings account is not open' USING ERRCODE='check_violation'; END IF;
 SELECT COALESCE(SUM(CASE WHEN txn_type IN ('deposit','correction_credit') THEN amount ELSE -amount END),0)
 INTO v_balance FROM ug_sacco.savings_transactions WHERE savings_account_id=a.savings_account_id;
 IF p_txn_type IN ('withdrawal','correction_debit') AND p_amount>v_balance THEN
  RAISE EXCEPTION 'Withdrawal/correction exceeds available savings balance' USING ERRCODE='check_violation';
 END IF;
 INSERT INTO ug_sacco.savings_transactions(txn_ref,idempotency_key,savings_account_id,txn_type,amount,external_reference,occurred_at,recorded_by_ref,evidence_ref)
 VALUES(p_txn_ref,p_idempotency_key,a.savings_account_id,p_txn_type,p_amount,p_external_reference,p_occurred_at,p_actor_ref,p_evidence_ref)
 RETURNING savings_txn_id INTO v_id;
 RETURN v_id;
END; $$;
