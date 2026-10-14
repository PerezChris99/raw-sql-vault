-- Fictional programme/applicant data; safe to re-run by stable references.
INSERT INTO trade_demo.programmes(programme_code,title,service_type,starts_on,ends_on,status) VALUES
('DEMO-TRADE-PROG-001','Synthetic Export Readiness Cohort','export_readiness',DATE '2026-07-01',DATE '2027-06-30','active'),
('DEMO-TRADE-PROG-002','Synthetic Regional Market Access','market_access',DATE '2026-09-01',DATE '2027-08-31','active')
ON CONFLICT(programme_code) DO NOTHING;
INSERT INTO trade_demo.applicant_refs(applicant_token,business_type,sector_code,locality_code) VALUES
('BIZ-TOKEN-A','small','DEMO-AGRO','DEMO-AREA-A'),
('BIZ-TOKEN-B','cooperative','DEMO-HANDCRAFT','DEMO-AREA-B'),
('BIZ-TOKEN-C','medium','DEMO-FOOD','DEMO-AREA-A')
ON CONFLICT(applicant_token) DO NOTHING;
INSERT INTO trade_demo.applications(application_ref,programme_id,applicant_id,status,decision_note)
SELECT v.ref,p.programme_id,a.applicant_id,v.status,v.note FROM (VALUES
('DEMO-APP-001','DEMO-TRADE-PROG-001','BIZ-TOKEN-A','accepted','Synthetic acceptance'),
('DEMO-APP-002','DEMO-TRADE-PROG-001','BIZ-TOKEN-B','in_review','Synthetic review'),
('DEMO-APP-003','DEMO-TRADE-PROG-002','BIZ-TOKEN-C','submitted',NULL::text)
) v(ref,program,token,status,note) JOIN trade_demo.programmes p ON p.programme_code=v.program JOIN trade_demo.applicant_refs a ON a.applicant_token=v.token
ON CONFLICT(application_ref) DO NOTHING;
INSERT INTO trade_demo.milestones(milestone_ref,application_id,milestone_type,owner_ref,due_date,status,summary)
SELECT v.ref,a.application_id,v.typ,'DEMO-ADVISER',v.due,v.status,v.summary FROM (VALUES
('DEMO-TR-MILE-001','DEMO-APP-001','diagnostic',DATE '2026-10-20','completed','Synthetic export-readiness diagnostic'),
('DEMO-TR-MILE-002','DEMO-APP-002','quality_review',DATE '2026-11-10','open','Synthetic quality-document review'),
('DEMO-TR-MILE-003','DEMO-APP-003','training',DATE '2026-12-01','in_progress','Synthetic export basics session')
) v(ref,app,typ,due,status,summary) JOIN trade_demo.applications a ON a.application_ref=v.app
ON CONFLICT(milestone_ref) DO NOTHING;