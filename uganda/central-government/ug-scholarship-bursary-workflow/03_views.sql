-- Purpose: application queue, award/disbursement balance and appeal review queue.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_bursary.v_application_queue AS
SELECT a.application_id,a.application_ref,p.programme_code,p.programme_name,p.academic_year,
       a.student_ref,a.school_ref,a.status,a.submitted_at,a.decision_at,
       a.decision_reason,p.award_amount,p.currency_code
FROM ug_bursary.applications a JOIN ug_bursary.programmes p USING(programme_id)
WHERE a.status IN ('submitted','under_review','awaiting_documents');

CREATE OR REPLACE VIEW ug_bursary.v_award_disbursement_summary AS
SELECT a.application_ref,a.student_ref,a.school_ref,a.status,p.award_amount,p.currency_code,
       COALESCE(SUM(d.amount),0)::NUMERIC(14,2) AS total_disbursed,
       (p.award_amount-COALESCE(SUM(d.amount),0))::NUMERIC(14,2) AS remaining_award_balance
FROM ug_bursary.applications a
JOIN ug_bursary.programmes p USING(programme_id)
LEFT JOIN ug_bursary.disbursements d USING(application_id)
GROUP BY a.application_id,a.application_ref,a.student_ref,a.school_ref,a.status,p.award_amount,p.currency_code;

CREATE OR REPLACE VIEW ug_bursary.v_appeal_queue AS
SELECT ap.appeal_ref,a.application_ref,a.student_ref,ap.status,ap.reason,ap.filed_at,ap.filed_by_ref
FROM ug_bursary.appeals ap JOIN ug_bursary.applications a USING(application_id)
WHERE ap.status IN ('submitted','under_review');
