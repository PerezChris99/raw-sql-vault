-- PostgreSQL 15+; transaction is rolled back after assertions.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_count BIGINT;
BEGIN
 INSERT INTO diplomacy_demo.commitments(commitment_ref,engagement_id,action_summary,owner_ref,status)
 SELECT 'TEST-AUTOPILOT-DIPLOMACY',engagement_id,'Synthetic workflow assertion','test-owner','open' FROM diplomacy_demo.engagements WHERE engagement_ref='DEMO-ENG-001'
 ON CONFLICT(commitment_ref) DO UPDATE SET status='open',completed_at=NULL RETURNING commitment_id INTO v_id;
 DELETE FROM diplomacy_demo.commitment_events WHERE commitment_id=v_id;
 PERFORM diplomacy_demo.fn_transition_commitment(v_id,'in_progress','valid state change','test-suite');
 PERFORM diplomacy_demo.fn_transition_commitment(v_id,'in_progress','same-state retry','test-suite');
 SELECT status INTO v_status FROM diplomacy_demo.commitments WHERE commitment_id=v_id;
 SELECT COUNT(*) INTO v_count FROM diplomacy_demo.commitment_events WHERE commitment_id=v_id;
 IF v_status<>'in_progress' OR v_count<>1 THEN RAISE EXCEPTION 'ASSERT commitment transition/idempotency failed'; END IF;
 BEGIN PERFORM diplomacy_demo.fn_transition_commitment(v_id,'open','invalid reverse','test-suite'); RAISE EXCEPTION 'ASSERT reverse accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;