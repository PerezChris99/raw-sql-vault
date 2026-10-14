-- Purpose: confidential triage queue, SLA exposure and referral status.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_public_case.v_triage_queue AS
SELECT c.case_id,c.case_ref,cat.category_code,cat.category_name,c.severity,c.status,c.received_at,c.due_at,
       c.assigned_team_ref,c.locality_ref,c.confidentiality,
       (c.due_at<now()) AS overdue
FROM ug_public_case.cases c JOIN ug_public_case.case_categories cat USING(category_id)
WHERE c.status NOT IN ('closed','withdrawn','resolved');

CREATE OR REPLACE VIEW ug_public_case.v_referral_queue AS
SELECT r.referral_ref,c.case_ref,r.receiving_office_ref,r.status,r.sent_at,r.due_at,
       (r.due_at<now() AND r.status NOT IN ('response_received','closed','declined')) AS overdue
FROM ug_public_case.referrals r JOIN ug_public_case.cases c USING(case_id)
WHERE r.status NOT IN ('closed','declined');

CREATE OR REPLACE VIEW ug_public_case.v_sla_summary AS
SELECT cat.category_code,cat.category_name,c.severity,c.status,COUNT(*) AS case_count,
       COUNT(*) FILTER (WHERE c.due_at<now() AND c.status NOT IN ('closed','withdrawn','resolved')) AS overdue_count
FROM ug_public_case.cases c JOIN ug_public_case.case_categories cat USING(category_id)
GROUP BY cat.category_code,cat.category_name,c.severity,c.status;
