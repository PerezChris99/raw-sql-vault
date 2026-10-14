-- Fictional examples. Subject tokens cannot be linked to real people.
INSERT INTO social_demo.programmes(programme_code,title,service_type,starts_on,ends_on,status) VALUES
('DEMO-SOC-001','Synthetic Skills Transition Programme','skills_training',DATE '2026-01-01',DATE '2027-12-31','active'),
('DEMO-SOC-002','Synthetic Employment Support Programme','employment_support',DATE '2026-04-01',DATE '2027-03-31','active')
ON CONFLICT(programme_code) DO NOTHING;
INSERT INTO social_demo.enrolments(enrolment_ref,programme_id,subject_token,status)
SELECT v.ref,p.programme_id,v.token,v.status FROM (VALUES
('DEMO-ENR-001','DEMO-SOC-001','SUBJECT-TOKEN-A','open'),
('DEMO-ENR-002','DEMO-SOC-001','SUBJECT-TOKEN-B','in_service'),
('DEMO-ENR-003','DEMO-SOC-002','SUBJECT-TOKEN-C','referred')
) v(ref,program,token,status) JOIN social_demo.programmes p ON p.programme_code=v.program
ON CONFLICT(enrolment_ref) DO NOTHING;
INSERT INTO social_demo.service_milestones(milestone_ref,enrolment_id,milestone_type,due_date,status,owner_ref,summary)
SELECT v.ref,e.enrolment_id,v.typ,v.due,v.status,'DEMO-CASEWORKER',v.summary FROM (VALUES
('DEMO-MILE-001','DEMO-ENR-001','assessment_scheduled',DATE '2026-11-15','open','Schedule synthetic needs assessment'),
('DEMO-MILE-002','DEMO-ENR-002','training_attended',DATE '2026-10-15','in_progress','Verify synthetic course attendance'),
('DEMO-MILE-003','DEMO-ENR-003','referral_acknowledged',DATE '2026-10-05','blocked','Await synthetic referral acknowledgement')
) v(ref,enrol,typ,due,status,summary) JOIN social_demo.enrolments e ON e.enrolment_ref=v.enrol
ON CONFLICT(milestone_ref) DO NOTHING;