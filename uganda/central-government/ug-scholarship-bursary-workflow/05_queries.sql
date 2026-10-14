-- Purpose: reporting examples for scholarship/bursary administration.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seeds and views.
-- All sample references are synthetic; bind parameters in applications.

-- 01. Open application queue.
SELECT application_ref,programme_code,academic_year,student_ref,school_ref,status,submitted_at
FROM ug_bursary.v_application_queue ORDER BY submitted_at,application_ref;

-- 02. Awards and remaining disbursement balance.
SELECT application_ref,student_ref,school_ref,status,award_amount,total_disbursed,remaining_award_balance,currency_code
FROM ug_bursary.v_award_disbursement_summary ORDER BY application_ref;

-- 03. Appeals waiting for review.
SELECT * FROM ug_bursary.v_appeal_queue ORDER BY filed_at,appeal_ref;

-- 04. Decisions missing evidence (should return zero).
SELECT application_ref,status,decision_at,decision_evidence_ref
FROM ug_bursary.applications
WHERE status IN ('approved','rejected') AND (decision_evidence_ref IS NULL OR decision_reason IS NULL);

-- 05. Applications with no document metadata.
SELECT a.application_ref,a.status
FROM ug_bursary.applications a
LEFT JOIN ug_bursary.document_metadata d USING(application_id)
GROUP BY a.application_id,a.application_ref,a.status
HAVING COUNT(d.document_id)=0 ORDER BY a.application_ref;

-- 06. Programme-level disbursement and approved-application counts without multiplying award totals.
SELECT p.programme_code,p.academic_year,
       COALESCE(SUM(d.amount),0)::NUMERIC(14,2) AS total_disbursed,
       COUNT(DISTINCT a.application_id) FILTER (WHERE a.status='approved') AS approved_application_count
FROM ug_bursary.programmes p
LEFT JOIN ug_bursary.applications a USING(programme_id)
LEFT JOIN ug_bursary.disbursements d USING(application_id)
GROUP BY p.programme_id,p.programme_code,p.academic_year ORDER BY p.programme_code;

-- 07. Duplicate students per programme (unique constraint should prevent these).
SELECT programme_id,student_ref,COUNT(*) FROM ug_bursary.applications
GROUP BY programme_id,student_ref HAVING COUNT(*)>1;

-- 08. Appeal outcome counts for programme accountability.
SELECT p.programme_code,ap.outcome,COUNT(*) AS appeals
FROM ug_bursary.appeals ap JOIN ug_bursary.applications a USING(application_id)
JOIN ug_bursary.programmes p USING(programme_id)
GROUP BY p.programme_code,ap.outcome ORDER BY p.programme_code,ap.outcome;

-- 09. Disbursement records without a source payment reference (should return zero).
SELECT disbursement_ref FROM ug_bursary.disbursements
WHERE external_payment_ref IS NULL OR length(btrim(external_payment_ref))=0;

-- 10. Application event timeline.
SELECT e.occurred_at,e.event_type,e.from_status,e.to_status,e.actor_ref,e.reason,e.evidence_reference
FROM ug_bursary.application_events e JOIN ug_bursary.applications a USING(application_id)
WHERE a.application_ref='UGB-DEMO-0001' ORDER BY e.occurred_at,e.event_id;
