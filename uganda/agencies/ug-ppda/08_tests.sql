-- PostgreSQL 15+; test data changes roll back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_count BIGINT;v_verified TIMESTAMPTZ;
BEGIN
 INSERT INTO ppda_demo.contract_milestones(milestone_ref,contract_id,milestone_title,due_date,planned_value_ugx,status)
 SELECT 'TEST-AUTOPILOT-PPDA',contract_id,'Temporary verification test',CURRENT_DATE+10,1000,'planned'
 FROM ppda_demo.contracts WHERE contract_ref='DEMO-CONTRACT-001'
 ON CONFLICT(milestone_ref) DO UPDATE SET status='planned',evidence_ref=NULL,verified_by_ref=NULL,verified_at=NULL
 RETURNING milestone_id INTO v_id;
 DELETE FROM ppda_demo.milestone_events WHERE milestone_id=v_id;
 PERFORM ppda_demo.fn_transition_milestone(v_id,'submitted','documents submitted','test-suite',NULL);
 BEGIN
  PERFORM ppda_demo.fn_transition_milestone(v_id,'verified','missing evidence','test-suite',NULL);
  RAISE EXCEPTION 'ASSERT verification without evidence accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM ppda_demo.fn_transition_milestone(v_id,'verified','evidence accepted','test-suite','TEST-EVIDENCE-001');
 SELECT status,verified_at INTO v_status,v_verified FROM ppda_demo.contract_milestones WHERE milestone_id=v_id;
 SELECT COUNT(*) INTO v_count FROM ppda_demo.milestone_events WHERE milestone_id=v_id;
 IF v_status<>'verified' OR v_verified IS NULL OR v_count<>2 THEN RAISE EXCEPTION 'ASSERT verified milestone invariants failed'; END IF;
 BEGIN
  PERFORM ppda_demo.fn_transition_milestone(v_id,'planned','invalid reversal','test-suite',NULL);
  RAISE EXCEPTION 'ASSERT reverse transition accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;