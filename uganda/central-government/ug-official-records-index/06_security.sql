-- Purpose: metadata-reader, records clerk and disposition reviewer role separation.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_records_reader') THEN CREATE ROLE ug_records_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_records_clerk') THEN CREATE ROLE ug_records_clerk NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_records_disposition_reviewer') THEN CREATE ROLE ug_records_disposition_reviewer NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_records FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_records TO ug_records_reader,ug_records_clerk,ug_records_disposition_reviewer;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_records FROM PUBLIC;
GRANT SELECT ON ug_records.v_custody_register,ug_records.v_retention_review TO ug_records_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA ug_records TO ug_records_clerk,ug_records_disposition_reviewer;
GRANT EXECUTE ON FUNCTION ug_records.fn_transfer_custody(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_records_clerk;
GRANT EXECUTE ON FUNCTION ug_records.fn_review_disposition(TEXT,TEXT,TEXT,TEXT) TO ug_records_disposition_reviewer;
GRANT EXECUTE ON FUNCTION ug_records.fn_execute_disposition(TEXT,TEXT,TEXT) TO ug_records_clerk;
REVOKE ALL ON FUNCTION ug_records.fn_transfer_custody(TEXT,TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_records.fn_review_disposition(TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_records.fn_execute_disposition(TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_records FROM PUBLIC;
-- Real document-object storage must enforce its own ACLs, encryption, audit and legal holds.
