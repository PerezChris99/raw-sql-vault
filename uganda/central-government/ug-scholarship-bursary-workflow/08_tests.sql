-- Purpose: assertions for human decision evidence, appeal restrictions and disbursement ceilings.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures.
-- Run against a disposable database; all mutations roll back.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 BEGIN
   PERFORM ug_bursary.fn_transition_application('UGB-DEMO-0001','approved','reviewer-test','approve without evidence',NULL);
   RAISE EXCEPTION 'ASSERT approval without evidence was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 BEGIN
   PERFORM ug_bursary.fn_file_appeal('UGBA-TEST-NONREJECTED','UGB-DEMO-0001','student-ref-test','appeal a pending case','SYNTHETIC-APPEAL-EVIDENCE');
   RAISE EXCEPTION 'ASSERT appeal of non-rejected application was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 PERFORM ug_bursary.fn_file_appeal('UGBA-TEST-001','UGB-DEMO-0002','student-ref-test','request review of decision','SYNTHETIC-APPEAL-EVIDENCE');
 PERFORM ug_bursary.fn_review_appeal('UGBA-TEST-001','overturned','appeal-reviewer','evidence warrants reconsideration','SYNTHETIC-APPEAL-OUTCOME');
 SELECT COUNT(*) INTO v_count FROM ug_bursary.applications WHERE application_ref='UGB-DEMO-0002' AND status='under_review';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT overturned appeal did not reopen case for human review'; END IF;

 PERFORM ug_bursary.fn_transition_application('UGB-DEMO-0001','approved','reviewer-test','synthetic approved decision','SYNTHETIC-DECISION-EVIDENCE');
 SELECT COUNT(*) INTO v_count FROM ug_bursary.applications WHERE application_ref='UGB-DEMO-0001' AND status='approved';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT evidenced approval did not update status'; END IF;

 BEGIN
   PERFORM ug_bursary.fn_record_disbursement('UGBD-TEST-OVER','UGB-DEMO-0001','bursary-idem-test-001',750001,'UGX','SYNTHETIC-PAYMENT-OVER',now(),'finance-test');
   RAISE EXCEPTION 'ASSERT disbursement above award ceiling was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 PERFORM ug_bursary.fn_record_disbursement('UGBD-TEST-VALID','UGB-DEMO-0001','bursary-idem-test-002',100000,'UGX','SYNTHETIC-PAYMENT-VALID',now(),'finance-test');
 SELECT COUNT(*) INTO v_count FROM ug_bursary.disbursements WHERE disbursement_ref='UGBD-TEST-VALID';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT valid disbursement was not recorded'; END IF;
END;
$test$;
ROLLBACK;
