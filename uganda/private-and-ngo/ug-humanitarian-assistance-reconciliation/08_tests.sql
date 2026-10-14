-- Purpose: assertions for human authorisation, delivery ceiling and idempotency.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 PERFORM ug_aid.fn_record_delivery('UGAID-D-DEMO-001','aid-delivery-idem-test-001','UGAID-A-DEMO-001',0.5,'delivered',
  now(),'SYN-DELIVERY-POINT-001','SYN-AID-CLERK','SYN-DELIVERY-EVIDENCE-001',NULL);
 BEGIN
  PERFORM ug_aid.fn_record_delivery('UGAID-D-DEMO-002','aid-delivery-idem-test-002','UGAID-A-DEMO-001',2,'delivered',
   now(),'SYN-DELIVERY-POINT-001','SYN-AID-CLERK','SYN-DELIVERY-EVIDENCE-002',NULL);
  RAISE EXCEPTION 'ASSERT delivery above approved quantity was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  PERFORM ug_aid.fn_record_delivery('UGAID-D-DEMO-003','aid-delivery-idem-test-001','UGAID-A-DEMO-001',0.1,'delivered',
   now(),'SYN-DELIVERY-POINT-001','SYN-AID-CLERK','SYN-DELIVERY-EVIDENCE-003',NULL);
  RAISE EXCEPTION 'ASSERT duplicate delivery idempotency key was accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;
 SELECT COUNT(*) INTO v_count FROM ug_aid.deliveries WHERE delivery_ref='UGAID-D-DEMO-001';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT valid delivery missing'; END IF;
END; $test$;
ROLLBACK;
