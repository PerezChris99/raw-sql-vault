-- Purpose: least-privilege scheduling and appointment management role groups.
-- Engine: PostgreSQL 15+. Prerequisite: controlled schema administrator.
DO $roles$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_clinic_sched_reader') THEN CREATE ROLE ug_clinic_sched_reader NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_clinic_sched_clerk') THEN CREATE ROLE ug_clinic_sched_clerk NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_clinic_sched_manager') THEN CREATE ROLE ug_clinic_sched_manager NOLOGIN; END IF;
END;
$roles$;
REVOKE ALL ON SCHEMA ug_clinic_sched FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_clinic_sched TO ug_clinic_sched_reader,ug_clinic_sched_clerk,ug_clinic_sched_manager;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_clinic_sched FROM PUBLIC;
GRANT SELECT ON ug_clinic_sched.services,ug_clinic_sched.v_available_slots,ug_clinic_sched.v_daily_clinic_load TO ug_clinic_sched_reader;
GRANT SELECT ON ug_clinic_sched.clinics,ug_clinic_sched.services,ug_clinic_sched.slots,
                ug_clinic_sched.appointments,ug_clinic_sched.appointment_events
TO ug_clinic_sched_clerk,ug_clinic_sched_manager;
GRANT EXECUTE ON FUNCTION ug_clinic_sched.fn_book_appointment(TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_clinic_sched_clerk;
GRANT EXECUTE ON FUNCTION ug_clinic_sched.fn_transition_appointment(TEXT,TEXT,TEXT,TEXT) TO ug_clinic_sched_clerk,ug_clinic_sched_manager;
GRANT EXECUTE ON FUNCTION ug_clinic_sched.fn_cancel_appointment(TEXT,TEXT,TEXT) TO ug_clinic_sched_clerk,ug_clinic_sched_manager;
REVOKE ALL ON FUNCTION ug_clinic_sched.fn_book_appointment(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_clinic_sched.fn_transition_appointment(TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_clinic_sched.fn_cancel_appointment(TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_clinic_sched FROM PUBLIC;
-- SECURITY DEFINER routines must remain trusted-owner functions with fixed search_path.
-- Real deployments need authenticated staff assignment, retention and access logging.
