-- Purpose: defensive reporting, remediation owner and independent verifier role separation.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_cyber_reader') THEN CREATE ROLE ug_cyber_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_cyber_remediator') THEN CREATE ROLE ug_cyber_remediator NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_cyber_verifier') THEN CREATE ROLE ug_cyber_verifier NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_cyber FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_cyber TO ug_cyber_reader,ug_cyber_remediator,ug_cyber_verifier;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_cyber FROM PUBLIC;
GRANT SELECT ON ug_cyber.v_remediation_queue,ug_cyber.v_overdue_findings TO ug_cyber_reader;
GRANT SELECT ON ug_cyber.assets,ug_cyber.findings,ug_cyber.remediation_events TO ug_cyber_remediator;
GRANT SELECT ON ug_cyber.findings,ug_cyber.verification_results TO ug_cyber_verifier;
GRANT EXECUTE ON FUNCTION ug_cyber.fn_record_verification(TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_cyber_verifier;
REVOKE ALL ON FUNCTION ug_cyber.fn_record_verification(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_cyber FROM PUBLIC;
-- Keep exact hostnames, IPs, exploit details, credentials and scan artefacts in restricted security tooling.
