INSERT INTO public_service_demo.departments(department_code,department_label) VALUES
('DEMO-DEPT-A','Synthetic Service Delivery Office'),('DEMO-DEPT-B','Synthetic Records Office')
ON CONFLICT(department_code) DO NOTHING;
INSERT INTO public_service_demo.training_courses(course_code,course_title,topic,duration_hours) VALUES
('DEMO-COURSE-001','Synthetic Digital Service Basics','digital_skills',12),
('DEMO-COURSE-002','Synthetic Records Lifecycle','records_management',8),
('DEMO-COURSE-003','Synthetic Ethical Service Practice','ethics',6)
ON CONFLICT(course_code) DO NOTHING;
INSERT INTO public_service_demo.cohorts(cohort_ref,course_id,department_id,starts_on,ends_on,capacity,status)
SELECT v.ref,c.course_id,d.department_id,v.start_date,v.end_date,v.capacity,v.status
FROM (VALUES
('DEMO-COHORT-001','DEMO-COURSE-001','DEMO-DEPT-A',DATE '2026-09-01',DATE '2026-09-03',25,'completed'),
('DEMO-COHORT-002','DEMO-COURSE-002','DEMO-DEPT-B',DATE '2026-11-10',DATE '2026-11-11',20,'planned')
) v(ref,course,dept,start_date,end_date,capacity,status)
JOIN public_service_demo.training_courses c ON c.course_code=v.course
JOIN public_service_demo.departments d ON d.department_code=v.dept
ON CONFLICT(cohort_ref) DO NOTHING;
INSERT INTO public_service_demo.enrolments(enrolment_ref,cohort_id,staff_token,status,score,completion_note)
SELECT v.ref,c.cohort_id,v.token,v.status,v.score,v.note
FROM (VALUES
('DEMO-ENR-001','DEMO-COHORT-001','STAFF-TOKEN-A','completed',88::numeric,'Synthetic completion record'),
('DEMO-ENR-002','DEMO-COHORT-001','STAFF-TOKEN-B','attended',NULL::numeric,'Attendance only'),
('DEMO-ENR-003','DEMO-COHORT-002','STAFF-TOKEN-C','enrolled',NULL::numeric,NULL::text)
) v(ref,cohort,token,status,score,note)
JOIN public_service_demo.cohorts c ON c.cohort_ref=v.cohort
ON CONFLICT(enrolment_ref) DO NOTHING;