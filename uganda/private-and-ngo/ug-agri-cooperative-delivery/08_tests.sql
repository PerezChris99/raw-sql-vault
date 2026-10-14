-- PostgreSQL 15+; test mutations are rolled back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_pay_a BIGINT;v_pay_b BIGINT;v_count BIGINT;v_paid NUMERIC;
BEGIN
 INSERT INTO coop_demo.deliveries(delivery_ref,member_id,produce_id,delivery_date,gross_kg,accepted_kg,rejected_kg,price_per_kg_ugx,grade_ref,status)
 SELECT 'TEST-AUTOPILOT-COOP',m.member_id,p.produce_id,CURRENT_DATE,10,10,0,5000,'TEST-GRADE','received'
 FROM coop_demo.members m CROSS JOIN coop_demo.produce_catalog p
 WHERE m.member_ref='DEMO-MEMBER-A1' AND p.produce_code='DEMO-COFFEE'
 ON CONFLICT(delivery_ref) DO UPDATE SET status='received',approved_by_ref=NULL,approved_at=NULL,accepted_kg=10,rejected_kg=0,gross_kg=10
 RETURNING delivery_id INTO v_id;
 DELETE FROM coop_demo.payments WHERE delivery_id=v_id;
 PERFORM coop_demo.fn_transition_delivery(v_id,'quality_checked','quality check recorded','test-suite','TEST-GRADE');
 PERFORM coop_demo.fn_transition_delivery(v_id,'approved','delivery approved','test-suite',NULL);
 v_pay_a:=coop_demo.fn_record_payment('TEST-COOP-PAY','TEST-AUTOPILOT-COOP',30000,'bank_transfer','TEST-PAY-REF','TEST-COOP-IDEM');
 v_pay_b:=coop_demo.fn_record_payment('TEST-COOP-PAY','TEST-AUTOPILOT-COOP',30000,'bank_transfer','TEST-PAY-REF','TEST-COOP-IDEM');
 IF v_pay_a<>v_pay_b THEN RAISE EXCEPTION 'ASSERT payment idempotency failed'; END IF;
 SELECT COUNT(*),SUM(amount_ugx) INTO v_count,v_paid FROM coop_demo.payments WHERE delivery_id=v_id;
 IF v_count<>1 OR v_paid<>30000 THEN RAISE EXCEPTION 'ASSERT duplicate pay entry: rows %, amount %',v_count,v_paid; END IF;
 BEGIN
  PERFORM coop_demo.fn_record_payment('TEST-COOP-PAY-OVER','TEST-AUTOPILOT-COOP',30000,'bank_transfer','TEST-PAY-REF-OVER','TEST-COOP-OVER');
  RAISE EXCEPTION 'ASSERT payment above payable accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;