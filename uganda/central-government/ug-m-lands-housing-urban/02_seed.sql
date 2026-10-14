INSERT INTO urban_demo.applications(application_ref,applicant_token,locality_code,development_type,status) VALUES
('DEMO-URB-APP-001','APPLICANT-TOKEN-A','DEMO-AREA-A','residential','approved'),
('DEMO-URB-APP-002','APPLICANT-TOKEN-B','DEMO-AREA-B','commercial','under_review'),
('DEMO-URB-APP-003','APPLICANT-TOKEN-C','DEMO-AREA-A','public_facility','approved')
ON CONFLICT(application_ref) DO NOTHING;
INSERT INTO urban_demo.permits(permit_ref,application_id,issued_on,expires_on,status,permit_type,document_ref)
SELECT v.ref,a.application_id,v.issued,v.expires,v.status,v.typ,'DEMO-DOC'
FROM (VALUES('DEMO-URB-PERMIT-001','DEMO-URB-APP-001',DATE '2026-01-01',DATE '2027-01-01','active','development'),('DEMO-URB-PERMIT-003','DEMO-URB-APP-003',DATE '2025-06-01',DATE '2026-06-01','expired','public_facility')) v(ref,app,issued,expires,status,typ)
JOIN urban_demo.applications a ON a.application_ref=v.app ON CONFLICT(permit_ref) DO NOTHING;
INSERT INTO urban_demo.inspections(inspection_ref,application_id,inspected_at,inspection_type,outcome,inspector_ref,summary)
SELECT v.ref,a.application_id,v.at_time,v.typ,v.outcome,'DEMO-INSPECTOR',v.summary
FROM (VALUES('DEMO-URB-INSP-001','DEMO-URB-APP-001',TIMESTAMPTZ '2026-04-10 09:00+00','site_progress','acceptable','Synthetic progress review'),('DEMO-URB-INSP-002','DEMO-URB-APP-003',TIMESTAMPTZ '2026-05-15 10:00+00','follow_up','follow_up_required','Synthetic accessibility follow-up')) v(ref,app,at_time,typ,outcome,summary)
JOIN urban_demo.applications a ON a.application_ref=v.app ON CONFLICT(inspection_ref) DO NOTHING;
INSERT INTO urban_demo.actions(action_ref,inspection_id,summary,owner_ref,due_date,status)
SELECT 'DEMO-URB-ACT-001',inspection_id,'Review synthetic access mitigation','DEMO-OWNER',DATE '2026-11-15','open' FROM urban_demo.inspections WHERE inspection_ref='DEMO-URB-INSP-002'
ON CONFLICT(action_ref) DO NOTHING;