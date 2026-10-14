-- Purpose: synthetic TVET programme, skill, cohort and enrolment fixtures. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_tvet.institutions(institution_ref,institution_name,locality_ref,institution_type)
VALUES('UGTVET-I-DEMO-01','Synthetic Technical Training Centre','SYN-LOCALITY-01','public_tvet')
ON CONFLICT(institution_ref) DO NOTHING;
INSERT INTO ug_tvet.programmes(programme_ref,institution_id,programme_name,qualification_level,duration_weeks)
SELECT 'UGTVET-P-DEMO-01',institution_id,'Synthetic solar installation fundamentals','DEMO-LEVEL-1',24
FROM ug_tvet.institutions WHERE institution_ref='UGTVET-I-DEMO-01'
ON CONFLICT(programme_ref) DO NOTHING;
INSERT INTO ug_tvet.skills(skill_code,skill_name,skill_category,framework_ref) VALUES
('SYN-SOLAR-SAFETY','Electrical safety basics','safety','SYN-FRAMEWORK-01'),
('SYN-SOLAR-INSTALL','Solar installation practice','technical','SYN-FRAMEWORK-01')
ON CONFLICT(skill_code) DO NOTHING;
INSERT INTO ug_tvet.programme_skills(programme_id,skill_id,proficiency_target)
SELECT p.programme_id,s.skill_id,'working' FROM ug_tvet.programmes p CROSS JOIN ug_tvet.skills s
WHERE p.programme_ref='UGTVET-P-DEMO-01' AND s.skill_code IN ('SYN-SOLAR-SAFETY','SYN-SOLAR-INSTALL')
ON CONFLICT DO NOTHING;
INSERT INTO ug_tvet.cohorts(cohort_ref,programme_id,cohort_name,starts_on,planned_ends_on,status)
SELECT 'UGTVET-C-DEMO-01',programme_id,'Synthetic 2026 cohort',DATE '2026-02-01',DATE '2026-07-31','completed'
FROM ug_tvet.programmes WHERE programme_ref='UGTVET-P-DEMO-01'
ON CONFLICT(cohort_ref) DO NOTHING;
INSERT INTO ug_tvet.enrolments(enrolment_ref,cohort_id,trainee_ref,status,enrolled_on)
SELECT 'UGTVET-E-DEMO-01',cohort_id,'SYN-TRAINEE-001','completed',DATE '2026-02-01'
FROM ug_tvet.cohorts WHERE cohort_ref='UGTVET-C-DEMO-01'
ON CONFLICT(enrolment_ref) DO NOTHING;
