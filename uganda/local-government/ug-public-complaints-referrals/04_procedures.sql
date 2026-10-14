-- Purpose: validated case state changes and referral creation.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_public_case.fn_transition_case(
 p_case_ref TEXT,p_target_status TEXT,p_actor_ref TEXT,p_reason TEXT,p_evidence_reference TEXT DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_public_case
AS $$
DECLARE v_case ug_public_case.cases%ROWTYPE; v_event_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_reason,'')))=0 THEN
  RAISE EXCEPTION 'Actor and reason are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_case FROM ug_public_case.cases WHERE case_ref=p_case_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Case % not found',p_case_ref USING ERRCODE='no_data_found'; END IF;
 IF NOT (
  (v_case.status='received' AND p_target_status IN ('triaged','withdrawn')) OR
  (v_case.status='triaged' AND p_target_status IN ('assigned','referred','withdrawn')) OR
  (v_case.status='assigned' AND p_target_status IN ('referred','awaiting_response','resolved','withdrawn')) OR
  (v_case.status='referred' AND p_target_status IN ('awaiting_response','resolved','withdrawn')) OR
  (v_case.status='awaiting_response' AND p_target_status IN ('assigned','resolved','withdrawn')) OR
  (v_case.status='resolved' AND p_target_status='closed')
 ) THEN RAISE EXCEPTION 'Invalid case transition % -> %',v_case.status,p_target_status USING ERRCODE='check_violation'; END IF;
 IF p_target_status IN ('resolved','closed','withdrawn') AND length(btrim(COALESCE(p_evidence_reference,'')))=0 THEN
  RAISE EXCEPTION 'Resolution, closure or withdrawal requires evidence reference' USING ERRCODE='check_violation';
 END IF;
 UPDATE ug_public_case.cases SET status=p_target_status,
   closed_at=CASE WHEN p_target_status IN ('closed','withdrawn') THEN clock_timestamp() ELSE NULL END,
   closure_reason=CASE WHEN p_target_status IN ('closed','withdrawn') THEN p_reason ELSE NULL END
 WHERE case_id=v_case.case_id;
 INSERT INTO ug_public_case.case_events(case_id,event_type,from_status,to_status,actor_ref,reason,evidence_reference)
 VALUES(v_case.case_id,CASE p_target_status WHEN 'triaged' THEN 'triaged' WHEN 'assigned' THEN 'assigned'
  WHEN 'referred' THEN 'referred' WHEN 'awaiting_response' THEN 'awaiting_response' WHEN 'resolved' THEN 'resolved'
  WHEN 'closed' THEN 'closed' WHEN 'withdrawn' THEN 'withdrawn' END,
  v_case.status,p_target_status,p_actor_ref,p_reason,p_evidence_reference)
 RETURNING event_id INTO v_event_id;
 RETURN v_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION ug_public_case.fn_create_referral(
 p_referral_ref TEXT,p_case_ref TEXT,p_receiving_office_ref TEXT,p_reason TEXT,
 p_source_evidence_ref TEXT,p_due_at TIMESTAMPTZ,p_recorded_by TEXT
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_public_case
AS $$
DECLARE v_case ug_public_case.cases%ROWTYPE; v_referral_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_receiving_office_ref,'')))=0 OR length(btrim(COALESCE(p_reason,'')))=0
    OR length(btrim(COALESCE(p_source_evidence_ref,'')))=0 OR length(btrim(COALESCE(p_recorded_by,'')))=0 OR p_due_at IS NULL THEN
  RAISE EXCEPTION 'Referral office, reason, source, due date and actor are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_case FROM ug_public_case.cases WHERE case_ref=p_case_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Case % not found',p_case_ref USING ERRCODE='no_data_found'; END IF;
 IF v_case.status NOT IN ('triaged','assigned') THEN RAISE EXCEPTION 'Case must be triaged or assigned before referral' USING ERRCODE='check_violation'; END IF;
 INSERT INTO ug_public_case.referrals(referral_ref,case_id,receiving_office_ref,referral_reason,source_evidence_ref,due_at,recorded_by)
 VALUES(p_referral_ref,v_case.case_id,p_receiving_office_ref,p_reason,p_source_evidence_ref,p_due_at,p_recorded_by)
 RETURNING referral_id INTO v_referral_id;
 UPDATE ug_public_case.cases SET status='referred' WHERE case_id=v_case.case_id;
 INSERT INTO ug_public_case.case_events(case_id,event_type,from_status,to_status,actor_ref,reason,evidence_reference)
 VALUES(v_case.case_id,'referred',v_case.status,'referred',p_recorded_by,p_reason,p_source_evidence_ref);
 RETURN v_referral_id;
END;
$$;
