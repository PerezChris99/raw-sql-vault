-- Purpose: assertions for transition controls, referral prerequisites and evidence-gated closure.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures.
-- Run against a disposable database; all changes roll back.
BEGIN;
DO $test$
DECLARE v_count BIGINT; v_status TEXT;
BEGIN
 BEGIN
  PERFORM ug_public_case.fn_transition_case('UGCASE-DEMO-0002','resolved','test-triage','resolve without evidence',NULL);
  RAISE EXCEPTION 'ASSERT case resolved without evidence';
 EXCEPTION WHEN check_violation THEN NULL; END;

 BEGIN
  PERFORM ug_public_case.fn_create_referral('UGREF-TEST-001','UGCASE-DEMO-0002','SYN-OFFICE-01','refer before triage',
    'SYNTHETIC-REFERRAL-EVIDENCE',now()+INTERVAL '24 hours','test-triage');
  RAISE EXCEPTION 'ASSERT referral from untriaged case was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 PERFORM ug_public_case.fn_create_referral('UGREF-TEST-001','UGCASE-DEMO-0001','SYN-OFFICE-01','synthetic referral',
   'SYNTHETIC-REFERRAL-EVIDENCE',now()+INTERVAL '72 hours','test-triage');
 SELECT COUNT(*) INTO v_count FROM ug_public_case.cases WHERE case_ref='UGCASE-DEMO-0001' AND status='referred';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT referral did not transition parent case'; END IF;

 PERFORM ug_public_case.fn_transition_case('UGCASE-DEMO-0001','awaiting_response','test-triage','await referral response',NULL);
 PERFORM ug_public_case.fn_transition_case('UGCASE-DEMO-0001','resolved','test-triage','evidence confirms resolution','SYNTHETIC-RESOLUTION-EVIDENCE');
 BEGIN
  PERFORM ug_public_case.fn_transition_case('UGCASE-DEMO-0001','closed','test-triage','close without evidence',NULL);
  RAISE EXCEPTION 'ASSERT case closed without evidence';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM ug_public_case.fn_transition_case('UGCASE-DEMO-0001','closed','test-triage','close after resolution','SYNTHETIC-CLOSURE-EVIDENCE');
 SELECT status INTO v_status FROM ug_public_case.cases WHERE case_ref='UGCASE-DEMO-0001';
 IF v_status<>'closed' THEN RAISE EXCEPTION 'ASSERT resolved case did not close'; END IF;
END;
$test$;
ROLLBACK;
