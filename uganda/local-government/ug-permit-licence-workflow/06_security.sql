-- Purpose: least-privilege role groups for the permit workflow.
-- Engine: PostgreSQL 15+. Prerequisite: run as a controlled schema administrator.
DO $roles$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_permit_reader') THEN CREATE ROLE ug_permit_reader NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_permit_clerk') THEN CREATE ROLE ug_permit_clerk NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_permit_decider') THEN CREATE ROLE ug_permit_decider NOLOGIN; END IF;
END;
$roles$;
REVOKE ALL ON SCHEMA ug_permit FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_permit TO ug_permit_reader,ug_permit_clerk,ug_permit_decider;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_permit FROM PUBLIC;
GRANT SELECT ON ug_permit.permit_types,ug_permit.v_application_queue,ug_permit.v_fee_summary,
                ug_permit.v_latest_application_event TO ug_permit_reader;
GRANT SELECT ON ug_permit.applications,ug_permit.application_events,ug_permit.application_documents
TO ug_permit_clerk,ug_permit_decider;
GRANT SELECT ON ug_permit.fee_events TO ug_permit_clerk;
GRANT INSERT ON ug_permit.application_documents TO ug_permit_clerk;
GRANT INSERT ON ug_permit.fee_events TO ug_permit_clerk;
GRANT EXECUTE ON FUNCTION ug_permit.fn_record_document(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_permit_clerk;
GRANT EXECUTE ON FUNCTION ug_permit.fn_transition_application(TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_permit_clerk,ug_permit_decider;
REVOKE ALL ON FUNCTION ug_permit.fn_transition_application(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_permit.fn_record_document(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_permit FROM PUBLIC;
-- Provision real user memberships separately. Runtime identities must not own the schema.
-- A production decision role should be granted transition execution only through an approved
-- deployment-specific grant strategy; this demo function still validates state and evidence.
