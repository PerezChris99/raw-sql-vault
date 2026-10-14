-- Purpose: reviewer-controlled decisions with an append-only event trail.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_market_price.fn_review_observation(
    p_observation_ref TEXT,p_decision TEXT,p_reviewer_ref TEXT,p_reason TEXT,p_evidence_reference TEXT DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,ug_market_price
AS $$
DECLARE v_obs ug_market_price.observations%ROWTYPE; v_event_id BIGINT;
BEGIN
 IF p_decision NOT IN ('accepted','rejected','flagged') THEN
   RAISE EXCEPTION 'Unsupported review decision %',p_decision USING ERRCODE='check_violation';
 END IF;
 IF length(btrim(COALESCE(p_reviewer_ref,'')))=0 OR length(btrim(COALESCE(p_reason,'')))=0 THEN
   RAISE EXCEPTION 'Reviewer and reason are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_obs FROM ug_market_price.observations
 WHERE observation_ref=p_observation_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Observation % not found',p_observation_ref USING ERRCODE='no_data_found'; END IF;
 IF v_obs.status NOT IN ('pending','flagged') THEN
   RAISE EXCEPTION 'Only pending or flagged observations may be reviewed' USING ERRCODE='check_violation';
 END IF;
 IF p_decision IN ('accepted','rejected') AND length(btrim(COALESCE(p_evidence_reference,'')))=0 THEN
   RAISE EXCEPTION 'Accept/reject decisions require an evidence reference' USING ERRCODE='check_violation';
 END IF;
 UPDATE ug_market_price.observations
 SET status=p_decision,
     reviewed_at=CASE WHEN p_decision IN ('accepted','rejected') THEN clock_timestamp() ELSE NULL END,
     reviewed_by=CASE WHEN p_decision IN ('accepted','rejected') THEN p_reviewer_ref ELSE NULL END,
     review_reason=CASE WHEN p_decision IN ('accepted','rejected') THEN p_reason ELSE NULL END
 WHERE observation_id=v_obs.observation_id;
 INSERT INTO ug_market_price.review_events(observation_id,event_type,from_status,to_status,actor_ref,reason,evidence_reference)
 VALUES(v_obs.observation_id,p_decision,v_obs.status,p_decision,p_reviewer_ref,p_reason,p_evidence_reference)
 RETURNING review_event_id INTO v_event_id;
 RETURN v_event_id;
END;
$$;
