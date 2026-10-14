CREATE OR REPLACE FUNCTION agriculture_demo.fn_transition_delivery(p_id BIGINT,p_to TEXT,p_note TEXT,p_actor TEXT,p_qty NUMERIC DEFAULT NULL,p_doc TEXT DEFAULT NULL) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,agriculture_demo AS $$
DECLARE v_from TEXT;v_planned NUMERIC;v_dispatched NUMERIC;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('planned','dispatched','received','disputed','cancelled') THEN RAISE EXCEPTION 'invalid delivery status' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor required' USING ERRCODE='22023'; END IF;
 SELECT status,planned_qty,dispatched_qty INTO v_from,v_planned,v_dispatched FROM agriculture_demo.input_deliveries WHERE delivery_id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'delivery not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN p_id; END IF;
 IF NOT((v_from='planned' AND p_to IN('dispatched','cancelled')) OR(v_from='dispatched' AND p_to IN('received','disputed')) OR(v_from='disputed' AND p_to IN('received','cancelled'))) THEN RAISE EXCEPTION 'transition not allowed' USING ERRCODE='23514'; END IF;
 IF p_to='dispatched' AND(p_qty IS NULL OR p_qty<=0 OR p_qty>v_planned) THEN RAISE EXCEPTION 'dispatch quantity out of range' USING ERRCODE='22023'; END IF;
 IF p_to='received' AND(p_qty IS NULL OR p_qty<=0 OR p_qty>v_dispatched) THEN RAISE EXCEPTION 'receipt quantity out of range' USING ERRCODE='22023'; END IF;
 UPDATE agriculture_demo.input_deliveries SET status=p_to,dispatched_qty=CASE WHEN p_to='dispatched' THEN p_qty ELSE dispatched_qty END,received_qty=CASE WHEN p_to='received' THEN p_qty ELSE received_qty END,dispatch_ref=CASE WHEN p_to='dispatched' THEN p_doc ELSE dispatch_ref END,receipt_ref=CASE WHEN p_to='received' THEN p_doc ELSE receipt_ref END WHERE delivery_id=p_id;
 INSERT INTO agriculture_demo.delivery_events(delivery_id,previous_status,new_status,event_note,actor_ref) VALUES(p_id,v_from,p_to,btrim(p_note),btrim(p_actor));
 RETURN p_id;
END; $$;
REVOKE ALL ON FUNCTION agriculture_demo.fn_transition_delivery(BIGINT,TEXT,TEXT,TEXT,NUMERIC,TEXT) FROM PUBLIC;