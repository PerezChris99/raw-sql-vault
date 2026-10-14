-- Purpose: operational queue, timeline and fee summaries.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_permit.v_application_queue AS
SELECT a.application_id,a.application_ref,t.type_code,t.type_name,t.issuing_office_code,
       a.applicant_ref,a.locality_code,a.status,a.submitted_at,a.created_at,a.updated_at,
       CASE WHEN a.status IN ('submitted','under_review','awaiting_documents')
            THEN now()-COALESCE(a.submitted_at,a.created_at) END AS open_age
FROM ug_permit.applications a
JOIN ug_permit.permit_types t USING(permit_type_id)
WHERE a.status NOT IN ('approved','rejected','withdrawn','expired');

CREATE OR REPLACE VIEW ug_permit.v_fee_summary AS
SELECT a.application_id,a.application_ref,
       COALESCE(SUM(CASE WHEN f.event_kind='assessed' THEN f.amount
                         WHEN f.event_kind IN ('waived','reversed','refunded') THEN -f.amount
                         WHEN f.event_kind='adjusted' THEN f.amount ELSE 0 END),0)::NUMERIC(14,2) AS net_assessed,
       COALESCE(SUM(CASE WHEN f.event_kind='payment_recorded' THEN f.amount
                         WHEN f.event_kind='refunded' THEN -f.amount ELSE 0 END),0)::NUMERIC(14,2) AS net_paid
FROM ug_permit.applications a
LEFT JOIN ug_permit.fee_events f USING(application_id)
GROUP BY a.application_id,a.application_ref;

CREATE OR REPLACE VIEW ug_permit.v_latest_application_event AS
SELECT DISTINCT ON (application_id) application_id,event_type,from_status,to_status,
       actor_ref,reason,occurred_at
FROM ug_permit.application_events
ORDER BY application_id,occurred_at DESC,event_id DESC;
