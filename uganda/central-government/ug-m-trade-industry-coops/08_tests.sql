-- PostgreSQL 15+; changes roll back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_count BIGINT;
BEGIN
 INSERT INTO trade_demo.milestones(milestone_ref,application_id,milestone_type,owner_ref,summary,status)
 SELECT 'TEST-AUTOPILOT-TRADE',application_id,'other','test-owner','Synthetic test milestone','open' FROM trade_demo.applications WHERE application_ref='DEMO-APP-001'
 ON CONFLICT(milestone_ref) DO UPDATE SET status='open',completed_at=NULL RETURNING milestone_id INTO v_id;
 DELETE FROM trade_demo.milestone_events WHERE milestone_id=v_id;
 PERFORM trade_demo.fn_transition_milestone(v_id,'in_progress','valid transition','test-suite');
 PERFORM trade_demo.fn_transition_milestone(v_id,'in_progress','same-state retry','test-suite');
 SELECT status INTO v_status FROM trade_demo.milestones WHERE milestone_id=v_id;
 SELECT COUNT(*) INTO v_count FROM trade_demo.milestone_events WHERE milestone_id=v_id;
 IF v_status<>'in_progress' OR v_count<>1 THEN RAISE EXCEPTION 'ASSERT trade milestone transition/idempotency failed'; END IF;
 BEGIN PERFORM trade_demo.fn_transition_milestone(v_id,'open','invalid reverse','test-suite'); RAISE EXCEPTION 'ASSERT reverse accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;