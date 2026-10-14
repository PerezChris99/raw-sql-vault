-- Purpose: assertions for human loan approval and principal-bound transaction recording.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT; v_loan_ref TEXT;
BEGIN
 BEGIN
  PERFORM ug_sacco.fn_review_loan_application('UGSAC-LA-DEMO-001','approved',999999999,'SYN-REVIEWER','over ceiling','SYN-LOAN-DECISION');
  RAISE EXCEPTION 'ASSERT approved principal above request was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM ug_sacco.fn_review_loan_application('UGSAC-LA-DEMO-001','approved',400000,'SYN-REVIEWER','synthetic human decision','SYN-LOAN-DECISION-001');
 SELECT loan_ref INTO v_loan_ref FROM ug_sacco.loans WHERE application_id=(SELECT application_id FROM ug_sacco.loan_applications WHERE application_ref='UGSAC-LA-DEMO-001');
 PERFORM ug_sacco.fn_record_loan_transaction('UGSAC-LT-DEMO-001','sacco-loan-idem-001',v_loan_ref,'disbursement',400000,
 'SYN-LOAN-DISBURSEMENT-001',now(),'SYN-FINANCE-CLERK','SYN-DISBURSEMENT-EVIDENCE-001');
 BEGIN
  PERFORM ug_sacco.fn_record_loan_transaction('UGSAC-LT-DEMO-002','sacco-loan-idem-002',v_loan_ref,'repayment',500000,
   'SYN-LOAN-REPAYMENT-OVER',now(),'SYN-FINANCE-CLERK','SYN-REPAYMENT-EVIDENCE-001');
  RAISE EXCEPTION 'ASSERT repayment above principal was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM ug_sacco.fn_record_loan_transaction('UGSAC-LT-DEMO-003','sacco-loan-idem-003',v_loan_ref,'repayment',400000,
 'SYN-LOAN-REPAYMENT-001',now(),'SYN-FINANCE-CLERK','SYN-REPAYMENT-EVIDENCE-002');
 SELECT COUNT(*) INTO v_count FROM ug_sacco.loans WHERE loan_ref=v_loan_ref AND status='settled';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT loan did not settle at zero principal'; END IF;
END; $test$;
ROLLBACK;
