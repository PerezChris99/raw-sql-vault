CREATE OR REPLACE FUNCTION energy_demo.fn_transition_action(p_id BIGINT,p_to TEXT,p_note TEXT,p_actor TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,energy_demo AS $$
DECLARE v_from TEXT;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('open','in_progress','blocked','closed','cancelled') THEN RAISE EXCEPTION 'invalid action state' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor required' USING ERRCODE='22023'; END IF;
 SELECT status INTO v_from FROM energy_demo.corrective_actions WHERE action_id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'corrective action not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN p_id; END IF;
 IF NOT((v_from='open' AND p_to IN('in_progress','blocked','cancelled')) OR
 (v_from='in_progress' AND p_to IN('blocked','closed','cancelled')) OR
 (v_from='blocked' AND p_to IN('in_progress','cancelled'))) THEN
 RAISE EXCEPTION 'transition not allowed: % -> %',v_from,p_to USING ERRCODE='23514'; END IF;
 UPDATE energy_demo.corrective_actions SET status=p_to,closed_at=CASE WHEN p_to='closed' THEN clock_timestamp() ELSE closed_at END WHERE action_id=p_id;
 INSERT INTO energy_demo.action_events(action_id,previous_status,new_status,event_note,actor_ref) VALUES(p_id,v_from,p_to,btrim(p_note),btrim(p_actor));
 RETURN p_id;
END; $$;
REVOKE ALL ON FUNCTION energy_demo.fn_transition_action(BIGINT,TEXT,TEXT,TEXT) FROM PUBLIC;
