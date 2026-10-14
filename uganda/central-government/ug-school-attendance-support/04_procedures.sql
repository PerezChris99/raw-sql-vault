-- Purpose: append evidence-backed corrections and supportive follow-up events.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_attendance.fn_correct_mark(
 p_session_ref TEXT,p_learner_ref TEXT,p_new_status TEXT,p_reason TEXT,p_evidence_ref TEXT,p_actor_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_attendance AS $$
DECLARE s ug_attendance.sessions%ROWTYPE; m ug_attendance.marks%ROWTYPE; v_id BIGINT;
BEGIN
 IF p_new_status NOT IN ('present','absent','late','excused') OR length(btrim(COALESCE(p_reason,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 OR length(btrim(COALESCE(p_actor_ref,'')))=0 THEN
  RAISE EXCEPTION 'Valid status, reason, evidence and actor are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO s FROM ug_attendance.sessions WHERE session_ref=p_session_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Session not found' USING ERRCODE='no_data_found'; END IF;
 IF s.status NOT IN ('submitted','corrected') THEN RAISE EXCEPTION 'Only submitted sessions can be corrected' USING ERRCODE='check_violation'; END IF;
 SELECT * INTO m FROM ug_attendance.marks WHERE session_id=s.session_id AND learner_ref=p_learner_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Learner mark not found' USING ERRCODE='no_data_found'; END IF;
 IF m.attendance_status=p_new_status THEN RAISE EXCEPTION 'Corrected status must differ from current status' USING ERRCODE='check_violation'; END IF;
 INSERT INTO ug_attendance.mark_corrections(mark_id,previous_status,corrected_status,reason,evidence_ref,corrected_by_ref)
 VALUES(m.mark_id,m.attendance_status,p_new_status,p_reason,p_evidence_ref,p_actor_ref) RETURNING correction_id INTO v_id;
 UPDATE ug_attendance.marks SET attendance_status=p_new_status,reason_code='corrected',recorded_by_ref=p_actor_ref,recorded_at=clock_timestamp()
 WHERE mark_id=m.mark_id;
 UPDATE ug_attendance.sessions SET status='corrected' WHERE session_id=s.session_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION ug_attendance.fn_record_support_event(
 p_support_ref TEXT,p_event_type TEXT,p_actor_ref TEXT,p_reason_redacted TEXT,p_evidence_ref TEXT DEFAULT NULL
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_attendance AS $$
DECLARE c ug_attendance.support_cases%ROWTYPE; v_id BIGINT;
BEGIN
 IF p_event_type NOT IN ('assigned','contact_attempt_recorded','referral','plan_agreed','review','resolved','reopened','closed')
 OR length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_reason_redacted,'')))=0 THEN
  RAISE EXCEPTION 'Valid event, actor and redacted reason are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO c FROM ug_attendance.support_cases WHERE support_ref=p_support_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Support case not found' USING ERRCODE='no_data_found'; END IF;
 IF c.status IN ('resolved','closed') AND p_event_type NOT IN ('reopened','review') THEN
  RAISE EXCEPTION 'Closed support case must be reopened before a new action' USING ERRCODE='check_violation';
 END IF;
 INSERT INTO ug_attendance.support_events(support_case_id,event_type,actor_ref,reason_redacted,evidence_ref)
 VALUES(c.support_case_id,p_event_type,p_actor_ref,p_reason_redacted,p_evidence_ref) RETURNING support_event_id INTO v_id;
 UPDATE ug_attendance.support_cases SET
 status=CASE p_event_type WHEN 'assigned' THEN 'assigned' WHEN 'referral' THEN 'referred'
 WHEN 'resolved' THEN 'resolved' WHEN 'closed' THEN 'closed' WHEN 'reopened' THEN 'open' ELSE status END,
 closed_at=CASE WHEN p_event_type IN ('resolved','closed') THEN clock_timestamp()
                WHEN p_event_type='reopened' THEN NULL ELSE closed_at END
 WHERE support_case_id=c.support_case_id;
 RETURN v_id;
END; $$;
