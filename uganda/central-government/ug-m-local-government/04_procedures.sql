-- State change and history insert are atomic; fixed-path definer requires trusted ownership.
CREATE OR REPLACE FUNCTION lgmin_demo.fn_transition_programme(p_id BIGINT,p_to TEXT,p_note TEXT,p_actor TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,lgmin_demo AS $$
DECLARE v_from TEXT;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('planned','active','blocked','completed','cancelled')
 THEN RAISE EXCEPTION 'invalid programme status' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL
 THEN RAISE EXCEPTION 'note and actor are required' USING ERRCODE='22023'; END IF;
 SELECT status INTO v_from FROM lgmin_demo.programmes WHERE programme_id=p_id AND is_deleted=FALSE FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'programme not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN p_id; END IF;
 IF NOT((v_from='planned' AND p_to IN('active','cancelled')) OR
 (v_from='active' AND p_to IN('blocked','completed','cancelled')) OR
 (v_from='blocked' AND p_to IN('active','cancelled')))
 THEN RAISE EXCEPTION 'transition not allowed: % -> %',v_from,p_to USING ERRCODE='23514'; END IF;
 UPDATE lgmin_demo.programmes SET status=p_to WHERE programme_id=p_id;
 INSERT INTO lgmin_demo.programme_events(programme_id,previous_status,new_status,note,actor_ref)
 VALUES(p_id,v_from,p_to,btrim(p_note),btrim(p_actor));
 RETURN p_id;
END; $$;
REVOKE ALL ON FUNCTION lgmin_demo.fn_transition_programme(BIGINT,TEXT,TEXT,TEXT) FROM PUBLIC;