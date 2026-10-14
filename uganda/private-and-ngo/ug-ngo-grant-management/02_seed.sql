INSERT INTO ngo_demo.donors(donor_code,donor_label,donor_type) VALUES
('DEMO-DONOR-A','Synthetic Community Foundation','foundation'),
('DEMO-DONOR-B','Synthetic Programme Partner','multilateral_demo')
ON CONFLICT(donor_code) DO NOTHING;
INSERT INTO ngo_demo.projects(project_code,project_label,locality_code,sector,start_date,end_date,status) VALUES
('DEMO-PROJ-A','Synthetic youth skills initiative','DEMO-AREA-A','livelihoods',DATE '2026-01-01',DATE '2027-12-31','active'),
('DEMO-PROJ-B','Synthetic clean water access programme','DEMO-AREA-B','water',DATE '2026-04-01',DATE '2027-03-31','active')
ON CONFLICT(project_code) DO NOTHING;
INSERT INTO ngo_demo.grants(grant_ref,donor_id,project_id,agreement_ref,grant_currency,award_ceiling,start_date,end_date,status)
SELECT v.ref,d.donor_id,p.project_id,v.agreement,v.currency,v.ceiling,v.start_date,v.end_date,'active'
FROM (VALUES
('DEMO-GRANT-A','DEMO-DONOR-A','DEMO-PROJ-A','DEMO-AGR-A','UGX',120000000::numeric,DATE '2026-01-01',DATE '2027-12-31'),
('DEMO-GRANT-B','DEMO-DONOR-B','DEMO-PROJ-B','DEMO-AGR-B','UGX',80000000::numeric,DATE '2026-04-01',DATE '2027-03-31')
) v(ref,donor_code,project_code,agreement,currency,ceiling,start_date,end_date)
JOIN ngo_demo.donors d ON d.donor_code=v.donor_code JOIN ngo_demo.projects p ON p.project_code=v.project_code
ON CONFLICT(grant_ref) DO NOTHING;
INSERT INTO ngo_demo.milestones(milestone_ref,project_id,milestone_title,due_date,status)
SELECT v.ref,p.project_id,v.title,v.due,v.status FROM (VALUES
('DEMO-MILESTONE-A','DEMO-PROJ-A','Synthetic cohort training sessions complete',DATE '2026-12-15','planned'),
('DEMO-MILESTONE-B','DEMO-PROJ-B','Synthetic water points inspected',DATE '2026-10-01','delayed')
) v(ref,project_code,title,due,status) JOIN ngo_demo.projects p ON p.project_code=v.project_code
ON CONFLICT(milestone_ref) DO NOTHING;
INSERT INTO ngo_demo.outcome_observations(observation_ref,project_id,indicator_code,period_start,period_end,observed_value,unit_label,disaggregation_code,source_ref)
SELECT 'DEMO-OUTCOME-A',project_id,'training_sessions_completed',DATE '2026-07-01',DATE '2026-09-30',18,'sessions','total','DEMO-SOURCE-OUTCOME-A'
FROM ngo_demo.projects WHERE project_code='DEMO-PROJ-A' ON CONFLICT(observation_ref) DO NOTHING;