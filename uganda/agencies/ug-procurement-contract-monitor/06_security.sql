-- Purpose: role separation for public disclosure, procurement clerks and variation reviewers.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_procurement_public_reader') THEN CREATE ROLE ug_procurement_public_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_procurement_clerk') THEN CREATE ROLE ug_procurement_clerk NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_procurement_reviewer') THEN CREATE ROLE ug_procurement_reviewer NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_procurement FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_procurement TO ug_procurement_public_reader,ug_procurement_clerk,ug_procurement_reviewer;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_procurement FROM PUBLIC;
GRANT SELECT ON ug_procurement.v_public_award_register TO ug_procurement_public_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA ug_procurement TO ug_procurement_clerk,ug_procurement_reviewer;
GRANT EXECUTE ON FUNCTION ug_procurement.fn_review_variation(TEXT,TEXT,TEXT,TEXT) TO ug_procurement_reviewer;
REVOKE ALL ON FUNCTION ug_procurement.fn_review_variation(TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_procurement FROM PUBLIC;
-- Actual user-to-role mapping, office scoping, procurement rules and public disclosure approvals remain deployment duties.
