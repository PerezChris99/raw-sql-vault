-- Fictional examples; stable references permit safe re-run.
INSERT INTO energy_demo.licence_holders(holder_ref,holder_type) VALUES
('DEMO-HOLDER-001','private_operator'),('DEMO-HOLDER-002','cooperative'),('DEMO-HOLDER-003','public_operator')
ON CONFLICT(holder_ref) DO NOTHING;
INSERT INTO energy_demo.licences(licence_ref,holder_id,sector,issued_on,expires_on,status,region_code,public_summary)
SELECT v.ref,h.holder_id,v.sector,v.issued,v.expires,v.status,v.region,v.summary
FROM (VALUES
('DEMO-LIC-001','DEMO-HOLDER-001','renewable',DATE '2024-06-01',DATE '2027-06-01','active','DEMO-REGION-A','Synthetic renewable permit'),
('DEMO-LIC-002','DEMO-HOLDER-002','mineral_exploration',DATE '2023-02-01',DATE '2026-12-01','active','DEMO-REGION-B','Synthetic exploration permit'),
('DEMO-LIC-003','DEMO-HOLDER-003','electricity',DATE '2020-01-01',DATE '2025-12-31','expired','DEMO-REGION-A','Synthetic historical permit')
) v(ref,holder,sector,issued,expires,status,region,summary)
JOIN energy_demo.licence_holders h ON h.holder_ref=v.holder
ON CONFLICT(licence_ref) DO NOTHING;
INSERT INTO energy_demo.inspections(inspection_ref,licence_id,inspected_at,inspection_type,outcome,inspector_ref,finding_summary)
SELECT v.ref,l.licence_id,v.at_time,v.kind,v.outcome,'DEMO-INSPECTOR',v.summary
FROM (VALUES
('DEMO-INSP-001','DEMO-LIC-001',TIMESTAMPTZ '2026-08-15 09:00:00+00','routine','no_action','Synthetic documentary review'),
('DEMO-INSP-002','DEMO-LIC-002',TIMESTAMPTZ '2026-09-20 10:30:00+00','follow_up','follow_up_required','Synthetic corrective-action candidate'),
('DEMO-INSP-003','DEMO-LIC-003',TIMESTAMPTZ '2025-10-10 08:00:00+00','document_review','refer_for_review','Synthetic historical record')
) v(ref,lic,at_time,kind,outcome,summary) JOIN energy_demo.licences l ON l.licence_ref=v.lic
ON CONFLICT(inspection_ref) DO NOTHING;
INSERT INTO energy_demo.corrective_actions(action_ref,inspection_id,summary,status,due_date,owner_ref)
SELECT v.ref,i.inspection_id,v.summary,v.status,v.due,'DEMO-OWNER'
FROM (VALUES
('DEMO-ACT-001','DEMO-INSP-002','Review fictional documentation gap','open',DATE '2026-11-15'),
('DEMO-ACT-002','DEMO-INSP-003','Review legacy record provenance','in_progress',DATE '2026-10-01')
) v(ref,insp,summary,status,due) JOIN energy_demo.inspections i ON i.inspection_ref=v.insp
ON CONFLICT(action_ref) DO NOTHING;
