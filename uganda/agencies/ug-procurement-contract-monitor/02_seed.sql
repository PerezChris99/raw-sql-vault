-- Purpose: deterministic synthetic procurement lifecycle fixtures.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_procurement.procurement_plans(plan_ref,procuring_entity_ref,fiscal_year,title,estimated_value,status,approved_by_ref,approved_at,approval_evidence_ref)
VALUES('UGPP-DEMO-001','SYN-ENTITY-01','2026/2027','Synthetic district water point repair services',50000000,'published','SYN-APPROVER-01',TIMESTAMPTZ '2026-01-05 09:00:00+03','SYN-PLAN-APPROVAL-001')
ON CONFLICT(plan_ref) DO NOTHING;

INSERT INTO ug_procurement.notices(notice_ref,plan_id,notice_title,procurement_method,published_at,closing_at,status,public_notice_url)
SELECT 'UGPN-DEMO-001',plan_id,'Synthetic repair services notice','open_competitive',
 TIMESTAMPTZ '2026-02-01 09:00:00+03',TIMESTAMPTZ '2026-03-01 17:00:00+03','closed','https://example.invalid/synthetic-notice'
FROM ug_procurement.procurement_plans WHERE plan_ref='UGPP-DEMO-001'
ON CONFLICT(notice_ref) DO NOTHING;

INSERT INTO ug_procurement.awards(award_ref,notice_id,supplier_ref,awarded_amount,currency_code,decision_at,decision_by_ref,decision_evidence_ref,disclosure_status,contract_ref)
SELECT 'UGPA-DEMO-001',notice_id,'SYN-SUPPLIER-01',42000000,'UGX',
 TIMESTAMPTZ '2026-03-15 10:00:00+03','SYN-COMMITTEE-01','SYN-AWARD-RECORD-001','publishable','SYN-CONTRACT-001'
FROM ug_procurement.notices WHERE notice_ref='UGPN-DEMO-001'
ON CONFLICT(award_ref) DO NOTHING;

INSERT INTO ug_procurement.contract_deliverables(award_id,deliverable_code,description,due_on,acceptance_criteria_ref)
SELECT award_id,'DEL-01','Synthetic site inspection report',DATE '2026-07-30','SYN-ACCEPTANCE-CRITERIA-01'
FROM ug_procurement.awards WHERE award_ref='UGPA-DEMO-001'
ON CONFLICT(award_id,deliverable_code) DO NOTHING;
