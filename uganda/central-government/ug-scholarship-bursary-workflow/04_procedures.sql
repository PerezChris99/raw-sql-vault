-- Purpose: evidence-backed application transitions, appeal review and idempotent disbursement.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_bursary.fn_transition_application(
 p_application_ref TEXT,p_target_status TEXT,p_actor_ref TEXT,p_reason TEXT,p_evidence_reference TEXT DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_bursary
AS $$
DECLARE v_app ug_bursary.applications%ROWTYPE; v_programme ug_bursary.programmes%ROWTYPE; v_event_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_reason,'')))=0 THEN
  RAISE EXCEPTION 'Actor and reason are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_app FROM ug_bursary.applications WHERE application_ref=p_application_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Application % not found',p_application_ref USING ERRCODE='no_data_found'; END IF;
 IF NOT (
  (v_app.status='draft' AND p_target_status IN ('submitted','withdrawn')) OR
  (v_app.status='submitted' AND p_target_status IN ('under_review','awaiting_documents','withdrawn')) OR
  (v_app.status='under_review' AND p_target_status IN ('awaiting_documents','approved','rejected','withdrawn')) OR
  (v_app.status='awaiting_documents' AND p_target_status IN ('under_review','withdrawn'))
 ) THEN RAISE EXCEPTION 'Invalid application transition % -> %',v_app.status,p_target_status USING ERRCODE='check_violation'; END IF;
 IF p_target_status='submitted' THEN
  SELECT * INTO v_programme FROM ug_bursary.programmes WHERE programme_id=v_app.programme_id;
  IF v_programme.programme_status<>'open' OR CURRENT_DATE NOT BETWEEN v_programme.opens_on AND v_programme.closes_on THEN
   RAISE EXCEPTION 'Programme is not open for submissions today' USING ERRCODE='check_violation';
  END IF;
 END IF;
 IF p_target_status IN ('approved','rejected') AND length(btrim(COALESCE(p_evidence_reference,'')))=0 THEN
  RAISE EXCEPTION 'Decision evidence reference is required' USING ERRCODE='check_violation';
 END IF;
 UPDATE ug_bursary.applications SET status=p_target_status,
   submitted_at=CASE WHEN p_target_status='submitted' THEN COALESCE(submitted_at,clock_timestamp()) ELSE submitted_at END,
   decision_at=CASE WHEN p_target_status IN ('approved','rejected') THEN clock_timestamp() ELSE NULL END,
   decision_evidence_ref=CASE WHEN p_target_status IN ('approved','rejected') THEN p_evidence_reference ELSE NULL END,
   decision_reason=CASE WHEN p_target_status IN ('approved','rejected') THEN p_reason ELSE NULL END,
   updated_at=clock_timestamp()
 WHERE application_id=v_app.application_id;
 INSERT INTO ug_bursary.application_events(application_id,event_type,from_status,to_status,actor_ref,reason,evidence_reference)
 VALUES(v_app.application_id,CASE p_target_status WHEN 'submitted' THEN 'submitted' WHEN 'under_review' THEN 'assigned_for_review'
   WHEN 'awaiting_documents' THEN 'requested_documents' WHEN 'approved' THEN 'approved' WHEN 'rejected' THEN 'rejected'
   WHEN 'withdrawn' THEN 'withdrawn' END,v_app.status,p_target_status,p_actor_ref,p_reason,p_evidence_reference)
 RETURNING event_id INTO v_event_id;
 RETURN v_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION ug_bursary.fn_file_appeal(
 p_appeal_ref TEXT,p_application_ref TEXT,p_filed_by_ref TEXT,p_reason TEXT,p_evidence_reference TEXT
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_bursary
AS $$
DECLARE v_app ug_bursary.applications%ROWTYPE; v_appeal_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_filed_by_ref,'')))=0 OR length(btrim(COALESCE(p_reason,'')))=0
    OR length(btrim(COALESCE(p_evidence_reference,'')))=0 THEN
  RAISE EXCEPTION 'Appeal filer, reason and evidence reference are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_app FROM ug_bursary.applications WHERE application_ref=p_application_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Application % not found',p_application_ref USING ERRCODE='no_data_found'; END IF;
 IF v_app.status<>'rejected' THEN RAISE EXCEPTION 'Only rejected applications can be appealed in this demo' USING ERRCODE='check_violation'; END IF;
 INSERT INTO ug_bursary.appeals(appeal_ref,application_id,filed_by_ref,reason,evidence_reference)
 VALUES(p_appeal_ref,v_app.application_id,p_filed_by_ref,p_reason,p_evidence_reference)
 RETURNING appeal_id INTO v_appeal_id;
 INSERT INTO ug_bursary.application_events(application_id,event_type,from_status,to_status,actor_ref,reason,evidence_reference)
 VALUES(v_app.application_id,'appeal_filed',v_app.status,v_app.status,p_filed_by_ref,p_reason,p_evidence_reference);
 RETURN v_appeal_id;
END;
$$;

