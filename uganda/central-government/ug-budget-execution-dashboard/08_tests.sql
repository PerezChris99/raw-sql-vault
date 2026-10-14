-- Purpose: assertions for commitment ceilings and expenditure idempotency.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 PERFORM ug_budget_exec.fn_record_expenditure('UGEXP-DEMO-001','budget-idem-test-001','UGCOM-DEMO-001',5000000,
 'SYN-PAYMENT-TEST-001',CURRENT_DATE,'SYN-FINANCE-TEST','SYN-VOUCHER-TEST-001');
 BEGIN
  PERFORM ug_budget_exec.fn_record_expenditure('UGEXP-DEMO-002','budget-idem-test-002','UGCOM-DEMO-001',999999999,
   'SYN-PAYMENT-TEST-002',CURRENT_DATE,'SYN-FINANCE-TEST','SYN-VOUCHER-TEST-002');
  RAISE EXCEPTION 'ASSERT expenditure beyond commitment was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  PERFORM ug_budget_exec.fn_record_expenditure('UGEXP-DEMO-003','budget-idem-test-001','UGCOM-DEMO-001',1000,
   'SYN-PAYMENT-TEST-003',CURRENT_DATE,'SYN-FINANCE-TEST','SYN-VOUCHER-TEST-003');
  RAISE EXCEPTION 'ASSERT duplicate idempotency key accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 SELECT COUNT(*) INTO v_count FROM ug_budget_exec.expenditures WHERE expenditure_ref='UGEXP-DEMO-001';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT valid expenditure not recorded'; END IF;
END; $test$;
ROLLBACK;
