-- Purpose: evidence-backed contract variation approval with a non-negative revised contract ceiling.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_procurement.fn_review_variation(
 p_variation_ref TEXT,p_decision TEXT,p_reviewer_ref TEXT,p_review_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_procurement AS $$
DECLARE v ug_procurement.contract_variations%ROWTYPE; a ug_procurement.awards%ROWTYPE; v_total NUMERIC(16,2); ev BIGINT;
BEGIN
 IF p_decision NOT IN ('approved','rejected') OR length(btrim(COALESCE(p_reviewer_ref,'')))=0
 OR length(btrim(COALESCE(p_review_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Decision, reviewer and review evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v FROM ug_procurement.contract_variations WHERE variation_ref=p_variation_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Variation not found' USING ERRCODE='no_data_found'; END IF;
 IF v.status<>'requested' THEN RAISE EXCEPTION 'Variation has already been reviewed' USING ERRCODE='check_violation'; END IF;
 SELECT * INTO a FROM ug_procurement.awards WHERE award_id=v.award_id FOR UPDATE;
 IF p_decision='approved' THEN
  SELECT a.awarded_amount+COALESCE(SUM(cv.value_delta),0) INTO v_total
  FROM ug_procurement.contract_variations cv
  WHERE cv.award_id=a.award_id AND cv.status='approved';
  IF v_total+v.value_delta<=0 THEN RAISE EXCEPTION 'Variation would make revised contract value non-positive' USING ERRCODE='check_violation'; END IF;
 END IF;
 UPDATE ug_procurement.contract_variations SET status=p_decision,reviewed_by_ref=p_reviewer_ref,
 reviewed_at=clock_timestamp(),review_evidence_ref=p_review_evidence_ref WHERE variation_id=v.variation_id;
 INSERT INTO ug_procurement.audit_events(entity_type,entity_ref,event_type,actor_ref,reason,evidence_ref)
 VALUES('variation',p_variation_ref,p_decision,p_reviewer_ref,'Contract variation reviewed',p_review_evidence_ref)
 RETURNING event_id INTO ev;
 RETURN ev;
END; $$;
