-- Purpose: assertions for stock underflow and duplicate movement idempotency.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seeds and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 BEGIN
  PERFORM ug_textbooks.fn_record_movement('UGTB-MV-TEST-OVER','UGTB-WH-DEMO-01','SYN-MATH-P4','dispatch',999999,
   'SYN-DISPATCH-OVER','underflow test','SYN-TEST-CLERK','textbook-overflow-test-001');
  RAISE EXCEPTION 'ASSERT dispatch beyond stock was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM ug_textbooks.fn_record_movement('UGTB-MV-TEST-RECEIPT','UGTB-WH-DEMO-01','SYN-MATH-P4','receipt',10,
   'SYN-RECEIPT-TEST','synthetic receipt','SYN-TEST-CLERK','textbook-receipt-test-001');
 SELECT COUNT(*) INTO v_count FROM ug_textbooks.stock_movements WHERE movement_ref='UGTB-MV-TEST-RECEIPT';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT valid stock receipt missing'; END IF;
 BEGIN
  PERFORM ug_textbooks.fn_record_movement('UGTB-MV-TEST-RECEIPT-2','UGTB-WH-DEMO-01','SYN-MATH-P4','receipt',10,
   'SYN-RECEIPT-TEST','duplicate idempotency key','SYN-TEST-CLERK','textbook-receipt-test-001');
  RAISE EXCEPTION 'ASSERT duplicate idempotency key accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
END; $test$;
ROLLBACK;
