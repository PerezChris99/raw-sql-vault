-- Purpose: separate aggregate programme reporting, delivery clerks and referral case workers.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_aid_aggregate_reader') THEN CREATE ROLE ug_aid_aggregate_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_aid_delivery_clerk') THEN CREATE ROLE ug_aid_delivery_clerk NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_aid_case_worker') THEN CREATE ROLE ug_aid_case_worker NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_aid FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_aid TO ug_aid_aggregate_reader,ug_aid_delivery_clerk,ug_aid_case_worker;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_aid FROM PUBLIC;
GRANT SELECT ON ug_aid.programmes,ug_aid.v_delivery_reconciliation TO ug_aid_aggregate_reader;
GRANT SELECT ON ug_aid.authorisations,ug_aid.recipients,ug_aid.deliveries TO ug_aid_delivery_clerk;
GRANT EXECUTE ON FUNCTION ug_aid.fn_record_delivery(TEXT,TEXT,TEXT,NUMERIC,TEXT,TIMESTAMPTZ,TEXT,TEXT,TEXT,TEXT) TO ug_aid_delivery_clerk;
GRANT SELECT ON ug_aid.referrals,ug_aid.audit_events TO ug_aid_case_worker;
REVOKE ALL ON FUNCTION ug_aid.fn_record_delivery(TEXT,TEXT,TEXT,NUMERIC,TEXT,TIMESTAMPTZ,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_aid FROM PUBLIC;
-- In production use case-level row scope, approved data-sharing authority, encryption and safeguarding review.
