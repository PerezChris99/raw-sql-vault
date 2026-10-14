-- Purpose: controlled custody transfer and evidence-backed record disposition.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_records.fn_transfer_custody(
 p_record_ref TEXT,p_to_office_ref TEXT,p_transferred_by TEXT,p_accepted_by TEXT,p_evidence_ref TEXT,p_reason TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_records AS $$
DECLARE r ug_records.records%ROWTYPE; v_to BIGINT; v_event BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_transferred_by,'')))=0 OR length(btrim(COALESCE(p_accepted_by,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 OR length(btrim(COALESCE(p_reason,'')))=0 THEN
  RAISE EXCEPTION 'Transfer actor, acceptance, evidence and reason are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO r FROM ug_records.records WHERE record_ref=p_record_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Record not found' USING ERRCODE='no_data_found'; END IF;
 IF r.status='disposed' THEN RAISE EXCEPTION 'Disposed record cannot be transferred' USING ERRCODE='check_violation'; END IF;
 SELECT office_id INTO v_to FROM ug_records.offices WHERE office_ref=p_to_office_ref AND is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Active destination office not found' USING ERRCODE='no_data_found'; END IF;
 INSERT INTO ug_records.custody_events(record_id,from_office_id,to_office_id,transferred_by_ref,accepted_by_ref,evidence_ref,reason)
 VALUES(r.record_id,r.current_custodian_office_id,v_to,p_transferred_by,p_accepted_by,p_evidence_ref,p_reason)
 RETURNING custody_event_id INTO v_event;
 UPDATE ug_records.records SET current_custodian_office_id=v_to,status='transferred' WHERE record_id=r.record_id;
 RETURN v_event;
END; $$;

CREATE OR REPLACE FUNCTION ug_records.fn_review_disposition(
 p_disposition_ref TEXT,p_decision TEXT,p_reviewer_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_records AS $$
DECLARE d ug_records.disposition_requests%ROWTYPE; r ug_records.records%ROWTYPE; v_event BIGINT;
BEGIN
 IF p_decision NOT IN ('approved','rejected') OR length(btrim(COALESCE(p_reviewer_ref,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Decision, reviewer and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO d FROM ug_records.disposition_requests WHERE disposition_ref=p_disposition_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Disposition request not found' USING ERRCODE='no_data_found'; END IF;
 IF d.status<>'requested' THEN RAISE EXCEPTION 'Disposition request already reviewed' USING ERRCODE='check_violation'; END IF;
 SELECT * INTO r FROM ug_records.records WHERE record_id=d.record_id FOR UPDATE;
 IF r.legal_hold THEN RAISE EXCEPTION 'Record is under legal hold' USING ERRCODE='check_violation'; END IF;
 IF p_decision='approved' AND (r.retention_until IS NULL OR r.retention_until>CURRENT_DATE) THEN
  RAISE EXCEPTION 'Retention period has not elapsed' USING ERRCODE='check_violation';
 END IF;
 UPDATE ug_records.disposition_requests SET status=p_decision,reviewed_by_ref=p_reviewer_ref,
 reviewed_at=clock_timestamp(),review_evidence_ref=p_evidence_ref WHERE disposition_id=d.disposition_id;
 RETURN d.disposition_id;
END; $$;

CREATE OR REPLACE FUNCTION ug_records.fn_execute_disposition(
 p_disposition_ref TEXT,p_actor_ref TEXT,p_execution_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_records AS $$
DECLARE d ug_records.disposition_requests%ROWTYPE; r ug_records.records%ROWTYPE;
BEGIN
 IF length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_execution_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Execution actor and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO d FROM ug_records.disposition_requests WHERE disposition_ref=p_disposition_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Disposition request not found' USING ERRCODE='no_data_found'; END IF;
 SELECT * INTO r FROM ug_records.records WHERE record_id=d.record_id FOR UPDATE;
 IF d.status<>'approved' OR r.legal_hold OR r.status='disposed' THEN
  RAISE EXCEPTION 'Record is not eligible for disposition execution' USING ERRCODE='check_violation';
 END IF;
 UPDATE ug_records.disposition_requests SET status='executed',executed_at=clock_timestamp(),
 execution_evidence_ref=p_execution_evidence_ref WHERE disposition_id=d.disposition_id;
 UPDATE ug_records.records SET status='disposed' WHERE record_id=r.record_id;
 INSERT INTO ug_records.access_events(record_id,actor_ref,action,purpose)
 VALUES(r.record_id,p_actor_ref,'correct_metadata','Approved disposition executed: '||p_disposition_ref);
 RETURN d.disposition_id;
END; $$;
