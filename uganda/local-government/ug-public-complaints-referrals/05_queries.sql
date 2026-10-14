-- Purpose: confidential case-management reporting.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seeds and views.
-- Do not expose complainant references or detailed case records in public dashboards.

-- 01. Active triage queue.
SELECT case_ref,category_code,severity,status,received_at,due_at,assigned_team_ref,overdue
FROM ug_public_case.v_triage_queue ORDER BY overdue DESC,severity, due_at;

-- 02. Referral response queue.
SELECT referral_ref,case_ref,receiving_office_ref,status,sent_at,due_at,overdue
FROM ug_public_case.v_referral_queue ORDER BY overdue DESC,due_at;

-- 03. SLA counts by category, severity and status.
SELECT * FROM ug_public_case.v_sla_summary ORDER BY category_code,severity,status;

-- 04. Case event history for an authorised case reference.
SELECT e.occurred_at,e.event_type,e.from_status,e.to_status,e.actor_ref,e.reason,e.evidence_reference
FROM ug_public_case.case_events e JOIN ug_public_case.cases c USING(case_id)
WHERE c.case_ref='UGCASE-DEMO-0001' ORDER BY e.occurred_at,e.event_id;

-- 05. Referrals with no response by due date.
SELECT referral_ref,case_ref,receiving_office_ref,due_at
FROM ug_public_case.v_referral_queue WHERE overdue ORDER BY due_at;

-- 06. Cases by intake channel and month.
SELECT date_trunc('month',received_at)::date AS intake_month,channel,COUNT(*) AS case_count
FROM ug_public_case.cases GROUP BY date_trunc('month',received_at)::date,channel
ORDER BY intake_month,channel;

-- 07. Cases missing assignment while status requires ownership.
SELECT case_ref,status FROM ug_public_case.cases
WHERE status IN ('assigned','awaiting_response') AND assigned_team_ref IS NULL;

-- 08. Referrals missing evidence references (should return zero).
SELECT referral_ref FROM ug_public_case.referrals
WHERE source_evidence_ref IS NULL OR length(btrim(source_evidence_ref))=0;

-- 09. Cases near SLA deadline (next 24 hours).
SELECT case_ref,category_code,severity,status,due_at
FROM ug_public_case.v_triage_queue WHERE due_at BETWEEN now() AND now()+INTERVAL '24 hours'
ORDER BY due_at;

-- 10. Resolution time distribution for closed cases.
SELECT cat.category_code,percentile_cont(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (c.closed_at-c.received_at))/3600.0) AS median_hours_to_close,
       COUNT(*) AS closed_cases
FROM ug_public_case.cases c JOIN ug_public_case.case_categories cat USING(category_id)
WHERE c.status='closed' GROUP BY cat.category_code ORDER BY cat.category_code;
