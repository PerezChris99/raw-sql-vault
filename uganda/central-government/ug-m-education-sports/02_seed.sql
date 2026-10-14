INSERT INTO education_demo.schools(school_code,school_name,locality_code,school_level) VALUES
('DEMO-SCH-001','Synthetic Hill Primary','DEMO-AREA-A','primary'),
('DEMO-SCH-002','Synthetic Market Secondary','DEMO-AREA-B','secondary'),
('DEMO-SCH-003','Synthetic Valley Technical School','DEMO-AREA-A','technical')
ON CONFLICT(school_code) DO NOTHING;
INSERT INTO education_demo.asset_catalog(asset_code,asset_name,category,unit_of_measure) VALUES
('DEMO-BOOK-MATH','Synthetic mathematics textbook','textbook','book'),
('DEMO-LAB-KIT','Synthetic general science kit','lab_kit','kit'),
('DEMO-SPORT-KIT','Synthetic sports equipment kit','sports_kit','kit')
ON CONFLICT(asset_code) DO NOTHING;
INSERT INTO education_demo.allocations(allocation_ref,school_id,asset_id,planned_quantity,dispatched_quantity,received_quantity,status,planned_dispatch_date,dispatch_reference,receipt_reference)
SELECT v.ref,s.school_id,a.asset_id,v.planned,v.dispatched,v.received,v.status,v.due,v.dispatch_ref,v.receipt_ref
FROM (VALUES
('DEMO-ALLOC-001','DEMO-SCH-001','DEMO-BOOK-MATH',500,500,500,'received',DATE '2026-09-30','DEMO-DN-001','DEMO-GRN-001'),
('DEMO-ALLOC-002','DEMO-SCH-002','DEMO-LAB-KIT',12,12,8,'disputed',DATE '2026-10-31','DEMO-DN-002','DEMO-GRN-002'),
('DEMO-ALLOC-003','DEMO-SCH-003','DEMO-SPORT-KIT',5,0,0,'planned',DATE '2026-12-01',NULL,NULL)
) v(ref,school_code,asset_code,planned,dispatched,received,status,due,dispatch_ref,receipt_ref)
JOIN education_demo.schools s ON s.school_code=v.school_code
JOIN education_demo.asset_catalog a ON a.asset_code=v.asset_code
ON CONFLICT(allocation_ref) DO NOTHING;