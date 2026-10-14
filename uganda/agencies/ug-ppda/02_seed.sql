INSERT INTO ppda_demo.procurement_plans(plan_ref,entity_ref,procurement_title,procurement_method,estimated_value_ugx,fiscal_year_start,status) VALUES
('DEMO-PLAN-001','DEMO-ENTITY-A','Synthetic school furniture procurement','open',120000000,2026,'approved'),
('DEMO-PLAN-002','DEMO-ENTITY-B','Synthetic drainage repair contract','request_for_quotation',45000000,2026,'approved'),
('DEMO-PLAN-003','DEMO-ENTITY-A','Synthetic ICT maintenance framework','framework',80000000,2026,'draft')
ON CONFLICT(plan_ref) DO NOTHING;
INSERT INTO ppda_demo.tenders(tender_ref,plan_id,advertised_at,closing_at,tender_status,source_notice_ref)
SELECT v.ref,p.plan_id,v.advertised,v.closing,v.status,v.notice
FROM (VALUES
('DEMO-TENDER-001','DEMO-PLAN-001',DATE '2026-07-15',DATE '2026-08-15','closed','DEMO-NOTICE-001'),
('DEMO-TENDER-002','DEMO-PLAN-002',DATE '2026-09-01',DATE '2026-09-15','evaluation_recorded','DEMO-NOTICE-002')
) v(ref,plan_ref,advertised,closing,status,notice) JOIN ppda_demo.procurement_plans p ON p.plan_ref=v.plan_ref
ON CONFLICT(tender_ref) DO NOTHING;
INSERT INTO ppda_demo.contracts(contract_ref,tender_id,supplier_ref,contract_value_ugx,start_date,end_date,contract_status)
SELECT v.ref,t.tender_id,v.supplier,v.value_ugx,v.start_date,v.end_date,'active'
FROM (VALUES
('DEMO-CONTRACT-001','DEMO-TENDER-001','DEMO-SUPPLIER-A',110000000::numeric,DATE '2026-10-01',DATE '2027-03-31')
) v(ref,tender_ref,supplier,value_ugx,start_date,end_date) JOIN ppda_demo.tenders t ON t.tender_ref=v.tender_ref
ON CONFLICT(contract_ref) DO NOTHING;
INSERT INTO ppda_demo.contract_milestones(milestone_ref,contract_id,milestone_title,due_date,planned_value_ugx,status)
SELECT v.ref,c.contract_id,v.title,v.due,v.value_ugx,v.status
FROM (VALUES
('DEMO-MILESTONE-001','DEMO-CONTRACT-001','Synthetic delivery of first lot',DATE '2026-11-15',40000000::numeric,'planned'),
('DEMO-MILESTONE-002','DEMO-CONTRACT-001','Synthetic installation and handover',DATE '2027-02-15',70000000::numeric,'submitted')
) v(ref,contract_ref,title,due,value_ugx,status) JOIN ppda_demo.contracts c ON c.contract_ref=v.contract_ref
ON CONFLICT(milestone_ref) DO NOTHING;