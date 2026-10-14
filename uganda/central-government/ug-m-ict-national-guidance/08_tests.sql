-- PostgreSQL 15+; all changes roll back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_events BIGINT;
BEGIN
 SELECT item_id INTO v_id FROM ict_demo.work_items WHERE item_ref='DEMO-WORK-001' FOR UPDATE;
 DELETE FROM ict_demo.work_events WHERE item_id=v_id;
 PERFORM ict_demo.fn_transition_work(v_id,'blocked','test transition','test-suite');
 PERFORM ict_demo.fn_transition_work(v_id,'blocked','same-state retry','test-suite');
 SELECT status INTO v_status FROM ict_demo.work_items WHERE item_id=v_id;
 SELECT COUNT(*) INTO v_events FROM ict_demo.work_events WHERE item_id=v_id;
 IF v_status<>'blocked' OR v_events<>1 THEN RAISE EXCEPTION 'ASSERT ICT transition/idempotency failed'; END IF;
 BEGIN PERFORM ict_demo.fn_transition_work(v_id,'open','invalid reverse','test-suite'); RAISE EXCEPTION 'ASSERT reverse accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;