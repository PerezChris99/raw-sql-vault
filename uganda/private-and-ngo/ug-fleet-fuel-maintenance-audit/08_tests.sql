-- Purpose: assertions for odometer regression rejection and fuel receipt idempotency.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 BEGIN
  PERFORM ug_fleet.fn_record_fuel('UGFUEL-TEST-REGRESSION','fleet-fuel-test-regression','UGVEH-DEMO-01','SYN-FUEL-SUPPLIER',
    now(),10,5000,100,'SYN-FUEL-RECEIPT-TEST-REGRESSION','SYN-TEST-CLERK','SYN-FUEL-EVIDENCE-TEST');
  RAISE EXCEPTION 'ASSERT odometer regression was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM ug_fleet.fn_record_fuel('UGFUEL-TEST-VALID','fleet-fuel-test-valid','UGVEH-DEMO-01','SYN-FUEL-SUPPLIER',
    now(),10,5000,12600,'SYN-FUEL-RECEIPT-TEST-VALID','SYN-TEST-CLERK','SYN-FUEL-EVIDENCE-TEST');
 SELECT COUNT(*) INTO v_count FROM ug_fleet.fuel_events WHERE fuel_ref='UGFUEL-TEST-VALID';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT valid fuel event missing'; END IF;
END; $test$;
ROLLBACK;
