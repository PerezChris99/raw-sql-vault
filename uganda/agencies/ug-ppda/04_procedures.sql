CREATE OR REPLACE FUNCTION ppda_demo.fn_transition_milestone(p_id BIGINT,p_to TEXT,p_note TEXT,p_actor TEXT,p_evidence_ref TEXT DEFAULT NULL)
RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ppda_demo AS $$
DECLARE v_from TEXT;
BEGIN
 IF p_to IS NULL OR p_to NOT IN('planned','submitted','verified','disputed','waived') THEN RAISE EXCEPTION 'invalid milestone status' USING ERRCODE='23514'; END IF;
 IF NULLIF(btrim(p_note),'') IS NULL OR NULLIF(btrim(p_actor),'') IS NULL THEN RAISE EXCEPTION 'note and actor required' USING ERRCODE='22023'; END IF;
 IF p_to='verified' AND NULLIF(btrim(p_evidence_ref),'') IS NULL THEN RAISE EXCEPTION 'verification requires evidence reference' USING ERRCODE='22023'; END IF;
 SELECT status INTO v_from FROM ppda_demo.contract_milestones WHERE milestone_id=p_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'milestone not found' USING ERRCODE='P0002'; END IF;
 IF v_from=p_to THEN RETURN p_id; END IF;
 IF NOT((v_from='planned' AND p_to IN('submitted','waived')) OR
 (v_from='submitted' AND p_to IN('verified','disputed')) OR
 (v_from='disputed' AND p_to IN('submitted','waived'))) THEN
 RAISE EXCEPTION 'transition not allowed: % -> %',v_from,p_to USING ERRCODE='23514'; END IF;
 UPDATE ppda_demo.contract_milestones SET status=p_to,
 evidence_ref=CASE WHEN p_evidence_ref IS NOT NULL THEN btrim(p_evidence_ref) ELSE evidence_ref END,
 verified_by_ref=CASE WHEN p_to='verified' THEN btrim(p_actor) ELSE verified_by_ref END,
 verified_at=CASE WHEN p_to='verified' THEN clock_timestamp() ELSE verified_at END
 WHERE milestone_id=p_id;
 INSERT INTO ppda_demo.milestone_events(milestone_id,previous_status,new_status,note,actor_ref,evidence_ref)
 VALUES(p_id,v_from,p_to,btrim(p_note),btrim(p_actor),p_evidence_ref);
 RETURN p_id;
END; $$;
REVOKE ALL ON FUNCTION ppda_demo.fn_transition_milestone(BIGINT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;