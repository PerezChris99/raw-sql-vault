-- Purpose: contract budget, overdue milestones and certificate review queues.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_works_contract.v_contract_budget_summary AS
SELECT c.contract_ref,c.status,c.contract_value,
       COALESCE((SELECT b.approved_amount FROM ug_works_contract.budget_versions b
                 WHERE b.contract_id=c.contract_id ORDER BY b.version_no DESC LIMIT 1),0) AS latest_approved_budget,
       COALESCE((SELECT SUM(cert.submitted_amount) FROM ug_works_contract.certificates cert
                 JOIN ug_works_contract.milestones m USING(milestone_id)
                 WHERE m.contract_id=c.contract_id AND cert.status IN ('approved','paid')),0) AS approved_certificates,
       COALESCE((SELECT SUM(cert.submitted_amount) FROM ug_works_contract.certificates cert
                 JOIN ug_works_contract.milestones m USING(milestone_id)
                 WHERE m.contract_id=c.contract_id AND cert.status='paid'),0) AS paid_certificates
FROM ug_works_contract.contracts c;

CREATE OR REPLACE VIEW ug_works_contract.v_overdue_milestones AS
SELECT p.project_ref,p.project_name,c.contract_ref,m.milestone_code,m.milestone_name,m.planned_due_on,m.status
FROM ug_works_contract.milestones m
JOIN ug_works_contract.contracts c USING(contract_id)
JOIN ug_works_contract.projects p USING(project_id)
WHERE m.status NOT IN ('accepted','waived') AND m.planned_due_on<CURRENT_DATE;

CREATE OR REPLACE VIEW ug_works_contract.v_certificate_review_queue AS
SELECT cert.certificate_ref,c.contract_ref,m.milestone_code,m.milestone_name,
       cert.submitted_amount,cert.submitted_by_ref,cert.submitted_at,cert.status
FROM ug_works_contract.certificates cert
JOIN ug_works_contract.milestones m USING(milestone_id)
JOIN ug_works_contract.contracts c USING(contract_id)
WHERE cert.status IN ('submitted','under_review');
