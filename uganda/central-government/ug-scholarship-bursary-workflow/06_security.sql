-- Purpose: least-privilege roles for case review, appeals and disbursement recording.
-- Engine: PostgreSQL 15+. Prerequisite: controlled schema administrator.
DO $roles$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_bursary_reader') THEN CREATE ROLE ug_bursary_reader NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_bursary_clerk') THEN CREATE ROLE ug_bursary_clerk NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_bursary_reviewer') THEN CREATE ROLE ug_bursary_reviewer NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='ug_bursary_finance') THEN CREATE ROLE ug_bursary_finance NOLOGIN; END IF;
END;
$roles$;
REVOKE ALL ON SCHEMA ug_bursary FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_bursary TO ug_bursary_reader,ug_bursary_clerk,ug_bursary_reviewer,ug_bursary_finance;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_bursary FROM PUBLIC;
GRANT SELECT ON ug_bursary.programmes,ug_bursary.v_application_queue,ug_bursary.v_award_disbursement_summary,ug_bursary.v_appeal_queue
TO ug_bursary_reader;
GRANT SELECT ON ug_bursary.programmes,ug_bursary.applications,ug_bursary.application_events,ug_bursary.document_metadata
TO ug_bursary_clerk,ug_bursary_reviewer;
GRANT SELECT ON ug_bursary.appeals TO ug_bursary_reviewer;
GRANT SELECT ON ug_bursary.disbursements TO ug_bursary_finance;
GRANT EXECUTE ON FUNCTION ug_bursary.fn_transition_application(TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_bursary_clerk,ug_bursary_reviewer;
GRANT EXECUTE ON FUNCTION ug_bursary.fn_file_appeal(TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_bursary_clerk;
GRANT EXECUTE ON FUNCTION ug_bursary.fn_review_appeal(TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_bursary_reviewer;
GRANT EXECUTE ON FUNCTION ug_bursary.fn_record_disbursement(TEXT,TEXT,TEXT,NUMERIC,TEXT,TEXT,TIMESTAMPTZ,TEXT) TO ug_bursary_finance;
REVOKE ALL ON FUNCTION ug_bursary.fn_transition_application(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_bursary.fn_file_appeal(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_bursary.fn_review_appeal(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_bursary.fn_record_disbursement(TEXT,TEXT,TEXT,NUMERIC,TEXT,TEXT,TIMESTAMPTZ,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_bursary FROM PUBLIC;
-- Keep SECURITY DEFINER routines owned by a trusted schema owner and schema non-writable
-- by runtime roles. Real users receive role membership only after identity and duties review.
