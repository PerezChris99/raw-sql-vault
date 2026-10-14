-- Purpose: conflict-safe appointment booking, lifecycle transitions, cancellation and event history.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_clinic_sched.fn_book_appointment(
 p_appointment_ref TEXT,p_idempotency_key TEXT,p_slot_ref TEXT,p_patient_ref TEXT,p_recorded_by TEXT
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_clinic_sched
AS $$
DECLARE v_slot ug_clinic_sched.slots%ROWTYPE; v_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_patient_ref,'')))<3 OR length(btrim(COALESCE(p_recorded_by,'')))=0 THEN
  RAISE EXCEPTION 'Opaque patient reference and recorder are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_slot FROM ug_clinic_sched.slots WHERE slot_ref=p_slot_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Slot % not found',p_slot_ref USING ERRCODE='no_data_found'; END IF;
 IF v_slot.status<>'open' OR v_slot.starts_at<=now() THEN
  RAISE EXCEPTION 'Slot is closed or has already started' USING ERRCODE='check_violation';
 END IF;
 IF NOT EXISTS (
   SELECT 1 FROM ug_clinic_sched.clinics c JOIN ug_clinic_sched.services s ON s.service_id=v_slot.service_id
   WHERE c.clinic_id=v_slot.clinic_id AND c.is_active AND s.is_active
 ) THEN RAISE EXCEPTION 'Clinic or service is inactive' USING ERRCODE='check_violation'; END IF;
 INSERT INTO ug_clinic_sched.appointments(appointment_ref,idempotency_key,slot_id,patient_ref,recorded_by)
 VALUES(p_appointment_ref,p_idempotency_key,v_slot.slot_id,p_patient_ref,p_recorded_by)
 RETURNING appointment_id INTO v_id;
 INSERT INTO ug_clinic_sched.appointment_events(appointment_id,event_type,from_status,to_status,actor_ref,reason)
 VALUES(v_id,'booked',NULL,'booked',p_recorded_by,'Appointment booked');
 RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION ug_clinic_sched.fn_transition_appointment(
 p_appointment_ref TEXT,p_target_status TEXT,p_actor_ref TEXT,p_reason TEXT
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_clinic_sched
AS $$
DECLARE v_app ug_clinic_sched.appointments%ROWTYPE; v_slot ug_clinic_sched.slots%ROWTYPE; v_event_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_reason,'')))=0 THEN
  RAISE EXCEPTION 'Actor and reason are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_app FROM ug_clinic_sched.appointments WHERE appointment_ref=p_appointment_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Appointment % not found',p_appointment_ref USING ERRCODE='no_data_found'; END IF;
 SELECT * INTO v_slot FROM ug_clinic_sched.slots WHERE slot_id=v_app.slot_id;
 IF NOT (
   (v_app.status='booked' AND p_target_status IN ('checked_in','no_show')) OR
   (v_app.status='checked_in' AND p_target_status='completed')
 ) THEN
  RAISE EXCEPTION 'Invalid appointment transition % -> %',v_app.status,p_target_status USING ERRCODE='check_violation';
 END IF;
 IF p_target_status='no_show' AND v_slot.ends_at>now() THEN
  RAISE EXCEPTION 'Appointment cannot be marked no-show before its slot ends' USING ERRCODE='check_violation';
 END IF;
 UPDATE ug_clinic_sched.appointments SET status=p_target_status WHERE appointment_id=v_app.appointment_id;
 INSERT INTO ug_clinic_sched.appointment_events(appointment_id,event_type,from_status,to_status,actor_ref,reason)
 VALUES(v_app.appointment_id,p_target_status,v_app.status,p_target_status,p_actor_ref,p_reason)
 RETURNING event_id INTO v_event_id;
 RETURN v_event_id;
END;
$$;

CREATE OR REPLACE FUNCTION ug_clinic_sched.fn_cancel_appointment(
 p_appointment_ref TEXT,p_actor_ref TEXT,p_reason TEXT
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_clinic_sched
AS $$
DECLARE v_app ug_clinic_sched.appointments%ROWTYPE; v_event_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_reason,'')))=0 THEN
  RAISE EXCEPTION 'Actor and cancellation reason are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_app FROM ug_clinic_sched.appointments WHERE appointment_ref=p_appointment_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Appointment % not found',p_appointment_ref USING ERRCODE='no_data_found'; END IF;
 IF v_app.status NOT IN ('booked','checked_in') THEN
  RAISE EXCEPTION 'Only active appointments can be cancelled' USING ERRCODE='check_violation';
 END IF;
 UPDATE ug_clinic_sched.appointments SET status='cancelled',cancelled_at=clock_timestamp(),cancellation_reason=p_reason
 WHERE appointment_id=v_app.appointment_id;
 INSERT INTO ug_clinic_sched.appointment_events(appointment_id,event_type,from_status,to_status,actor_ref,reason)
 VALUES(v_app.appointment_id,'cancelled',v_app.status,'cancelled',p_actor_ref,p_reason)
 RETURNING event_id INTO v_event_id;
 RETURN v_event_id;
END;
$$;
