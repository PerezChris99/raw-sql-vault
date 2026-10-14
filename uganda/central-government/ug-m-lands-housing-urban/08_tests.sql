-- PostgreSQL 15+; rollback test mutations.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_events BIGINT;
BEGIN
 SELECT action_id INTO v_id FROM urban_demo.actions WHERE action_ref='DEMO-URB-ACT-001' FOR UPDATE;
 DELETE FROM urban_demo.action_events WHERE action_id=v_id;
 PERFORM urban_demo.fn_transition_action(v_id,'in_progress','valid transition','test-suite');
 PERFORM urban_demo.fn_transition_action(v_id,'in_progress','same state retry','test-suite');
 SELECT status INTO v_status FROM urban_demo.actions WHERE action_id=v_id;
 SELECT COUNT(*) INTO v_events FROM urban_demo.action_events WHERE action_id=v_id;
 IF v_status<>'in_progress' OR v_events<>1 THEN RAISE EXCEPTION 'ASSERT urban action transition failed'; END IF;
 BEGIN PERFORM urban_demo.fn_transition_action(v_id,'open','invalid reverse','test-suite'); RAISE EXCEPTION 'ASSERT reverse transition accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;