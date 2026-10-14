CREATE OR REPLACE FUNCTION ubos_demo.fn_transition_wave(p_id BIGINT,p_to TEXT,p_note TEXT,p_actor TEXT)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ubos_demo AS $$
DECLARE v_from TEXT;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('planned','fieldwork','processing','quality_review','complete','cancelled') THEN RAISE EXCEPTION 'invalid wave state' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor required' USING ERRCODE='22023'; END IF;
 SELECT status INTO v_from FROM ubos_demo.survey_waves WHERE wave_id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'wave not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN p_id; END IF;
 IF NOT((v_from='planned' AND p_to IN('fieldwork','cancelled')) OR (v_from='fieldwork' AND p_to IN('processing','cancelled')) OR (v_from='processing' AND p_to IN('quality_review','cancelled')) OR (v_from='quality_review' AND p_to IN('complete','processing','cancelled'))) THEN RAISE EXCEPTION 'wave transition not allowed' USING ERRCODE='23514'; END IF;
 UPDATE ubos_demo.survey_waves SET status=p_to WHERE wave_id=p_id;
 INSERT INTO ubos_demo.release_events(wave_id,previous_status,new_status,note,actor_ref) VALUES(p_id,v_from,p_to,btrim(p_note),btrim(p_actor));
 RETURN p_id;
END; $$;
REVOKE ALL ON FUNCTION ubos_demo.fn_transition_wave(BIGINT,TEXT,TEXT,TEXT) FROM PUBLIC;