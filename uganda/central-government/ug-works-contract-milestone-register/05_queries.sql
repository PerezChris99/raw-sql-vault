-- Purpose: oversight queries for project delivery, budget control and certificate review.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seeds and views.
-- 01. Latest budget and payment position by contract.
SELECT * FROM ug_works_contract.v_contract_budget_summary ORDER BY contract_ref;
-- 02. Overdue milestones requiring owner follow-up.
SELECT * FROM ug_works_contract.v_overdue_milestones ORDER BY planned_due_on,project_ref;
-- 03. Certificates awaiting review.
SELECT * FROM ug_works_contract.v_certificate_review_queue ORDER BY submitted_at,certificate_ref;
-- 04. Budget versions and approval evidence.
SELECT c.contract_ref,b.version_no,b.approved_amount,b.approved_by_ref,b.approval_evidence_ref,b.effective_on
FROM ug_works_contract.budget_versions b JOIN ug_works_contract.contracts c USING(contract_id)
ORDER BY c.contract_ref,b.version_no;
-- 05. Variance between contract ceiling and accepted/paid certificates.
SELECT contract_ref,contract_value,latest_approved_budget,approved_certificates,
       LEAST(contract_value,latest_approved_budget)-approved_certificates AS uncommitted_certificate_balance
FROM ug_works_contract.v_contract_budget_summary ORDER BY contract_ref;
-- 06. Milestone value totals must be reviewed against signed contract schedules.
SELECT c.contract_ref,c.contract_value,SUM(m.planned_value) AS milestone_plan_total,
       SUM(m.planned_value)-c.contract_value AS plan_variance
FROM ug_works_contract.contracts c JOIN ug_works_contract.milestones m USING(contract_id)
GROUP BY c.contract_id,c.contract_ref,c.contract_value
HAVING SUM(m.planned_value)<>c.contract_value;
-- 07. Paid certificates without a payment reference (should return zero).
SELECT certificate_ref FROM ug_works_contract.certificates
WHERE status='paid' AND (payment_ref IS NULL OR paid_at IS NULL);
-- 08. Event history for a certificate.
SELECT * FROM ug_works_contract.events WHERE entity_type='certificate' AND entity_ref='UGCERT-DEMO-001'
ORDER BY occurred_at,event_id;
