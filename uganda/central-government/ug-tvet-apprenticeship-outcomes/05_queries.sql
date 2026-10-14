-- Purpose: cohort outcomes, skills evidence and placement reporting.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Completion and withdrawal counts by cohort.
SELECT * FROM ug_tvet.v_cohort_outcomes ORDER BY programme_ref,cohort_ref;
-- 02. Latest valid skill assessments; restrict trainee-level output to authorised assessors.
SELECT * FROM ug_tvet.v_latest_skill_assessments ORDER BY enrolment_ref,skill_code;
-- 03. Placement outcomes by type and status.
SELECT programme_ref,placement_type,status,COUNT(*) AS placements
FROM ug_tvet.v_placement_outcomes GROUP BY programme_ref,placement_type,status ORDER BY programme_ref,placement_type,status;
-- 04. Feedback quality and rating distribution.
SELECT skill_code,rating,COUNT(*) AS feedback_count
FROM ug_tvet.employer_feedback GROUP BY skill_code,rating ORDER BY skill_code,rating;
-- 05. Active placements ending in the next 30 days.
SELECT * FROM ug_tvet.v_placement_outcomes
WHERE status='active' AND ends_on BETWEEN CURRENT_DATE AND CURRENT_DATE+30 ORDER BY ends_on;
-- 06. Completed cohort without a recorded outcome.
SELECT e.enrolment_ref,c.cohort_ref FROM ug_tvet.enrolments e JOIN ug_tvet.cohorts c USING(cohort_id)
WHERE e.status='completed' AND NOT EXISTS(SELECT 1 FROM ug_tvet.placements p WHERE p.enrolment_id=e.enrolment_id AND p.status='completed');
