-- Purpose: inspect remediation queue and verification history access.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_cyber.findings;
ANALYZE ug_cyber.verification_results;
EXPLAIN (COSTS, VERBOSE)
SELECT finding_ref,severity,remediation_due FROM ug_cyber.findings WHERE status IN ('open','in_progress') ORDER BY remediation_due;
EXPLAIN (COSTS, VERBOSE)
SELECT finding_id,verified_at,result FROM ug_cyber.verification_results WHERE finding_id=1 ORDER BY verified_at DESC;
