-- Purpose: attendance quality, term-level aggregate and confidential support case reporting.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Session summaries after the teacher submits a register.
SELECT * FROM ug_attendance.v_session_summary ORDER BY session_date,school_ref,class_ref;
-- 02. Class/term trends; interpret alongside enrollment and calendar coverage.
SELECT * FROM ug_attendance.v_term_class_trends ORDER BY academic_year,school_ref,class_ref;
-- 03. Open support queue; restricted access only.
SELECT * FROM ug_attendance.v_open_support_queue ORDER BY opened_at,support_ref;
-- 04. Corrections with evidence.
SELECT s.session_ref,m.learner_ref,c.previous_status,c.corrected_status,c.reason,c.evidence_ref,c.corrected_by_ref,c.corrected_at
FROM ug_attendance.mark_corrections c JOIN ug_attendance.marks m USING(mark_id)
JOIN ug_attendance.sessions s USING(session_id) ORDER BY c.corrected_at DESC;
-- 05. Sessions with no marks for completion follow-up.
SELECT s.session_ref,sch.school_ref,s.session_date,s.class_ref,s.status
FROM ug_attendance.sessions s JOIN ug_attendance.schools sch USING(school_id)
LEFT JOIN ug_attendance.marks m USING(session_id)
GROUP BY s.session_id,s.session_ref,sch.school_ref,s.session_date,s.class_ref,s.status
HAVING COUNT(m.mark_id)=0 ORDER BY s.session_date;
-- 06. Do not rank learners or schools by raw absence counts without context, completeness and human review.
