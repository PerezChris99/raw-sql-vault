-- Fictional grant call and proposal examples; re-runnable by stable refs.
INSERT INTO innovation_demo.calls(call_code,title,focus_area,opens_on,closes_on,budget_ceiling_ugx,status) VALUES
('DEMO-CALL-001','Synthetic Applied Research Call','agri_tech',DATE '2026-07-01',DATE '2026-10-31',250000000,'closed'),
('DEMO-CALL-002','Synthetic Public Innovation Challenge','civic_tech',DATE '2026-09-01',DATE '2026-12-15',100000000,'open')
ON CONFLICT(call_code) DO NOTHING;
INSERT INTO innovation_demo.proposals(proposal_ref,call_id,applicant_token,requested_budget_ugx,status,review_note)
SELECT v.ref,c.call_id,v.token,v.amount,v.status,v.note FROM (VALUES
('DEMO-PROP-001','DEMO-CALL-001','APPLICANT-TOKEN-A',75000000::numeric,'accepted','Synthetic review outcome'),
('DEMO-PROP-002','DEMO-CALL-001','APPLICANT-TOKEN-B',60000000::numeric,'under_review',NULL::text),
('DEMO-PROP-003','DEMO-CALL-002','APPLICANT-TOKEN-C',30000000::numeric,'submitted',NULL::text)
) v(ref,call,token,amount,status,note) JOIN innovation_demo.calls c ON c.call_code=v.call
ON CONFLICT(proposal_ref) DO NOTHING;
INSERT INTO innovation_demo.projects(project_ref,proposal_id,approved_budget_ugx,start_date,end_date,status)
SELECT 'DEMO-PROJECT-001',proposal_id,70000000,DATE '2026-11-01',DATE '2027-10-31','active'
FROM innovation_demo.proposals WHERE proposal_ref='DEMO-PROP-001'
ON CONFLICT(project_ref) DO NOTHING;
INSERT INTO innovation_demo.milestones(milestone_ref,project_id,title,due_date,status,evidence_ref)
SELECT v.ref,p.project_id,v.title,v.due,v.status,v.evidence FROM (VALUES
('DEMO-MILE-001','DEMO-PROJECT-001','Synthetic inception report',DATE '2026-11-30','in_progress','DEMO-EVIDENCE-001'),
('DEMO-MILE-002','DEMO-PROJECT-001','Synthetic prototype review',DATE '2027-03-31','open',NULL)
) v(ref,project,title,due,status,evidence) JOIN innovation_demo.projects p ON p.project_ref=v.project
ON CONFLICT(milestone_ref) DO NOTHING;