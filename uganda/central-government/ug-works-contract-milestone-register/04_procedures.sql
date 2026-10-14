-- Purpose: evidence-backed certificate decisions and payment registration.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_works_contract.fn_review_certificate(
 p_certificate_ref TEXT,p_decision TEXT,p_reviewer_ref TEXT,p_reason TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_works_contract AS $$
DECLARE v_cert ug_works_contract.certificates%ROWTYPE; v_mile ug_works_contract.milestones%ROWTYPE;
 v_contract ug_works_contract.contracts%ROWTYPE; v_budget NUMERIC(16,2); v_total NUMERIC(16,2); v_event BIGINT;
BEGIN
 IF p_decision NOT IN ('approved','rejected') OR length(btrim(COALESCE(p_reviewer_ref,'')))=0
 OR length(btrim(COALESCE(p_reason,'')))=0 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Decision, reviewer, reason and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_cert FROM ug_works_contract.certificates WHERE certificate_ref=p_certificate_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Certificate not found' USING ERRCODE='no_data_found'; END IF;
 IF v_cert.status NOT IN ('submitted','under_review') THEN RAISE EXCEPTION 'Certificate is not reviewable' USING ERRCODE='check_violation'; END IF;
 SELECT * INTO v_mile FROM ug_works_contract.milestones WHERE milestone_id=v_cert.milestone_id FOR UPDATE;
 SELECT * INTO v_contract FROM ug_works_contract.contracts WHERE contract_id=v_mile.contract_id FOR UPDATE;
 SELECT approved_amount INTO v_budget FROM ug_works_contract.budget_versions
 WHERE contract_id=v_contract.contract_id ORDER BY version_no DESC LIMIT 1;
 IF p_decision='approved' THEN
  SELECT COALESCE(SUM(c.submitted_amount),0) INTO v_total
  FROM ug_works_contract.certificates c JOIN ug_works_contract.milestones m USING(milestone_id)
  WHERE m.contract_id=v_contract.contract_id AND c.status IN ('approved','paid') AND c.certificate_id<>v_cert.certificate_id;
  IF v_total+v_cert.submitted_amount>LEAST(v_contract.contract_value,COALESCE(v_budget,0)) THEN
   RAISE EXCEPTION 'Certificate exceeds current approved contract/budget ceiling' USING ERRCODE='check_violation';
  END IF;
 END IF;
 UPDATE ug_works_contract.certificates SET status=p_decision,reviewed_by_ref=p_reviewer_ref,
 reviewed_at=clock_timestamp(),decision_reason=p_reason,evidence_ref=p_evidence_ref
 WHERE certificate_id=v_cert.certificate_id;
 INSERT INTO ug_works_contract.events(entity_type,entity_ref,event_type,actor_ref,reason,evidence_ref)
 VALUES('certificate',p_certificate_ref,p_decision,p_reviewer_ref,p_reason,p_evidence_ref)
 RETURNING event_id INTO v_event;
 RETURN v_event;
END; $$;

CREATE OR REPLACE FUNCTION ug_works_contract.fn_record_certificate_payment(
 p_certificate_ref TEXT,p_payment_ref TEXT,p_actor_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_works_contract AS $$
DECLARE v_cert ug_works_contract.certificates%ROWTYPE; v_event BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_payment_ref,'')))=0 OR length(btrim(COALESCE(p_actor_ref,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Payment reference, actor and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_cert FROM ug_works_contract.certificates WHERE certificate_ref=p_certificate_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Certificate not found' USING ERRCODE='no_data_found'; END IF;
 IF v_cert.status<>'approved' THEN RAISE EXCEPTION 'Only approved certificates may be marked paid' USING ERRCODE='check_violation'; END IF;
 UPDATE ug_works_contract.certificates SET status='paid',paid_at=clock_timestamp(),payment_ref=p_payment_ref
 WHERE certificate_id=v_cert.certificate_id;
 INSERT INTO ug_works_contract.events(entity_type,entity_ref,event_type,actor_ref,reason,evidence_ref)
 VALUES('certificate',p_certificate_ref,'paid',p_actor_ref,'Payment recorded: '||p_payment_ref,p_evidence_ref)
 RETURNING event_id INTO v_event;
 RETURN v_event;
END; $$;
