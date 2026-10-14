-- Fictional references only; safe re-run.
INSERT INTO tourism_demo.establishments(establishment_ref,category,locality_code,display_label) VALUES
('DEMO-EST-001','accommodation','DEMO-AREA-A','Synthetic Lakeside Lodge'),
('DEMO-EST-002','tour_operator','DEMO-AREA-B','Synthetic Horizon Operator'),
('DEMO-EST-003','heritage_site','DEMO-AREA-C','Synthetic Heritage Centre')
ON CONFLICT(establishment_ref) DO NOTHING;
INSERT INTO tourism_demo.permits(permit_ref,establishment_id,permit_type,issued_on,expires_on,status,source_ref)
SELECT v.ref,e.establishment_id,v.typ,v.issued,v.expires,v.status,'DEMO-DOC'
FROM (VALUES
('DEMO-PERMIT-001','DEMO-EST-001','operating',DATE '2024-05-01',DATE '2027-05-01','active'),
('DEMO-PERMIT-002','DEMO-EST-002','registration',DATE '2023-01-10',DATE '2026-11-01','active'),
('DEMO-PERMIT-003','DEMO-EST-003','activity',DATE '2021-03-01',DATE '2025-03-01','expired')
) v(ref,est,typ,issued,expires,status) JOIN tourism_demo.establishments e ON e.establishment_ref=v.est
ON CONFLICT(permit_ref) DO NOTHING;
INSERT INTO tourism_demo.inspections(inspection_ref,establishment_id,inspected_at,inspection_type,outcome,inspector_ref,summary)
SELECT v.ref,e.establishment_id,v.at_time,v.typ,v.outcome,'DEMO-INSPECTOR',v.summary
FROM (VALUES
('DEMO-INSP-001','DEMO-EST-001',TIMESTAMPTZ '2026-09-01 09:00+00','routine','acceptable','Synthetic routine review'),
('DEMO-INSP-002','DEMO-EST-002',TIMESTAMPTZ '2026-10-02 10:00+00','follow_up','follow_up_required','Synthetic document correction requested'),
('DEMO-INSP-003','DEMO-EST-003',TIMESTAMPTZ '2026-10-05 08:00+00','document_review','referred','Synthetic historical record needs review')
) v(ref,est,at_time,typ,outcome,summary) JOIN tourism_demo.establishments e ON e.establishment_ref=v.est
ON CONFLICT(inspection_ref) DO NOTHING;
INSERT INTO tourism_demo.actions(action_ref,inspection_id,summary,owner_ref,due_date,status)
SELECT v.ref,i.inspection_id,v.summary,'DEMO-OWNER',v.due,v.status FROM (VALUES
('DEMO-ACT-001','DEMO-INSP-002','Review fictional supporting document',DATE '2026-11-10','open'),
('DEMO-ACT-002','DEMO-INSP-003','Confirm synthetic legacy reference',DATE '2026-10-15','in_progress')
) v(ref,insp,summary,due,status) JOIN tourism_demo.inspections i ON i.inspection_ref=v.insp ON CONFLICT(action_ref) DO NOTHING;