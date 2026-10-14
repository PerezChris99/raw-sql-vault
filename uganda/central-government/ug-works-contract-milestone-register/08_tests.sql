-- Purpose: executable assertions for evidence requirements and contract/budget ceilings.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seeds, views and procedures.
-- Disposable DB only; this test transaction rolls back.
BEGIN;
DO $test$
DECLARE v_count BIGINT; v_contract_id BIGINT; v_milestone_id BIGINT;
BEGIN
 SELECT contract_id INTO v_contract_id FROM ug_works_contract.contracts WHERE contract_ref='UGWC-DEMO-001';
 SELECT milestone_id INTO v_milestone_id FROM ug_works_contract.milestones WHERE contract_id=v_contract_id AND milestone_code='MOB';
 INSERT INTO ug_works_contract.certificates(certificate_ref,milestone_id,submitted_amount,submitted_by_ref)
 VALUES('UGCERT-DEMO-001',v_milestone_id,12000000,'SYN-CONTRACTOR-01');
 BEGIN
  PERFORM ug_works_contract.fn_review_certificate('UGCERT-DEMO-001','approved','SYN-REVIEWER','approve without evidence',NULL);
  RAISE EXCEPTION 'ASSERT approval without evidence was accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM ug_works_contract.fn_review_certificate('UGCERT-DEMO-001','approved','SYN-REVIEWER','synthetic milestone accepted','SYN-INSPECTION-001');
 PERFORM ug_works_contract.fn_record_certificate_payment('UGCERT-DEMO-001','SYN-PAYMENT-001','SYN-FINANCE','SYN-PAYMENT-VOUCHER-001');
 SELECT COUNT(*) INTO v_count FROM ug_works_contract.certificates WHERE certificate_ref='UGCERT-DEMO-001' AND status='paid';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT approved certificate was not marked paid'; END IF;
 BEGIN
  PERFORM ug_works_contract.fn_record_certificate_payment('UGCERT-DEMO-001','SYN-PAYMENT-002','SYN-FINANCE','SYN-PAYMENT-VOUCHER-002');
  RAISE EXCEPTION 'ASSERT duplicate payment was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;
