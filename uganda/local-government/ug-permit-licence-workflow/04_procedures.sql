-- Purpose: enforce allowed application state transitions and record decisions.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_permit.fn_transition_application(
    p_application_ref TEXT,
    p_target_status TEXT,
    p_actor_ref TEXT,
    p_reason TEXT,
    p_evidence_ref TEXT DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,ug_permit
AS $$
DECLARE
    v_app ug_permit.applications%ROWTYPE;
    v_event_id BIGINT;
    v_event_type TEXT;
BEGIN
    IF length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_reason,'')))=0 THEN
        RAISE EXCEPTION 'Actor and reason are required' USING ERRCODE='invalid_parameter_value';
    END IF;
    IF p_target_status NOT IN ('submitted','under_review','awaiting_documents','approved','rejected','withdrawn','expired') THEN
        RAISE EXCEPTION 'Unsupported target status: %',p_target_status USING ERRCODE='check_violation';
    END IF;
    SELECT * INTO v_app FROM ug_permit.applications
    WHERE application_ref=p_application_ref FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Application % not found',p_application_ref USING ERRCODE='no_data_found'; END IF;
    IF NOT (
      (v_app.status='draft' AND p_target_status IN ('submitted','withdrawn')) OR
      (v_app.status='submitted' AND p_target_status IN ('under_review','awaiting_documents','withdrawn')) OR
      (v_app.status='under_review' AND p_target_status IN ('awaiting_documents','approved','rejected','withdrawn')) OR
      (v_app.status='awaiting_documents' AND p_target_status IN ('under_review','withdrawn')) OR
      (v_app.status='approved' AND p_target_status='expired')
    ) THEN
        RAISE EXCEPTION 'Invalid application transition: % -> %',v_app.status,p_target_status
            USING ERRCODE='check_violation';
    END IF;
    IF p_target_status IN ('approved','rejected') AND length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
        RAISE EXCEPTION 'A recorded decision requires an evidence/reference identifier'
            USING ERRCODE='check_violation';
    END IF;
    v_event_type := CASE p_target_status
      WHEN 'submitted' THEN 'submitted'
      WHEN 'under_review' THEN 'assigned_for_review'
      WHEN 'awaiting_documents' THEN 'requested_documents'
      WHEN 'approved' THEN 'approved'
      WHEN 'rejected' THEN 'rejected'
      WHEN 'withdrawn' THEN 'withdrawn'
      WHEN 'expired' THEN 'expired'
    END;
    UPDATE ug_permit.applications
    SET status=p_target_status,
        submitted_at=CASE WHEN p_target_status='submitted' THEN COALESCE(submitted_at,clock_timestamp()) ELSE submitted_at END,
        decision_at=CASE WHEN p_target_status IN ('approved','rejected') THEN clock_timestamp() ELSE decision_at END,
        expires_on=CASE WHEN p_target_status='approved'
          THEN (CURRENT_DATE + (SELECT validity_days FROM ug_permit.permit_types WHERE permit_type_id=v_app.permit_type_id))
          WHEN p_target_status='expired' THEN COALESCE(expires_on,CURRENT_DATE)
          ELSE expires_on END,
        updated_at=clock_timestamp()
    WHERE application_id=v_app.application_id;
    INSERT INTO ug_permit.application_events(application_id,event_type,from_status,to_status,actor_ref,reason,evidence_ref)
    VALUES(v_app.application_id,v_event_type,v_app.status,p_target_status,p_actor_ref,p_reason,p_evidence_ref)
    RETURNING event_id INTO v_event_id;
    RETURN v_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION ug_permit.fn_record_document(
    p_application_ref TEXT,p_document_type TEXT,p_object_ref TEXT,p_sha256_hex TEXT,
    p_uploaded_by TEXT,p_classification TEXT DEFAULT 'restricted'
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,ug_permit
AS $$
DECLARE v_app_id BIGINT; v_document_id BIGINT;
BEGIN
    SELECT application_id INTO v_app_id FROM ug_permit.applications
    WHERE application_ref=p_application_ref;
    IF v_app_id IS NULL THEN RAISE EXCEPTION 'Application % not found',p_application_ref USING ERRCODE='no_data_found'; END IF;
    INSERT INTO ug_permit.application_documents(application_id,document_type,object_ref,sha256_hex,uploaded_by,classification)
    VALUES(v_app_id,p_document_type,p_object_ref,p_sha256_hex,p_uploaded_by,p_classification)
    RETURNING document_id INTO v_document_id;
    INSERT INTO ug_permit.application_events(application_id,event_type,from_status,to_status,actor_ref,reason,evidence_ref)
    SELECT v_app_id,'documents_received',a.status,a.status,p_uploaded_by,
           'Document metadata recorded: '||p_document_type,'document:'||v_document_id
    FROM ug_permit.applications a WHERE a.application_id=v_app_id;
    RETURN v_document_id;
END;
$$;
