-- Purpose: inspect term aggregates and restricted support queue plans.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_attendance.sessions;
ANALYZE ug_attendance.marks;
ANALYZE ug_attendance.support_cases;
EXPLAIN (COSTS, VERBOSE)
SELECT session_id,attendance_status,COUNT(*) FROM ug_attendance.marks WHERE session_id=1 GROUP BY session_id,attendance_status;
EXPLAIN (COSTS, VERBOSE)
SELECT support_ref,status,opened_at FROM ug_attendance.support_cases WHERE status IN ('open','assigned','referred') ORDER BY opened_at;
