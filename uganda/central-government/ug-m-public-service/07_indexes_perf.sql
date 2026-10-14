-- Candidate indexes; validate with real query plans and synthetic volumes.
CREATE INDEX IF NOT EXISTS ix_ps_cohort_course_dates ON public_service_demo.cohorts(course_id,starts_on DESC);
CREATE INDEX IF NOT EXISTS ix_ps_enrolment_cohort_status ON public_service_demo.enrolments(cohort_id,status);