INSERT INTO coop_demo.cooperatives(cooperative_code,cooperative_label,locality_code) VALUES
('DEMO-COOP-A','Synthetic Coffee Cooperative A','DEMO-AREA-A'),
('DEMO-COOP-B','Synthetic Grain Cooperative B','DEMO-AREA-B')
ON CONFLICT(cooperative_code) DO NOTHING;
INSERT INTO coop_demo.members(cooperative_id,member_ref,joined_on)
SELECT c.cooperative_id,v.member_ref,v.joined_on FROM (VALUES
('DEMO-COOP-A','DEMO-MEMBER-A1',DATE '2022-01-10'),
('DEMO-COOP-A','DEMO-MEMBER-A2',DATE '2023-05-15'),
('DEMO-COOP-B','DEMO-MEMBER-B1',DATE '2021-11-21')
) v(coop_code,member_ref,joined_on) JOIN coop_demo.cooperatives c ON c.cooperative_code=v.coop_code
ON CONFLICT(member_ref) DO NOTHING;
INSERT INTO coop_demo.produce_catalog(produce_code,produce_label) VALUES
('DEMO-COFFEE','Synthetic coffee beans'),('DEMO-MAIZE','Synthetic maize'),('DEMO-BEANS','Synthetic beans')
ON CONFLICT(produce_code) DO NOTHING;
INSERT INTO coop_demo.deliveries(delivery_ref,member_id,produce_id,delivery_date,gross_kg,accepted_kg,rejected_kg,price_per_kg_ugx,grade_ref,status,approved_by_ref,approved_at)
SELECT v.ref,m.member_id,p.produce_id,v.day,v.gross,v.accepted,v.rejected,v.price,v.grade,v.status,
 CASE WHEN v.status='approved' THEN 'synthetic-reviewer' ELSE NULL END,
 CASE WHEN v.status='approved' THEN now() ELSE NULL END
FROM (VALUES
('DEMO-DEL-001','DEMO-MEMBER-A1','DEMO-COFFEE',DATE '2026-09-10',100::numeric,95::numeric,5::numeric,8500::numeric,'DEMO-GRADE-A','approved'),
('DEMO-DEL-002','DEMO-MEMBER-A2','DEMO-COFFEE',DATE '2026-10-01',80::numeric,70::numeric,10::numeric,8000::numeric,'DEMO-GRADE-B','quality_checked'),
('DEMO-DEL-003','DEMO-MEMBER-B1','DEMO-MAIZE',DATE '2026-10-05',200::numeric,190::numeric,10::numeric,1300::numeric,'DEMO-GRADE-M','received')
) v(ref,member_ref,produce_code,day,gross,accepted,rejected,price,grade,status)
JOIN coop_demo.members m ON m.member_ref=v.member_ref JOIN coop_demo.produce_catalog p ON p.produce_code=v.produce_code
ON CONFLICT(delivery_ref) DO NOTHING;
SELECT coop_demo.fn_record_payment('DEMO-PAY-001','DEMO-DEL-001',300000,'bank_transfer','DEMO-BANK-REF-001','SEED-PAY-001');