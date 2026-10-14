-- PostgreSQL 15+; synthetic state machine assertions roll back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_count BIGINT;
BEGIN
 INSERT INTO energy_demo.corrective_actions(action_ref,inspection_id,summary,status,owner_ref)
 SELECT 'TEST-AUTOPILOT-ENERGY',inspection_id,'Synthetic test action','open','test-owner'
 FROM energy_demo.inspections WHERE inspection_ref='DEMO-INSP-001'
 ON CONFLICT(action_ref) DO UPDATE SET status='open',closed_at=NULL
 RETURNING action_id INTO v_id;
 DELETE FROM energy_demo.action_events WHERE action_id=v_id;
 PERFORM energy_demo.fn_transition_action(v_id,'in_progress','valid transition','test-suite');
 PERFORM energy_demo.fn_transition_action(v_id,'in_progress','idempotent retry','test-suite');
 SELECT status INTO v_status FROM energy_demo.corrective_actions WHERE action_id=v_id;
 SELECT COUNT(*) INTO v_count FROM energy_demo.action_events WHERE action_id=v_id;
 IF v_status<>'in_progress' OR v_count<>1 THEN RAISE EXCEPTION 'ASSERT energy corrective transition/idempotency failed'; END IF;
 BEGIN PERFORM energy_demo.fn_transition_action(v_id,'open','invalid reverse','test-suite'); RAISE EXCEPTION 'ASSERT invalid reverse accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;