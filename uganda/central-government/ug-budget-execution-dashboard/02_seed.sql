-- Purpose: synthetic programme and budget execution fixture. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_budget_exec.programmes(programme_ref,office_ref,programme_name,fiscal_year,status)
VALUES('UGBUD-DEMO-001','SYN-OFFICE-01','Synthetic water point repair programme','2026/2027','approved')
ON CONFLICT(programme_ref) DO NOTHING;
INSERT INTO ug_budget_exec.appropriations(programme_id,version_no,approved_amount,approved_by_ref,evidence_ref,effective_on)
SELECT programme_id,1,100000000,'SYN-BUDGET-APPROVER','SYN-APPROPRIATION-001',DATE '2026-07-01'
FROM ug_budget_exec.programmes WHERE programme_ref='UGBUD-DEMO-001'
ON CONFLICT(programme_id,version_no) DO NOTHING;
INSERT INTO ug_budget_exec.releases(release_ref,programme_id,amount,treasury_reference,released_on,recorded_by_ref,evidence_ref)
SELECT 'UGREL-DEMO-001',programme_id,40000000,'SYN-TREASURY-RELEASE-001',DATE '2026-07-15','SYN-FINANCE-CLERK','SYN-RELEASE-EVIDENCE-001'
FROM ug_budget_exec.programmes WHERE programme_ref='UGBUD-DEMO-001'
ON CONFLICT(release_ref) DO NOTHING;
INSERT INTO ug_budget_exec.commitments(commitment_ref,programme_id,supplier_ref,amount,status,committed_on,approval_ref,recorded_by_ref)
SELECT 'UGCOM-DEMO-001',programme_id,'SYN-SUPPLIER-01',25000000,'open',DATE '2026-08-01','SYN-COMMITMENT-APPROVAL-001','SYN-FINANCE-CLERK'
FROM ug_budget_exec.programmes WHERE programme_ref='UGBUD-DEMO-001'
ON CONFLICT(commitment_ref) DO NOTHING;
INSERT INTO ug_budget_exec.service_outputs(output_ref,programme_id,reporting_period,output_metric,planned_quantity,achieved_quantity,unit_code,source_ref,quality_status)
SELECT 'SYN-OUTPUT-001',programme_id,DATE '2026-09-01','water_points_repaired',20,7,'count','SYN-MONITORING-REPORT-001','verified'
FROM ug_budget_exec.programmes WHERE programme_ref='UGBUD-DEMO-001'
ON CONFLICT(output_ref) DO NOTHING;
