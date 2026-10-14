-- Purpose: synthetic school, term and session fixtures. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_attendance.schools(school_ref,locality_ref,school_name)
VALUES('UGSCH-DEMO-01','SYN-LOCALITY-01','Synthetic School Alpha')
ON CONFLICT(school_ref) DO NOTHING;
INSERT INTO ug_attendance.terms(term_ref,academic_year,term_name,starts_on,ends_on)
VALUES('UGTERM-DEMO-01','2026','Term 1',DATE '2026-02-01',DATE '2026-05-31')
ON CONFLICT(term_ref) DO NOTHING;
INSERT INTO ug_attendance.sessions(session_ref,school_id,term_id,session_date,class_ref,recorded_by_ref,source_ref)
SELECT 'UGATT-DEMO-001',s.school_id,t.term_id,DATE '2026-03-02','SYN-P4-A','SYN-TEACHER-01','SYN-REGISTER-001'
FROM ug_attendance.schools s CROSS JOIN ug_attendance.terms t
WHERE s.school_ref='UGSCH-DEMO-01' AND t.term_ref='UGTERM-DEMO-01'
ON CONFLICT(session_ref) DO NOTHING;
INSERT INTO ug_attendance.marks(session_id,learner_ref,attendance_status,reason_code,recorded_by_ref)
SELECT session_id,v.learner_ref,v.attendance_status,v.reason,'SYN-TEACHER-01'
FROM ug_attendance.sessions s CROSS JOIN (VALUES
 ('SYN-LEARNER-001','present',''),
 ('SYN-LEARNER-002','absent','unconfirmed'),
 ('SYN-LEARNER-003','late','transport_unknown')
) v(learner_ref,attendance_status,reason)
WHERE s.session_ref='UGATT-DEMO-001'
ON CONFLICT(session_id,learner_ref) DO NOTHING;
