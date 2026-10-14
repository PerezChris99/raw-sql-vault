-- Purpose: aggregate reporting separated from restricted learner support.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_attendance_aggregate_reader') THEN CREATE ROLE ug_attendance_aggregate_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_attendance_recorder') THEN CREATE ROLE ug_attendance_recorder NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_attendance_support_worker') THEN CREATE ROLE ug_attendance_support_worker NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_attendance FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_attendance TO ug_attendance_aggregate_reader,ug_attendance_recorder,ug_attendance_support_worker;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_attendance FROM PUBLIC;
GRANT SELECT ON ug_attendance.v_session_summary,ug_attendance.v_term_class_trends TO ug_attendance_aggregate_reader;
GRANT SELECT ON ug_attendance.schools,ug_attendance.terms,ug_attendance.sessions,ug_attendance.marks,ug_attendance.mark_corrections TO ug_attendance_recorder;
GRANT EXECUTE ON FUNCTION ug_attendance.fn_correct_mark(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_attendance_recorder;
GRANT SELECT ON ug_attendance.support_cases,ug_attendance.support_events,ug_attendance.v_open_support_queue TO ug_attendance_support_worker;
GRANT EXECUTE ON FUNCTION ug_attendance.fn_record_support_event(TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_attendance_support_worker;
REVOKE ALL ON FUNCTION ug_attendance.fn_correct_mark(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_attendance.fn_record_support_event(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_attendance FROM PUBLIC;
-- Map only authenticated, trained school staff to case access; enforce school-level row scope in deployment.
