-- PostgreSQL 15+ read-only queries; staff references are opaque synthetic tokens.
-- 01 Cohort capacity.
SELECT * FROM public_service_demo.v_cohort_summary ORDER BY starts_on,cohort_ref;
-- 02 Topic completion summary.
SELECT * FROM public_service_demo.v_completion_summary ORDER BY topic;
-- 03 Open cohorts with spare places.
SELECT * FROM public_service_demo.v_cohort_summary WHERE status IN('planned','open') AND places_remaining>0;
-- 04 Cohorts at or above capacity.
SELECT cohort_ref,enrolment_count,capacity FROM public_service_demo.v_cohort_summary WHERE enrolment_count>=capacity;
-- 05 Enrolments by status and department.
SELECT d.department_code,e.status,COUNT(*) FROM public_service_demo.enrolments e JOIN public_service_demo.cohorts c USING(cohort_id) JOIN public_service_demo.departments d USING(department_id) GROUP BY d.department_code,e.status;
-- 06 Courses without cohorts.
SELECT course_code FROM public_service_demo.training_courses cc WHERE NOT EXISTS(SELECT 1 FROM public_service_demo.cohorts c WHERE c.course_id=cc.course_id);
-- 07 Cohorts with no enrolments.
SELECT cohort_ref FROM public_service_demo.cohorts c WHERE NOT EXISTS(SELECT 1 FROM public_service_demo.enrolments e WHERE e.cohort_id=c.cohort_id);
-- 08 Completed enrolments missing scores (should be empty).
SELECT enrolment_ref FROM public_service_demo.enrolments WHERE status='completed' AND score IS NULL;
-- 09 Average score per course.
SELECT cc.course_code,AVG(e.score) FROM public_service_demo.enrolments e JOIN public_service_demo.cohorts c USING(cohort_id) JOIN public_service_demo.training_courses cc USING(course_id) WHERE e.status='completed' GROUP BY cc.course_code;
-- 10 Event history.
SELECT e.enrolment_ref,x.previous_status,x.new_status,x.actor_ref,x.happened_at FROM public_service_demo.enrolment_events x JOIN public_service_demo.enrolments e USING(enrolment_id) ORDER BY e.enrolment_ref,x.happened_at;
-- 11 Latest event per enrolment.
SELECT DISTINCT ON(enrolment_id) enrolment_id,new_status,happened_at FROM public_service_demo.enrolment_events ORDER BY enrolment_id,happened_at DESC,event_id DESC;
-- 12 Training hours scheduled by month.
SELECT date_trunc('month',starts_on)::date AS month_start,SUM(cc.duration_hours) FROM public_service_demo.cohorts c JOIN public_service_demo.training_courses cc USING(course_id) GROUP BY 1;
-- 13 Courses by topic.
SELECT topic,COUNT(*) FROM public_service_demo.training_courses WHERE active GROUP BY topic;
-- 14 Withdrawals by cohort.
SELECT cohort_ref,COUNT(*) FILTER(WHERE status='withdrawn') FROM public_service_demo.cohorts c LEFT JOIN public_service_demo.enrolments e USING(cohort_id) GROUP BY cohort_ref;
-- 15 Scheduled courses in the next 60 days.
SELECT cohort_ref,starts_on FROM public_service_demo.cohorts WHERE starts_on>=CURRENT_DATE AND starts_on<CURRENT_DATE+60 AND status IN('planned','open') ORDER BY starts_on;
-- 16 Enrolments by synthetic staff token.
SELECT staff_token,COUNT(*) FROM public_service_demo.enrolments GROUP BY staff_token ORDER BY 2 DESC;
-- 17 Courses needing attention due to low completion.
SELECT course_code,completed_count,enrolment_count FROM public_service_demo.v_cohort_summary WHERE enrolment_count>0 AND completed_count=0;
-- 18 Cohort duration.
SELECT cohort_ref,(ends_on-starts_on)+1 AS calendar_days FROM public_service_demo.cohorts;
-- 19 Data quality: inactive department with future cohort.
SELECT DISTINCT d.department_code FROM public_service_demo.departments d JOIN public_service_demo.cohorts c USING(department_id) WHERE NOT d.active AND c.starts_on>=CURRENT_DATE;
-- 20 Enrolment counts by course/topic.
SELECT cc.topic,cc.course_code,COUNT(e.enrolment_id) FROM public_service_demo.training_courses cc JOIN public_service_demo.cohorts c USING(course_id) LEFT JOIN public_service_demo.enrolments e USING(cohort_id) GROUP BY cc.topic,cc.course_code;