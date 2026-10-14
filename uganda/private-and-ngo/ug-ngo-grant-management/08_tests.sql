-- PostgreSQL 15+; test-only writes are rolled back.
BEGIN;
DO $test$
DECLARE v_a BIGINT; v_b BIGINT; v_count BIGINT; v_spent NUMERIC; v_id BIGINT;
BEGIN
 v_a := ngo_demo.fn_record_expenditure('TEST-NGO-EXP-1','DEMO-GRANT-A',CURRENT_DATE,10000,'UGX','supplies','TEST-NGO-SOURCE-1','TEST-NGO-IDEM-1');
 v_b := ngo_demo.fn_record_expenditure('TEST-NGO-EXP-1','DEMO-GRANT-A',CURRENT_DATE,10000,'UGX','supplies','TEST-NGO-SOURCE-1','TEST-NGO-IDEM-1');
 IF v_a <> v_b THEN RAISE EXCEPTION 'ASSERT expenditure idempotency failed'; END IF;
 SELECT COUNT(*),SUM(amount) INTO v_count,v_spent FROM ngo_demo.expenditures WHERE idempotency_key='TEST-NGO-IDEM-1';
 IF v_count <> 1 OR v_spent <> 10000 THEN RAISE EXCEPTION 'ASSERT expense retry double-counted'; END IF;
 BEGIN
  PERFORM ngo_demo.fn_record_expenditure('TEST-NGO-OVER','DEMO-GRANT-A',CURRENT_DATE,999999999,'UGX','supplies','TEST-NGO-SOURCE-OVER','TEST-NGO-IDEM-OVER');
  RAISE EXCEPTION 'ASSERT grant ceiling exceeded';
 EXCEPTION WHEN check_violation THEN NULL; END;
 INSERT INTO ngo_demo.milestones(milestone_ref,project_id,milestone_title,due_date,status)
 SELECT 'TEST-NGO-MILESTONE',project_id,'Temporary evidence assertion',CURRENT_DATE+2,'planned'
 FROM ngo_demo.projects WHERE project_code='DEMO-PROJ-A'
 ON CONFLICT(milestone_ref) DO UPDATE SET status='planned',evidence_ref=NULL,verified_by_ref=NULL,verified_at=NULL
 RETURNING milestone_id INTO v_id;
 DELETE FROM ngo_demo.milestone_events WHERE milestone_id=v_id;
 BEGIN
  PERFORM ngo_demo.fn_transition_milestone('TEST-NGO-MILESTONE','verified','missing evidence','test-suite',NULL);
  RAISE EXCEPTION 'ASSERT verification without evidence accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM ngo_demo.fn_transition_milestone('TEST-NGO-MILESTONE','submitted','submitted for review','test-suite',NULL);
 PERFORM ngo_demo.fn_transition_milestone('TEST-NGO-MILESTONE','verified','verified with evidence','test-suite','TEST-EVIDENCE');
 IF NOT EXISTS(SELECT 1 FROM ngo_demo.milestones WHERE milestone_id=v_id AND status='verified' AND verified_at IS NOT NULL) THEN
  RAISE EXCEPTION 'ASSERT verified milestone evidence missing';
 END IF;
END;
$test$;
ROLLBACK;