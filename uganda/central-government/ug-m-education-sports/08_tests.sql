-- PostgreSQL 15+; synthetic tests rolled back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_disp INTEGER;v_recv INTEGER;v_events BIGINT;
BEGIN
 INSERT INTO education_demo.allocations(allocation_ref,school_id,asset_id,planned_quantity,status)
 SELECT 'TEST-AUTOPILOT-EDU',s.school_id,a.asset_id,10,'planned'
 FROM education_demo.schools s CROSS JOIN education_demo.asset_catalog a
 WHERE s.school_code='DEMO-SCH-001' AND a.asset_code='DEMO-BOOK-MATH'
 ON CONFLICT(allocation_ref) DO UPDATE SET planned_quantity=10,dispatched_quantity=0,received_quantity=0,status='planned',is_deleted=FALSE
 RETURNING allocation_id INTO v_id;
 DELETE FROM education_demo.allocation_events WHERE allocation_id=v_id;
 PERFORM education_demo.fn_transition_allocation(v_id,'dispatched','fixture dispatch','test-suite',10,'TEST-DN');
 BEGIN
  PERFORM education_demo.fn_transition_allocation(v_id,'received','excess receipt','test-suite',11,'TEST-EXCESS-GRN');
  RAISE EXCEPTION 'ASSERT excess receipt was accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM education_demo.fn_transition_allocation(v_id,'received','fixture receipt','test-suite',8,'TEST-GRN');
 SELECT status,dispatched_quantity,received_quantity INTO v_status,v_disp,v_recv FROM education_demo.allocations WHERE allocation_id=v_id;
 SELECT COUNT(*) INTO v_events FROM education_demo.allocation_events WHERE allocation_id=v_id;
 IF v_status<>'received' OR v_disp<>10 OR v_recv<>8 OR v_events<>2 THEN RAISE EXCEPTION 'ASSERT allocation receipt invariants failed'; END IF;
 BEGIN
  PERFORM education_demo.fn_transition_allocation(v_id,'planned','invalid reverse','test-suite',NULL,NULL);
  RAISE EXCEPTION 'ASSERT reverse transition accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
END; $test$;
ROLLBACK;