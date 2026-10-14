-- Purpose: assertions for route-stop membership, exception reasons and idempotency.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_shift BIGINT; v_stop BIGINT; v_count BIGINT;
BEGIN
 UPDATE ug_waste.shifts SET status='active' WHERE shift_ref='UGW-SH-DEMO-01';
 PERFORM ug_waste.fn_record_pickup('UGW-PU-DEMO-001','waste-pickup-idem-001','UGW-SH-DEMO-01','UGWS-DEMO-01',
 'collected',1,'load',TIMESTAMPTZ '2026-10-16 06:30:00+03','SYN-CREW-01','SYN-PICKUP-EVIDENCE-001',NULL);
 BEGIN
  PERFORM ug_waste.fn_record_pickup('UGW-PU-DEMO-002','waste-pickup-idem-002','UGW-SH-DEMO-01','UGWS-DEMO-99',
   'collected',1,'load',now(),'SYN-CREW-01','SYN-PICKUP-EVIDENCE-002',NULL);
  RAISE EXCEPTION 'ASSERT stop from another route was accepted';
 EXCEPTION WHEN foreign_key_violation THEN NULL; END;
 BEGIN
  PERFORM ug_waste.fn_record_pickup('UGW-PU-DEMO-003','waste-pickup-idem-003','UGW-SH-DEMO-01','UGWS-DEMO-02',
   'missed',NULL,NULL,now(),'SYN-CREW-01','SYN-PICKUP-EVIDENCE-003',NULL);
  RAISE EXCEPTION 'ASSERT missed pickup without reason was accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 SELECT COUNT(*) INTO v_count FROM ug_waste.pickup_events WHERE pickup_ref='UGW-PU-DEMO-001';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT pickup event missing'; END IF;
END; $test$;
ROLLBACK;
