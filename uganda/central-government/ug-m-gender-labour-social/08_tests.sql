-- PostgreSQL 15+; all writes roll back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_events BIGINT;
BEGIN
 INSERT INTO social_demo.service_milestones(milestone_ref,enrolment_id,milestone_type,owner_ref,summary,status)
 SELECT 'TEST-AUTOPILOT-SOC',enrolment_id,'follow_up','test-owner','Synthetic state test','open' FROM social_demo.enrolments WHERE enrolment_ref='DEMO-ENR-001'
 ON CONFLICT(milestone_ref) DO UPDATE SET status='open',completed_at=NULL RETURNING milestone_id INTO v_id;
 DELETE FROM social_demo.milestone_events WHERE milestone_id=v_id;
 PERFORM social_demo.fn_transition_milestone(v_id,'in_progress','valid transition','test-suite');
 PERFORM social_demo.fn_transition_milestone(v_id,'in_progress','idempotent retry','test-suite');
 SELECT status INTO v_status FROM social_demo.service_milestones WHERE milestone_id=v_id;
 SELECT COUNT(*) INTO v_events FROM social_demo.milestone_events WHERE milestone_id=v_id;
 IF v_status<>'in_progress' OR v_events<>1 THEN RAISE EXCEPTION 'ASSERT social milestone transition/idempotency failed'; END IF;
 BEGIN PERFORM social_demo.fn_transition_milestone(v_id,'open','invalid reverse','test-suite'); RAISE EXCEPTION 'ASSERT reverse transition accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;