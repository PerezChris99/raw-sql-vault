-- Purpose: auditable ticket lifecycle and first-response capture.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_support.fn_transition_ticket(
 p_ticket_ref TEXT,p_target_status TEXT,p_actor_ref TEXT,p_note_redacted TEXT,p_evidence_ref TEXT DEFAULT NULL
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_support AS $$
DECLARE t ug_support.tickets%ROWTYPE; v_id BIGINT; v_type TEXT;
BEGIN
 IF length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_note_redacted,'')))=0 THEN
  RAISE EXCEPTION 'Actor and redacted note are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO t FROM ug_support.tickets WHERE ticket_ref=p_ticket_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Ticket not found' USING ERRCODE='no_data_found'; END IF;
 IF NOT (
 (t.status='open' AND p_target_status IN ('assigned','waiting_customer','waiting_third_party','resolved')) OR
 (t.status='assigned' AND p_target_status IN ('waiting_customer','waiting_third_party','resolved','closed')) OR
 (t.status IN ('waiting_customer','waiting_third_party') AND p_target_status IN ('assigned','resolved')) OR
 (t.status='resolved' AND p_target_status IN ('closed','reopened')) OR
 (t.status='closed' AND p_target_status='reopened') OR
 (t.status='reopened' AND p_target_status IN ('assigned','waiting_customer','waiting_third_party','resolved'))
 ) THEN RAISE EXCEPTION 'Invalid ticket transition % -> %',t.status,p_target_status USING ERRCODE='check_violation'; END IF;
 v_type:=CASE p_target_status WHEN 'resolved' THEN 'resolved' WHEN 'closed' THEN 'closed' WHEN 'reopened' THEN 'reopened' ELSE 'status_changed' END;
 UPDATE ug_support.tickets SET status=p_target_status,
 resolved_at=CASE WHEN p_target_status='resolved' THEN COALESCE(resolved_at,clock_timestamp()) WHEN p_target_status='reopened' THEN NULL ELSE resolved_at END,
 closed_at=CASE WHEN p_target_status='closed' THEN clock_timestamp() WHEN p_target_status='reopened' THEN NULL ELSE closed_at END
 WHERE ticket_id=t.ticket_id;
 INSERT INTO ug_support.ticket_events(ticket_id,event_type,from_status,to_status,actor_ref,note_redacted,evidence_ref)
 VALUES(t.ticket_id,v_type,t.status,p_target_status,p_actor_ref,p_note_redacted,p_evidence_ref) RETURNING event_id INTO v_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION ug_support.fn_record_first_response(
 p_ticket_ref TEXT,p_actor_ref TEXT,p_note_redacted TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_support AS $$
DECLARE t ug_support.tickets%ROWTYPE; v_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_note_redacted,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN RAISE EXCEPTION 'Response actor, note and evidence are required' USING ERRCODE='invalid_parameter_value'; END IF;
 SELECT * INTO t FROM ug_support.tickets WHERE ticket_ref=p_ticket_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Ticket not found' USING ERRCODE='no_data_found'; END IF;
 IF t.first_response_at IS NOT NULL THEN RAISE EXCEPTION 'First response already recorded' USING ERRCODE='unique_violation'; END IF;
 UPDATE ug_support.tickets SET first_response_at=clock_timestamp(),assigned_to_ref=COALESCE(assigned_to_ref,p_actor_ref),status=CASE WHEN status='open' THEN 'assigned' ELSE status END
 WHERE ticket_id=t.ticket_id;
 INSERT INTO ug_support.ticket_events(ticket_id,event_type,from_status,to_status,actor_ref,note_redacted,evidence_ref)
 VALUES(t.ticket_id,'first_response',t.status,CASE WHEN t.status='open' THEN 'assigned' ELSE t.status END,p_actor_ref,p_note_redacted,p_evidence_ref)
 RETURNING event_id INTO v_id;
 RETURN v_id;
END; $$;
