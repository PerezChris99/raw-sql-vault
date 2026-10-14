CREATE OR REPLACE VIEW public_service_demo.v_cohort_summary AS
SELECT c.cohort_ref,cc.course_code,cc.course_title,d.department_code,c.starts_on,c.ends_on,c.capacity,c.status,
 COUNT(e.enrolment_id)::BIGINT AS enrolment_count,
 COUNT(e.enrolment_id) FILTER(WHERE e.status='completed')::BIGINT AS completed_count,
 c.capacity-COUNT(e.enrolment_id)::BIGINT AS places_remaining
FROM public_service_demo.cohorts c
JOIN public_service_demo.training_courses cc USING(course_id)
JOIN public_service_demo.departments d USING(department_id)
LEFT JOIN public_service_demo.enrolments e USING(cohort_id)
GROUP BY c.cohort_id,cc.course_code,cc.course_title,d.department_code;
CREATE OR REPLACE VIEW public_service_demo.v_completion_summary AS
SELECT cc.topic,COUNT(e.enrolment_id) AS enrolments,
 COUNT(e.enrolment_id) FILTER(WHERE e.status='completed') AS completed,
 ROUND(AVG(e.score) FILTER(WHERE e.status='completed'),2) AS average_score
FROM public_service_demo.enrolments e
JOIN public_service_demo.cohorts c USING(cohort_id)
JOIN public_service_demo.training_courses cc USING(course_id)
GROUP BY cc.topic;