CREATE OR REPLACE FUNCTION ug_bursary.fn_review_appeal(
 p_appeal_ref TEXT,p_outcome TEXT,p_reviewer_ref TEXT,p_reason TEXT,p_evidence_reference TEXT
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_bursary
AS $$
DECLARE v_appeal ug_bursary.appeals%ROWTYPE; v_app ug_bursary.applications%ROWTYPE; v_event_id BIGINT;
BEGIN
 IF p_outcome NOT IN ('upheld','overturned') OR length(btrim(COALESCE(p_reviewer_ref,'')))=0
    OR length(btrim(COALESCE(p_reason,'')))=0 OR length(btrim(COALESCE(p_evidence_reference,'')))=0 THEN
  RAISE EXCEPTION 'Valid appeal outcome, reviewer, reason and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_appeal FROM ug_bursary.appeals WHERE appeal_ref=p_appeal_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Appeal % not found',p_appeal_ref USING ERRCODE='no_data_found'; END IF;
 IF v_appeal.status NOT IN ('submitted','under_review') THEN RAISE EXCEPTION 'Appeal already closed' USING ERRCODE='check_violation'; END IF;
 SELECT * INTO v_app FROM ug_bursary.applications WHERE application_id=v_appeal.application_id FOR UPDATE;
 UPDATE ug_bursary.appeals SET status='closed',outcome=p_outcome,reviewed_by=p_reviewer_ref,reviewed_at=clock_timestamp(),
   review_reason=p_reason,review_evidence_reference=p_evidence_reference WHERE appeal_id=v_appeal.appeal_id;
 IF p_outcome='overturned' THEN
  UPDATE ug_bursary.applications SET status='under_review',decision_at=NULL,decision_evidence_ref=NULL,decision_reason=NULL,updated_at=clock_timestamp()
  WHERE application_id=v_app.application_id;
  INSERT INTO ug_bursary.application_events(application_id,event_type,from_status,to_status,actor_ref,reason,evidence_reference)
  VALUES(v_app.application_id,'appeal_overturned',v_app.status,'under_review',p_reviewer_ref,p_reason,p_evidence_reference)
  RETURNING event_id INTO v_event_id;
 ELSE
  INSERT INTO ug_bursary.application_events(application_id,event_type,from_status,to_status,actor_ref,reason,evidence_reference)
  VALUES(v_app.application_id,'appeal_upheld',v_app.status,v_app.status,p_reviewer_ref,p_reason,p_evidence_reference)
  RETURNING event_id INTO v_event_id;
 END IF;
 RETURN v_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION ug_bursary.fn_record_disbursement(
 p_disbursement_ref TEXT,p_application_ref TEXT,p_idempotency_key TEXT,p_amount NUMERIC,
 p_currency_code TEXT,p_external_payment_ref TEXT,p_paid_at TIMESTAMPTZ,p_recorded_by TEXT
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_bursary
AS $$
DECLARE
 v_app ug_bursary.applications%ROWTYPE;
 v_programme ug_bursary.programmes%ROWTYPE;
 v_existing ug_bursary.disbursements%ROWTYPE;
 v_paid NUMERIC(14,2);
 v_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_idempotency_key,'')))<8
    OR length(btrim(COALESCE(p_disbursement_ref,'')))=0
    OR length(btrim(COALESCE(p_external_payment_ref,'')))=0
    OR length(btrim(COALESCE(p_recorded_by,'')))=0
    OR p_amount IS NULL OR p_amount<=0 OR p_amount<>round(p_amount,2)
    OR p_currency_code IS NULL OR p_paid_at IS NULL THEN
  RAISE EXCEPTION 'Disbursement requires valid references, a positive amount to two decimal places, currency, date and recorder'
    USING ERRCODE='invalid_parameter_value';
 END IF;
 -- Serialise retries by key before locking application rows.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_idempotency_key,0));
 SELECT * INTO v_existing FROM ug_bursary.disbursements
 WHERE idempotency_key=p_idempotency_key FOR UPDATE;
 IF FOUND THEN
  IF v_existing.disbursement_ref<>p_disbursement_ref
     OR v_existing.external_payment_ref<>p_external_payment_ref
     OR v_existing.amount<>p_amount
     OR v_existing.currency_code<>p_currency_code
     OR v_existing.paid_at<>p_paid_at
     OR v_existing.recorded_by<>p_recorded_by
     OR NOT EXISTS (SELECT 1 FROM ug_bursary.applications
                    WHERE application_id=v_existing.application_id AND application_ref=p_application_ref) THEN
   RAISE EXCEPTION 'Idempotency key was already used for a different disbursement request'
     USING ERRCODE='unique_violation';
  END IF;
  RETURN v_existing.disbursement_id;
 END IF;
 SELECT * INTO v_app FROM ug_bursary.applications WHERE application_ref=p_application_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Application % not found',p_application_ref USING ERRCODE='no_data_found'; END IF;
 IF v_app.status<>'approved' THEN RAISE EXCEPTION 'Only approved applications may be disbursed' USING ERRCODE='check_violation'; END IF;
 SELECT * INTO v_programme FROM ug_bursary.programmes WHERE programme_id=v_app.programme_id;
 SELECT COALESCE(SUM(amount),0) INTO v_paid FROM ug_bursary.disbursements WHERE application_id=v_app.application_id;
 IF v_paid+p_amount>v_programme.award_amount THEN
  RAISE EXCEPTION 'Disbursement must not exceed the award balance' USING ERRCODE='check_violation';
 END IF;
 IF p_currency_code<>v_programme.currency_code THEN
  RAISE EXCEPTION 'Disbursement currency must match the programme currency' USING ERRCODE='invalid_parameter_value';
 END IF;
 INSERT INTO ug_bursary.disbursements(disbursement_ref,idempotency_key,application_id,amount,currency_code,external_payment_ref,paid_at,recorded_by)
 VALUES(p_disbursement_ref,p_idempotency_key,v_app.application_id,p_amount,p_currency_code,p_external_payment_ref,p_paid_at,p_recorded_by)
 RETURNING disbursement_id INTO v_id;
 RETURN v_id;
END;
$$;
