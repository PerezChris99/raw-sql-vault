CREATE OR REPLACE FUNCTION public_service_demo.fn_transition_enrolment(p_id BIGINT,p_to TEXT,p_note TEXT,p_actor TEXT,p_score NUMERIC DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,public_service_demo AS $$
DECLARE v_from TEXT;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('enrolled','attended','completed','withdrawn') THEN RAISE EXCEPTION 'invalid enrolment status' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor required' USING ERRCODE='22023'; END IF;
 IF p_to='completed' AND (p_score IS NULL OR p_score<0 OR p_score>100) THEN RAISE EXCEPTION 'completed enrolment needs score 0..100' USING ERRCODE='22023'; END IF;
 SELECT status INTO v_from FROM public_service_demo.enrolments WHERE enrolment_id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'enrolment not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN p_id; END IF;
 IF NOT((v_from='enrolled' AND p_to IN('attended','withdrawn')) OR (v_from='attended' AND p_to IN('completed','withdrawn'))) THEN
 RAISE EXCEPTION 'transition not allowed: % -> %',v_from,p_to USING ERRCODE='23514'; END IF;
 UPDATE public_service_demo.enrolments SET status=p_to,score=CASE WHEN p_to='completed' THEN p_score ELSE score END WHERE enrolment_id=p_id;
 INSERT INTO public_service_demo.enrolment_events(enrolment_id,previous_status,new_status,event_note,actor_ref)
 VALUES(p_id,v_from,p_to,btrim(p_note),btrim(p_actor));
 RETURN p_id;
END; $$;
REVOKE ALL ON FUNCTION public_service_demo.fn_transition_enrolment(BIGINT,TEXT,TEXT,TEXT,NUMERIC) FROM PUBLIC;