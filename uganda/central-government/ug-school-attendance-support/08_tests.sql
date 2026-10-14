-- Purpose: assertions for attendance correction evidence and supportive case closure/reopen.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_mark BIGINT; v_session BIGINT; v_school BIGINT; v_term BIGINT; v_case BIGINT; v_count BIGINT;
BEGIN
 SELECT session_id INTO v_session FROM ug_attendance.sessions WHERE session_ref='UGATT-DEMO-001';
 BEGIN
  PERFORM ug_attendance.fn_correct_mark('UGATT-DEMO-001','SYN-LEARNER-002','present','correction without evidence',NULL,'SYN-TEST-REVIEWER');
  RAISE EXCEPTION 'ASSERT correction without evidence was accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
 PERFORM ug_attendance.fn_correct_mark('UGATT-DEMO-001','SYN-LEARNER-002','present','synthetic register correction','SYN-CORRECTION-EVIDENCE-001','SYN-TEST-REVIEWER');
 SELECT COUNT(*) INTO v_count FROM ug_attendance.mark_corrections WHERE mark_id=(SELECT mark_id FROM ug_attendance.marks WHERE session_id=v_session AND learner_ref='SYN-LEARNER-002');
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT correction history missing'; END IF;
 SELECT school_id INTO v_school FROM ug_attendance.schools WHERE school_ref='UGSCH-DEMO-01';
 SELECT term_id INTO v_term FROM ug_attendance.terms WHERE term_ref='UGTERM-DEMO-01';
 INSERT INTO ug_attendance.support_cases(support_ref,school_id,learner_ref,term_id,concern_category,concern_summary_redacted,opened_by_ref)
 VALUES('UGSUP-DEMO-001',v_school,'SYN-LEARNER-002',v_term,'attendance_pattern','Synthetic supportive check-in; details stored separately','SYN-SCHOOL-COUNSELLOR')
 RETURNING support_case_id INTO v_case;
 PERFORM ug_attendance.fn_record_support_event('UGSUP-DEMO-001','assigned','SYN-SCHOOL-COUNSELLOR','assigned for supportive follow-up',NULL);
 PERFORM ug_attendance.fn_record_support_event('UGSUP-DEMO-001','resolved','SYN-SCHOOL-COUNSELLOR','support plan completed; no punitive inference',NULL);
 PERFORM ug_attendance.fn_record_support_event('UGSUP-DEMO-001','reopened','SYN-SCHOOL-COUNSELLOR','follow-up requested',NULL);
 SELECT COUNT(*) INTO v_count FROM ug_attendance.support_cases WHERE support_ref='UGSUP-DEMO-001' AND status='open' AND closed_at IS NULL;
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT case reopen did not reset status'; END IF;
END; $test$;
ROLLBACK;
