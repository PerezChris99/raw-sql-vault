-- Purpose: safe read examples for permit workflow reporting.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql, 02_seed.sql and 03_views.sql.
-- Use bind parameters in applications; literal demo references are for learning only.

-- 01. Work queue by issuing office and oldest open case.
SELECT issuing_office_code,application_ref,type_name,status,submitted_at,open_age
FROM ug_permit.v_application_queue
ORDER BY issuing_office_code,submitted_at NULLS FIRST,application_id;

-- 02. Counts and average age by status.
SELECT status,COUNT(*) AS applications,
       AVG(EXTRACT(EPOCH FROM open_age)/3600.0) AS average_open_hours
FROM ug_permit.v_application_queue GROUP BY status ORDER BY status;

-- 03. Full auditable event timeline for a synthetic application.
SELECT e.occurred_at,e.event_type,e.from_status,e.to_status,e.actor_ref,e.reason,e.evidence_ref
FROM ug_permit.application_events e
JOIN ug_permit.applications a USING(application_id)
WHERE a.application_ref='UGP-DEMO-0001'
ORDER BY e.occurred_at,e.event_id;

-- 04. Documents by application, newest first; content is stored elsewhere.
SELECT a.application_ref,d.document_type,d.object_ref,d.sha256_hex,d.classification,d.received_at
FROM ug_permit.application_documents d
JOIN ug_permit.applications a USING(application_id)
ORDER BY a.application_ref,d.received_at DESC;

-- 05. Fee assessed and paid summary; finance must reconcile source references independently.
SELECT application_ref,net_assessed,net_paid,net_assessed-net_paid AS indicative_balance
FROM ug_permit.v_fee_summary ORDER BY application_ref;

-- 06. Application types with no submissions in the current dataset.
SELECT t.type_code,t.type_name
FROM ug_permit.permit_types t
LEFT JOIN ug_permit.applications a USING(permit_type_id)
GROUP BY t.permit_type_id,t.type_code,t.type_name
HAVING COUNT(a.application_id)=0 ORDER BY t.type_code;

-- 07. Decisions missing evidence reference (should return zero).
SELECT a.application_ref,e.event_type,e.actor_ref,e.reason
FROM ug_permit.application_events e JOIN ug_permit.applications a USING(application_id)
WHERE e.event_type IN ('approved','rejected') AND e.evidence_ref IS NULL;

-- 08. Applications waiting on documents.
SELECT application_ref,type_name,issuing_office_code,open_age
FROM ug_permit.v_application_queue WHERE status='awaiting_documents'
ORDER BY open_age DESC NULLS LAST;

-- 09. Current application/document counts by locality reference.
SELECT locality_code,COUNT(*) AS application_count,COUNT(d.document_id) AS document_count
FROM ug_permit.applications a
LEFT JOIN ug_permit.application_documents d USING(application_id)
GROUP BY locality_code ORDER BY application_count DESC,locality_code;

-- 10. Source event counts for audit review.
SELECT event_type,COUNT(*) AS event_count,MIN(occurred_at) AS first_seen,MAX(occurred_at) AS last_seen
FROM ug_permit.application_events GROUP BY event_type ORDER BY event_type;
