-- Purpose: assertions for booking idempotency, slot capacity, lifecycle and cancellation release.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seeds, views and procedures.
-- Run against a disposable database; all changes roll back.
BEGIN;
DO $test$
DECLARE v_count BIGINT; v_status TEXT; v_first_id BIGINT; v_replay_id BIGINT;
BEGIN
 -- Dedicated test slots stay future-dated and separate from the public demo seed slots.
 INSERT INTO ug_clinic_sched.slots(slot_ref,clinic_id,service_id,clinician_ref,starts_at,ends_at,status)
 SELECT v.slot_ref,c.clinic_id,s.service_id,v.clinician_ref,v.starts_at,
        v.starts_at+make_interval(mins=>s.default_duration_minutes),'open'
 FROM (VALUES
  ('UGSLOT-TEST-001','UGCL-DEMO-001','DEMO-CONSULT','SYN-CLINICIAN-TEST-01',now()+INTERVAL '2 days'),
  ('UGSLOT-TEST-002','UGCL-DEMO-001','DEMO-CONSULT','SYN-CLINICIAN-TEST-01',now()+INTERVAL '2 days 30 minutes')
 ) AS v(slot_ref,clinic_ref,service_code,clinician_ref,starts_at)
 JOIN ug_clinic_sched.clinics c ON c.clinic_ref=v.clinic_ref
 JOIN ug_clinic_sched.services s ON s.service_code=v.service_code;

 v_first_id:=ug_clinic_sched.fn_book_appointment('UGAPT-DEMO-0001','appt-idem-test-0001','UGSLOT-TEST-001','SYN-PATIENT-001','test-clerk');
 v_replay_id:=ug_clinic_sched.fn_book_appointment('UGAPT-DEMO-0001','appt-idem-test-0001','UGSLOT-TEST-001','SYN-PATIENT-001','test-clerk');
 IF v_first_id<>v_replay_id THEN RAISE EXCEPTION 'ASSERT matching idempotent replay did not return original appointment'; END IF;

 BEGIN
  PERFORM ug_clinic_sched.fn_book_appointment('UGAPT-DEMO-0099','appt-idem-test-0001','UGSLOT-TEST-001','SYN-PATIENT-999','test-clerk');
  RAISE EXCEPTION 'ASSERT idempotency key reuse with a different request was accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;

 BEGIN
  PERFORM ug_clinic_sched.fn_book_appointment('UGAPT-DEMO-0002','appt-idem-test-0002','UGSLOT-TEST-001','SYN-PATIENT-002','test-clerk');
  RAISE EXCEPTION 'ASSERT second active booking for a slot was accepted';
 EXCEPTION WHEN unique_violation THEN NULL; END;

 BEGIN
  PERFORM ug_clinic_sched.fn_transition_appointment('UGAPT-DEMO-0001','completed','test-clerk','skip check-in');
  RAISE EXCEPTION 'ASSERT booked -> completed transition was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;

 PERFORM ug_clinic_sched.fn_cancel_appointment('UGAPT-DEMO-0001','test-clerk','synthetic cancellation');
 PERFORM ug_clinic_sched.fn_book_appointment('UGAPT-DEMO-0003','appt-idem-test-0003','UGSLOT-TEST-001','SYN-PATIENT-003','test-clerk');
 PERFORM ug_clinic_sched.fn_book_appointment('UGAPT-DEMO-0004','appt-idem-test-0004','UGSLOT-TEST-002','SYN-PATIENT-004','test-clerk');
 PERFORM ug_clinic_sched.fn_transition_appointment('UGAPT-DEMO-0004','checked_in','test-clerk','synthetic arrival');
 PERFORM ug_clinic_sched.fn_transition_appointment('UGAPT-DEMO-0004','completed','test-clerk','synthetic service completion');
 SELECT status INTO v_status FROM ug_clinic_sched.appointments WHERE appointment_ref='UGAPT-DEMO-0004';
 IF v_status<>'completed' THEN RAISE EXCEPTION 'ASSERT valid appointment lifecycle did not complete'; END IF;

 SELECT COUNT(*) INTO v_count FROM ug_clinic_sched.appointments
 WHERE slot_id=(SELECT slot_id FROM ug_clinic_sched.slots WHERE slot_ref='UGSLOT-TEST-001')
 AND status IN ('booked','checked_in');
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT cancellation did not release slot capacity'; END IF;

 BEGIN
  PERFORM ug_clinic_sched.fn_cancel_appointment('UGAPT-DEMO-0003','test-clerk','');
  RAISE EXCEPTION 'ASSERT blank cancellation reason was accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END;
$test$;
ROLLBACK;
