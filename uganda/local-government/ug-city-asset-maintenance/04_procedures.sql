CREATE OR REPLACE FUNCTION city_ops_demo.fn_transition_work(p_id BIGINT,p_to TEXT,p_note TEXT,p_actor TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,city_ops_demo AS $$
DECLARE v_from TEXT;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('planned','in_progress','blocked','completed','cancelled') THEN RAISE EXCEPTION 'invalid work state' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor required' USING ERRCODE='22023'; END IF;
 SELECT status INTO v_from FROM city_ops_demo.work_orders WHERE work_order_id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'work order not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN p_id; END IF;
 IF NOT((v_from='planned' AND p_to IN('in_progress','blocked','cancelled')) OR (v_from='in_progress' AND p_to IN('blocked','completed','cancelled')) OR (v_from='blocked' AND p_to IN('in_progress','cancelled'))) THEN RAISE EXCEPTION 'transition not allowed' USING ERRCODE='23514'; END IF;
 UPDATE city_ops_demo.work_orders SET status=p_to,completed_at=CASE WHEN p_to='completed' THEN clock_timestamp() ELSE completed_at END WHERE work_order_id=p_id;
 INSERT INTO city_ops_demo.work_events(work_order_id,previous_status,new_status,note,actor_ref) VALUES(p_id,v_from,p_to,btrim(p_note),btrim(p_actor));
 RETURN p_id;
END; $$;
REVOKE ALL ON FUNCTION city_ops_demo.fn_transition_work(BIGINT,TEXT,TEXT,TEXT) FROM PUBLIC;