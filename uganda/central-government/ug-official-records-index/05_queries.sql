-- Purpose: records retention, custody and access oversight queries.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Current custody register.
SELECT * FROM ug_records.v_custody_register ORDER BY custodian_office_ref,record_ref;
-- 02. Records due for retention review; not an automatic deletion list.
SELECT * FROM ug_records.v_retention_review ORDER BY retention_until,record_ref;
-- 03. Disposition requests blocked by legal hold (should remain unexecuted).
SELECT d.disposition_ref,r.record_ref,r.legal_hold,d.status
FROM ug_records.disposition_requests d JOIN ug_records.records r USING(record_id)
WHERE r.legal_hold=TRUE AND d.status<>'executed';
-- 04. Custody chain.
SELECT r.record_ref,e.transferred_at,e.from_office_id,e.to_office_id,e.transferred_by_ref,e.accepted_by_ref,e.evidence_ref
FROM ug_records.custody_events e JOIN ug_records.records r USING(record_id)
ORDER BY r.record_ref,e.transferred_at,e.custody_event_id;
-- 05. Record accesses by action and actor.
SELECT actor_ref,action,COUNT(*) AS event_count,MIN(occurred_at) AS first_seen,MAX(occurred_at) AS last_seen
FROM ug_records.access_events GROUP BY actor_ref,action ORDER BY actor_ref,action;
-- 06. Missing or malformed object checksums (should return zero).
SELECT record_ref FROM ug_records.records WHERE sha256_hex !~ '^[0-9a-f]{64}$';
