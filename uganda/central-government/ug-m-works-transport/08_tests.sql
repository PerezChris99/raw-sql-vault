-- PostgreSQL 15+; all test mutations roll back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_count BIGINT;
BEGIN
 INSERT INTO works_demo.work_orders(work_order_ref,road_id,summary,status,priority,estimated_cost_ugx)
 SELECT 'TEST-AUTOPILOT-WORKS',road_id,'Temporary workflow test','planned',3,1000
 FROM works_demo.road_assets WHERE road_code='DEMO-RD-001'
 ON CONFLICT(work_order_ref) DO UPDATE SET status='planned',completed_at=NULL,is_deleted=FALSE RETURNING work_order_id INTO v_id;
 DELETE FROM works_demo.work_order_events WHERE work_order_id=v_id;
 PERFORM works_demo.fn_transition_work_order(v_id,'in_progress','valid transition','test-suite');
 PERFORM works_demo.fn_transition_work_order(v_id,'in_progress','idempotent retry','test-suite');
 SELECT status INTO v_status FROM works_demo.work_orders WHERE work_order_id=v_id;
 SELECT COUNT(*) INTO v_count FROM works_demo.work_order_events WHERE work_order_id=v_id;
 IF v_status<>'in_progress' OR v_count<>1 THEN RAISE EXCEPTION 'ASSERT transition/idempotence failed'; END IF;
 BEGIN
  PERFORM works_demo.fn_transition_work_order(v_id,'planned','invalid reverse','test-suite');
  RAISE EXCEPTION 'ASSERT reverse transition accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 SELECT status INTO v_status FROM works_demo.work_orders WHERE work_order_id=v_id;
 IF v_status<>'in_progress' THEN RAISE EXCEPTION 'ASSERT rejected transition mutated row'; END IF;
END; $test$;
ROLLBACK;