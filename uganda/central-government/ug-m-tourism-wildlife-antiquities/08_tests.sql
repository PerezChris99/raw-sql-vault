-- PostgreSQL 15+; rolled-back workflow assertions.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_events BIGINT;
BEGIN
 INSERT INTO tourism_demo.actions(action_ref,inspection_id,summary,owner_ref,status)
 SELECT 'TEST-AUTOPILOT-TOURISM',inspection_id,'Synthetic test action','test-owner','open' FROM tourism_demo.inspections WHERE inspection_ref='DEMO-INSP-001'
 ON CONFLICT(action_ref) DO UPDATE SET status='open',closed_at=NULL RETURNING action_id INTO v_id;
 DELETE FROM tourism_demo.action_events WHERE action_id=v_id;
 PERFORM tourism_demo.fn_transition_action(v_id,'in_progress','valid transition','test-suite');
 PERFORM tourism_demo.fn_transition_action(v_id,'in_progress','same-state retry','test-suite');
 SELECT status INTO v_status FROM tourism_demo.actions WHERE action_id=v_id;
 SELECT COUNT(*) INTO v_events FROM tourism_demo.action_events WHERE action_id=v_id;
 IF v_status<>'in_progress' OR v_events<>1 THEN RAISE EXCEPTION 'ASSERT tourism action transition/idempotency failed'; END IF;
 BEGIN PERFORM tourism_demo.fn_transition_action(v_id,'open','invalid reverse','test-suite'); RAISE EXCEPTION 'ASSERT reverse accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;