-- Purpose: separate read-only oversight from contract administration.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_works_contract_reader') THEN CREATE ROLE ug_works_contract_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_works_contract_clerk') THEN CREATE ROLE ug_works_contract_clerk NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_works_contract_reviewer') THEN CREATE ROLE ug_works_contract_reviewer NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_works_contract FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_works_contract TO ug_works_contract_reader,ug_works_contract_clerk,ug_works_contract_reviewer;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_works_contract FROM PUBLIC;
GRANT SELECT ON ug_works_contract.v_contract_budget_summary,ug_works_contract.v_overdue_milestones TO ug_works_contract_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA ug_works_contract TO ug_works_contract_clerk,ug_works_contract_reviewer;
GRANT EXECUTE ON FUNCTION ug_works_contract.fn_review_certificate(TEXT,TEXT,TEXT,TEXT,TEXT) TO ug_works_contract_reviewer;
GRANT EXECUTE ON FUNCTION ug_works_contract.fn_record_certificate_payment(TEXT,TEXT,TEXT,TEXT) TO ug_works_contract_clerk;
REVOKE ALL ON FUNCTION ug_works_contract.fn_review_certificate(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_works_contract.fn_record_certificate_payment(TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_works_contract FROM PUBLIC;
-- Operational deployments must also enforce user/office scope and independent approval separation.
