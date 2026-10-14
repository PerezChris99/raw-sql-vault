-- Purpose: assertions for evidence requirements, one-time review and variation value guards.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_award BIGINT; v_id BIGINT; v_count BIGINT;
BEGIN
 SELECT award_id INTO v_award FROM ug_procurement.awards WHERE award_ref='UGPA-DEMO-001';
 INSERT INTO ug_procurement.contract_variations(variation_ref,award_id,value_delta,reason,evidence_ref,requested_by_ref)
 VALUES('UGPV-DEMO-001',v_award,1000000,'Synthetic scope adjustment','SYN-VARIATION-REQUEST-001','SYN-PROJECT-OFFICER');
 BEGIN
  PERFORM ug_procurement.fn_review_variation('UGPV-DEMO-001','approved','SYN-REVIEWER',NULL);
  RAISE EXCEPTION 'ASSERT variation without review evidence was approved';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM ug_procurement.fn_review_variation('UGPV-DEMO-001','approved','SYN-REVIEWER','SYN-VARIATION-REVIEW-001');
 SELECT COUNT(*) INTO v_count FROM ug_procurement.contract_variations WHERE variation_ref='UGPV-DEMO-001' AND status='approved';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT valid variation was not approved'; END IF;
 BEGIN
  PERFORM ug_procurement.fn_review_variation('UGPV-DEMO-001','rejected','SYN-REVIEWER','SYN-VARIATION-REVIEW-002');
  RAISE EXCEPTION 'ASSERT second review of variation was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;
