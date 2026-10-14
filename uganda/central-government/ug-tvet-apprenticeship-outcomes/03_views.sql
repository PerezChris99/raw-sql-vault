-- Purpose: cohort completion, assessed skill and placement outcome summaries.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_tvet.v_cohort_outcomes AS
SELECT i.institution_ref,p.programme_ref,p.programme_name,c.cohort_ref,c.starts_on,c.planned_ends_on,
 COUNT(e.enrolment_id) AS enrolments,
 COUNT(e.enrolment_id) FILTER(WHERE e.status='completed') AS completions,
 COUNT(e.enrolment_id) FILTER(WHERE e.status='withdrawn') AS withdrawals,
 round(100.0*COUNT(e.enrolment_id) FILTER(WHERE e.status='completed')/NULLIF(COUNT(e.enrolment_id),0),2) AS completion_percent
FROM ug_tvet.cohorts c JOIN ug_tvet.programmes p USING(programme_id)
JOIN ug_tvet.institutions i USING(institution_id)
LEFT JOIN ug_tvet.enrolments e USING(cohort_id)
GROUP BY i.institution_ref,p.programme_ref,p.programme_name,c.cohort_id,c.cohort_ref,c.starts_on,c.planned_ends_on;

CREATE OR REPLACE VIEW ug_tvet.v_latest_skill_assessments AS
SELECT e.enrolment_ref,e.trainee_ref,s.skill_code,s.skill_name,a.proficiency,a.assessed_on,a.assessor_ref,a.evidence_ref
FROM ug_tvet.assessments a JOIN ug_tvet.enrolments e USING(enrolment_id)
JOIN ug_tvet.skills s USING(skill_id)
WHERE a.status='valid' AND NOT EXISTS (
 SELECT 1 FROM ug_tvet.assessments newer
 WHERE newer.enrolment_id=a.enrolment_id AND newer.skill_id=a.skill_id AND newer.status='valid'
 AND (newer.assessed_on>a.assessed_on OR (newer.assessed_on=a.assessed_on AND newer.assessment_id>a.assessment_id))
);

CREATE OR REPLACE VIEW ug_tvet.v_placement_outcomes AS
SELECT p.placement_ref,p.placement_type,p.employer_ref,p.starts_on,p.ends_on,p.status,
 e.enrolment_ref,c.cohort_ref,pr.programme_ref
FROM ug_tvet.placements p JOIN ug_tvet.enrolments e USING(enrolment_id)
JOIN ug_tvet.cohorts c USING(cohort_id) JOIN ug_tvet.programmes pr USING(programme_id);
