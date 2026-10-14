-- Purpose: deterministic synthetic public works sample records.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_works_contract.projects(project_ref,project_name,sponsor_office_ref,locality_ref,project_status,approved_on,planned_start,planned_end)
VALUES ('UGW-DEMO-001','Synthetic community access improvement','SYN-OFFICE-01','SYN-LOCALITY-01','active',DATE '2026-01-10',DATE '2026-02-01',DATE '2026-12-31')
ON CONFLICT(project_ref) DO NOTHING;

INSERT INTO ug_works_contract.contracts(contract_ref,project_id,supplier_ref,signed_on,planned_completion,contract_value,status)
SELECT 'UGWC-DEMO-001',project_id,'SYN-SUPPLIER-01',DATE '2026-01-15',DATE '2026-11-30',120000000,'in_progress'
FROM ug_works_contract.projects WHERE project_ref='UGW-DEMO-001'
ON CONFLICT(contract_ref) DO NOTHING;

INSERT INTO ug_works_contract.budget_versions(contract_id,version_no,approved_amount,approved_by_ref,approval_evidence_ref,effective_on)
SELECT contract_id,1,120000000,'SYN-APPROVER-01','SYN-BUDGET-APPROVAL-001',DATE '2026-01-15'
FROM ug_works_contract.contracts WHERE contract_ref='UGWC-DEMO-001'
ON CONFLICT(contract_id,version_no) DO NOTHING;

INSERT INTO ug_works_contract.milestones(contract_id,milestone_code,milestone_name,planned_due_on,planned_value,status)
SELECT contract_id,v.code,v.name,v.due_on,v.amount,'planned'
FROM ug_works_contract.contracts c
CROSS JOIN (VALUES
 ('MOB','Mobilisation and site handover',DATE '2026-03-01',12000000::NUMERIC),
 ('MID','Midpoint works inspection',DATE '2026-07-01',48000000::NUMERIC),
 ('FIN','Final inspection and handover',DATE '2026-11-30',60000000::NUMERIC)
) v(code,name,due_on,amount)
WHERE c.contract_ref='UGWC-DEMO-001'
ON CONFLICT(contract_id,milestone_code) DO NOTHING;
