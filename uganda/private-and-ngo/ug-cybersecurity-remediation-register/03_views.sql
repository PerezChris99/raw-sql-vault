-- Purpose: remediation queue, overdue high-risk findings and verification status.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_cyber.v_remediation_queue AS
SELECT f.finding_ref,a.asset_ref,a.owner_unit_ref,a.environment,a.criticality AS asset_criticality,
 f.category,f.severity,f.summary_redacted,f.remediation_due,f.status,f.owner_ref
FROM ug_cyber.findings f JOIN ug_cyber.assets a USING(asset_id)
WHERE f.status IN ('open','in_progress','accepted_risk');

CREATE OR REPLACE VIEW ug_cyber.v_overdue_findings AS
SELECT * FROM ug_cyber.v_remediation_queue
WHERE remediation_due<CURRENT_DATE AND status<>'accepted_risk';

CREATE OR REPLACE VIEW ug_cyber.v_verification_latest AS
SELECT f.finding_ref,v.verifier_ref,v.verified_at,v.result,v.evidence_ref,v.notes_redacted
FROM ug_cyber.verification_results v JOIN ug_cyber.findings f USING(finding_id)
WHERE NOT EXISTS(SELECT 1 FROM ug_cyber.verification_results newer
 WHERE newer.finding_id=v.finding_id AND (newer.verified_at>v.verified_at OR (newer.verified_at=v.verified_at AND newer.verification_id>v.verification_id)));
