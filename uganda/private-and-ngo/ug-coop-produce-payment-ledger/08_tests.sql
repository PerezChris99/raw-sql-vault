-- Purpose: executable assertions for idempotency, weights, payment ownership and allocation limits.
-- Engine: PostgreSQL 15+. Prerequisites: 01_schema.sql, 02_seed.sql, 03_views.sql, 04_procedures.sql.
-- Run against a disposable database. Test changes are rolled back.
BEGIN;
DO $test$
DECLARE v_payment_id BIGINT; v_delivery_id BIGINT; v_count BIGINT;
BEGIN
 SELECT payment_id INTO v_payment_id FROM ug_coop_pay.payments WHERE payment_ref='UGPAY-DEMO-0001';
 IF v_payment_id IS NOT NULL THEN RAISE EXCEPTION 'ASSERT clean fixture unexpectedly contains demo payment'; END IF;

 BEGIN
   INSERT INTO ug_coop_pay.deliveries(delivery_ref,source_ticket_ref,member_ref,produce_type_id,grade_code,received_at,
     gross_weight_kg,accepted_weight_kg,status,scale_reference,recorded_by)
   SELECT 'UGD-TEST-BAD','TICKET-TEST-BAD','SYN-MEMBER-001',produce_type_id,'A',now(),10,11,'accepted','TEST-SCALE','test'
   FROM ug_coop_pay.produce_types WHERE produce_code='DEMO-COFFEE';
   RAISE EXCEPTION 'ASSERT accepted weight above gross weight was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 INSERT INTO ug_coop_pay.payments(payment_ref,member_ref,idempotency_key,amount,currency_code,payment_method_ref,source_reference,paid_at,recorded_by)
 VALUES('UGPAY-DEMO-0001','SYN-MEMBER-001','demo-payment-key-0001',200000,'UGX','SYNTHETIC-PROVIDER-REF','SYNTHETIC-PAYMENT-SOURCE',now(),'test-runner');

 BEGIN
   PERFORM ug_coop_pay.fn_allocate_payment('UGPAY-DEMO-0001','UGD-DEMO-0002',200000,'test-runner','ALLOC-TEST-OVER-DELIVERY');
   RAISE EXCEPTION 'ASSERT allocation above delivery value was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 BEGIN
   PERFORM ug_coop_pay.fn_allocate_payment('UGPAY-DEMO-0001','UGD-DEMO-0001',200001,'test-runner','ALLOC-TEST-OVER-PAYMENT');
   RAISE EXCEPTION 'ASSERT allocation above payment amount was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 BEGIN
   INSERT INTO ug_coop_pay.payments(payment_ref,member_ref,idempotency_key,amount,currency_code,payment_method_ref,source_reference,paid_at,recorded_by)
   VALUES('UGPAY-DEMO-DUP','SYN-MEMBER-001','demo-payment-key-0001',100,'UGX','SYNTHETIC-PROVIDER-REF','SYNTHETIC-DUP',now(),'test-runner');
   RAISE EXCEPTION 'ASSERT duplicate idempotency key was accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;

 SELECT COUNT(*) INTO v_count FROM ug_coop_pay.v_delivery_settlement WHERE delivery_ref='UGD-DEMO-0002';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT delivery settlement view missing fixture'; END IF;
END;
$test$;
ROLLBACK;
