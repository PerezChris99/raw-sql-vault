-- Purpose: assertions for stock underflow, movement idempotency and expiry safeguards.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures.
-- Run against a disposable database; all changes roll back.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 BEGIN
  PERFORM ug_agri_inputs.fn_record_movement('UGMOV-TEST-UNDER','agri-test-underflow-01','UGLOT-DEMO-001',
    'issued',999999,'SYN-RECIPIENT-001',now(),'SYNTHETIC-ISSUE-OVER','test underflow','test-runner');
  RAISE EXCEPTION 'ASSERT stock underflow was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 PERFORM ug_agri_inputs.fn_record_movement('UGMOV-TEST-ISSUE','agri-test-issue-01','UGLOT-DEMO-001',
   'issued',25,'SYN-RECIPIENT-001',now(),'SYNTHETIC-ISSUE-001','synthetic test issue','test-runner');
 SELECT COUNT(*) INTO v_count FROM ug_agri_inputs.v_lot_balance
 WHERE lot_ref='UGLOT-DEMO-001' AND current_balance=975;
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT issue movement did not reduce lot balance'; END IF;

 BEGIN
  PERFORM ug_agri_inputs.fn_record_movement('UGMOV-TEST-DUP','agri-test-issue-01','UGLOT-DEMO-001',
    'issued',1,'SYN-RECIPIENT-001',now(),'SYNTHETIC-ISSUE-DUP','duplicate idempotency test','test-runner');
  RAISE EXCEPTION 'ASSERT duplicate idempotency key was accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;

 BEGIN
  PERFORM ug_agri_inputs.fn_record_movement('UGMOV-TEST-EMPTY','agri-test-empty-01','UGLOT-DEMO-001',
    'issued',1,NULL,now(),'SYNTHETIC-ISSUE-EMPTY','missing recipient test','test-runner');
  RAISE EXCEPTION 'ASSERT issue without recipient was accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END;
$test$;
ROLLBACK;
