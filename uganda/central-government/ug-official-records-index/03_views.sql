-- Purpose: retention review, custody location and disposition queues.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_records.v_retention_review AS
SELECT r.record_ref,c.category_code,r.classification,r.current_custodian_office_id,r.retention_until,r.legal_hold,r.status
FROM ug_records.records r JOIN ug_records.record_categories c USING(category_id)
WHERE r.status<>'disposed' AND r.legal_hold=FALSE AND r.retention_until IS NOT NULL AND r.retention_until<=CURRENT_DATE;

CREATE OR REPLACE VIEW ug_records.v_disposition_queue AS
SELECT d.disposition_ref,r.record_ref,r.classification,r.retention_until,r.legal_hold,d.reason,d.status,d.requested_by_ref
FROM ug_records.disposition_requests d JOIN ug_records.records r USING(record_id)
WHERE d.status IN ('requested','approved') AND r.legal_hold=FALSE;

CREATE OR REPLACE VIEW ug_records.v_custody_register AS
SELECT r.record_ref,r.external_reference,r.classification,r.status,r.retention_until,r.legal_hold,
       o.office_ref AS custodian_office_ref,o.office_name AS custodian_office
FROM ug_records.records r JOIN ug_records.offices o ON o.office_id=r.current_custodian_office_id;
