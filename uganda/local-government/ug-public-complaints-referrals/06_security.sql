-- Purpose: role groups for confidential complaint intake, triage and referral.
-- Engine: PostgreSQL 15+. Prerequisite: controlled schema administrator.
DO $roles$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_public_case_aggregate_reader') THEN CREATE ROLE ug_public_case_aggregate_reader NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_public_case_clerk') THEN CREATE ROLE ug_public_case_clerk NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_public_case_triage') THEN CREATE ROLE ug_public_case_triage NOLOGIN; END IF;
END;
$roles$;
REVOKE ALL ON SCHEMA ug_public_case FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_public_case TO ug_public_case_aggregate_reader,ug_public_case_clerk,ug_public_case_triage;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_public_case FROM PUBLIC;
GRANT SELECT ON ug_public_case.v_sla_summary TO ug_public_case_aggregate_reader;
GRANT SELECT ON ug_public_case.case_categories,ug_public_case.cases,ug_public_case.case_events,ug_public_case.referrals
TO ug_public_case_clerk,ug_public_case_triage;
GRANT EXECUTE ON FUNCTION ug_public_case.fn_transition_case(TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_public_case_triage;
GRANT EXECUTE ON FUNCTION ug_public_case.fn_create_referral(TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TEXT) TO ug_public_case_triage;
REVOKE ALL ON FUNCTION ug_public_case.fn_transition_case(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_public_case.fn_create_referral(TEXT,TEXT,TEXT,TEXT,TEXT,TIMESTAMPTZ,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_public_case FROM PUBLIC;
-- Keep SECURITY DEFINER functions trusted-owned, fix search_path, and deny runtime CREATE.
-- The aggregate role receives only the grouped SLA view, not identifiable case records.
