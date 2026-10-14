CREATE OR REPLACE FUNCTION water_demo.fn_transition_job(p_id BIGINT,p_to TEXT,p_note TEXT,p_actor TEXT,p_actual_ugx NUMERIC DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,water_demo AS $$
DECLARE v_from TEXT;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('planned','in_progress','blocked','completed','cancelled') THEN RAISE EXCEPTION 'invalid maintenance status' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor are required' USING ERRCODE='22023'; END IF;
 IF p_actual_ugx IS NOT NULL AND p_actual_ugx<0 THEN RAISE EXCEPTION 'actual cost must be non-negative' USING ERRCODE='22023'; END IF;
 SELECT status INTO v_from FROM water_demo.maintenance_jobs WHERE job_id=p_id AND is_deleted=FALSE FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'maintenance job not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN p_id; END IF;
 IF NOT((v_from='planned' AND p_to IN('in_progress','blocked','cancelled')) OR
 (v_from='in_progress' AND p_to IN('blocked','completed','cancelled')) OR
 (v_from='blocked' AND p_to IN('in_progress','cancelled'))) THEN
 RAISE EXCEPTION 'transition not allowed: % -> %',v_from,p_to USING ERRCODE='23514'; END IF;
 UPDATE water_demo.maintenance_jobs SET status=p_to,
 completed_at=CASE WHEN p_to='completed' THEN clock_timestamp() ELSE completed_at END,
 actual_ugx=COALESCE(p_actual_ugx,actual_ugx) WHERE job_id=p_id;
 INSERT INTO water_demo.maintenance_events(job_id,previous_status,new_status,event_note,actor_ref)
 VALUES(p_id,v_from,p_to,btrim(p_note),btrim(p_actor));
 RETURN p_id;
END; $$;
REVOKE ALL ON FUNCTION water_demo.fn_transition_job(BIGINT,TEXT,TEXT,TEXT,NUMERIC) FROM PUBLIC;