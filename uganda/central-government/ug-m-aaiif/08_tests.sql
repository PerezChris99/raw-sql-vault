-- PostgreSQL 15+; rollback all test mutations.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_status TEXT;v_d NUMERIC;v_r NUMERIC;v_events BIGINT;
BEGIN
 INSERT INTO agriculture_demo.input_deliveries(delivery_ref,farm_id,input_type,input_label,planned_qty,unit_code,status)
 SELECT 'TEST-AUTOPILOT-AGRI',farm_id,'seed','Synthetic assertion fixture',10,'kg','planned' FROM agriculture_demo.farm_refs WHERE farm_token='FARM-DEMO-001'
 ON CONFLICT(delivery_ref) DO UPDATE SET planned_qty=10,dispatched_qty=0,received_qty=0,status='planned'
 RETURNING delivery_id INTO v_id;
 DELETE FROM agriculture_demo.delivery_events WHERE delivery_id=v_id;
 PERFORM agriculture_demo.fn_transition_delivery(v_id,'dispatched','dispatch test','test-suite',10,'TEST-DN');
 BEGIN PERFORM agriculture_demo.fn_transition_delivery(v_id,'received','excess receipt','test-suite',11,'TEST-GRN'); RAISE EXCEPTION 'ASSERT over-receipt accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM agriculture_demo.fn_transition_delivery(v_id,'received','partial receipt','test-suite',8,'TEST-GRN');
 SELECT status,dispatched_qty,received_qty INTO v_status,v_d,v_r FROM agriculture_demo.input_deliveries WHERE delivery_id=v_id;
 SELECT COUNT(*) INTO v_events FROM agriculture_demo.delivery_events WHERE delivery_id=v_id;
 IF v_status<>'received' OR v_d<>10 OR v_r<>8 OR v_events<>2 THEN RAISE EXCEPTION 'ASSERT delivery state/history failed'; END IF;
END; $test$;
ROLLBACK;