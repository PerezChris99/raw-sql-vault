-- Purpose: assertions for independent verification and evidence-backed closure.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT;
BEGIN
 BEGIN
  PERFORM ug_cyber.fn_record_verification('UGFIND-DEMO-001','SYN-SECURITY-OWNER','pass','SYN-VERIFY-EVIDENCE','self verify');
  RAISE EXCEPTION 'ASSERT remediation owner independently verified own fix';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM ug_cyber.fn_record_verification('UGFIND-DEMO-001','SYN-INDEPENDENT-VERIFIER','pass','SYN-VERIFY-EVIDENCE-001','Synthetic independent verification');
 SELECT COUNT(*) INTO v_count FROM ug_cyber.findings WHERE finding_ref='UGFIND-DEMO-001' AND status='verified';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT passing verification did not mark finding verified'; END IF;
END; $test$;
ROLLBACK;
