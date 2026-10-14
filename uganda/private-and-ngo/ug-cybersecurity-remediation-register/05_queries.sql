-- Purpose: defensive asset inventory and remediation reporting.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Open remediation queue.
SELECT * FROM ug_cyber.v_remediation_queue ORDER BY severity DESC,remediation_due;
-- 02. Overdue remediation items.
SELECT * FROM ug_cyber.v_overdue_findings ORDER BY remediation_due,severity DESC;
-- 03. Latest verification result.
SELECT * FROM ug_cyber.v_verification_latest ORDER BY verified_at DESC;
-- 04. Critical assets with no recent inventory verification.
SELECT asset_ref,owner_unit_ref,criticality,last_verified_at
FROM ug_cyber.assets WHERE status='active' AND criticality='critical'
AND (last_verified_at IS NULL OR last_verified_at<CURRENT_TIMESTAMP-INTERVAL '90 days');
-- 05. Findings closed without a passing verification (should return zero).
SELECT f.finding_ref,f.status FROM ug_cyber.findings f
WHERE f.status IN ('verified','closed') AND NOT EXISTS(
 SELECT 1 FROM ug_cyber.verification_results v WHERE v.finding_id=f.finding_id AND v.result='pass');
