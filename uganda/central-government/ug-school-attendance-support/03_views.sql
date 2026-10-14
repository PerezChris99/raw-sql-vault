-- Purpose: term/class attendance aggregates and restricted open support queue.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_attendance.v_session_summary AS
SELECT s.session_ref,sch.school_ref,s.session_date,s.class_ref,t.academic_year,t.term_name,
 COUNT(m.mark_id) AS recorded_learners,
 COUNT(m.mark_id) FILTER(WHERE m.attendance_status='present') AS present_count,
 COUNT(m.mark_id) FILTER(WHERE m.attendance_status='absent') AS absent_count,
 COUNT(m.mark_id) FILTER(WHERE m.attendance_status='late') AS late_count,
 COUNT(m.mark_id) FILTER(WHERE m.attendance_status='excused') AS excused_count
FROM ug_attendance.sessions s JOIN ug_attendance.schools sch USING(school_id)
JOIN ug_attendance.terms t USING(term_id)
LEFT JOIN ug_attendance.marks m USING(session_id)
WHERE s.status IN ('submitted','corrected')
GROUP BY s.session_id,s.session_ref,sch.school_ref,s.session_date,s.class_ref,t.academic_year,t.term_name;

CREATE OR REPLACE VIEW ug_attendance.v_term_class_trends AS
SELECT sch.school_ref,s.class_ref,t.academic_year,t.term_name,
 COUNT(DISTINCT s.session_id) AS sessions,
 COUNT(m.mark_id) AS marks,
 COUNT(m.mark_id) FILTER(WHERE m.attendance_status='present') AS present_marks,
 COUNT(m.mark_id) FILTER(WHERE m.attendance_status='absent') AS absent_marks,
 round(100.0*COUNT(m.mark_id) FILTER(WHERE m.attendance_status='present')/NULLIF(COUNT(m.mark_id),0),2) AS present_percent
FROM ug_attendance.sessions s JOIN ug_attendance.schools sch USING(school_id)
JOIN ug_attendance.terms t USING(term_id)
JOIN ug_attendance.marks m USING(session_id)
WHERE s.status IN ('submitted','corrected')
GROUP BY sch.school_ref,s.class_ref,t.academic_year,t.term_name;

CREATE OR REPLACE VIEW ug_attendance.v_open_support_queue AS
SELECT c.support_ref,sch.school_ref,c.learner_ref,t.term_ref,c.concern_category,c.status,c.opened_at,c.opened_by_ref
FROM ug_attendance.support_cases c JOIN ug_attendance.schools sch USING(school_id)
JOIN ug_attendance.terms t USING(term_id)
WHERE c.status IN ('open','assigned','referred');
