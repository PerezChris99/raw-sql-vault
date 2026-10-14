-- PostgreSQL 15+; all test mutations are rolled back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_events BIGINT;
BEGIN
 INSERT INTO city_ops_demo.work_orders(work_ref,asset_id,work_type,summary,priority,estimated_cost_ugx,status)
 SELECT 'TEST-CITY-WORK',asset_id,'repair','Synthetic test work',3,1000,'planned' FROM city_ops_demo.assets WHERE asset_ref='DEMO-CITY-ASSET-001'
 ON CONFLICT(work_ref) DO UPDATE SET status='planned',completed_at=NULL RETURNING work_order_id INTO v_id;
 DELETE FROM city_ops_demo.work_events WHERE work_order_id=v_id;
 PERFORM city_ops_demo.fn_transition_work(v_id,'in_progress','valid transition','test-suite');
 PERFORM city_ops_demo.fn_transition_work(v_id,'in_progress','same-state retry','test-suite');
 SELECT status INTO v_status FROM city_ops_demo.work_orders WHERE work_order_id=v_id;
 SELECT COUNT(*) INTO v_events FROM city_ops_demo.work_events WHERE work_order_id=v_id;
 IF v_status<>'in_progress' OR v_events<>1 THEN RAISE EXCEPTION 'ASSERT city work transition/idempotency failed'; END IF;
 BEGIN PERFORM city_ops_demo.fn_transition_work(v_id,'planned','invalid reverse','test-suite'); RAISE EXCEPTION 'ASSERT reverse accepted'; EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;