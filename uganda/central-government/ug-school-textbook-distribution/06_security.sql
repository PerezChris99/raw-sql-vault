-- Purpose: separate distribution clerks and education oversight reporting.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_textbooks_reader') THEN CREATE ROLE ug_textbooks_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_textbooks_clerk') THEN CREATE ROLE ug_textbooks_clerk NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_textbooks FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_textbooks TO ug_textbooks_reader,ug_textbooks_clerk;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_textbooks FROM PUBLIC;
GRANT SELECT ON ug_textbooks.v_stock_on_hand,ug_textbooks.v_allocation_reconciliation,ug_textbooks.v_receipt_exceptions TO ug_textbooks_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA ug_textbooks TO ug_textbooks_clerk;
GRANT EXECUTE ON FUNCTION ug_textbooks.fn_record_movement(TEXT,TEXT,TEXT,TEXT,INTEGER,TEXT,TEXT,TEXT,TEXT) TO ug_textbooks_clerk;
REVOKE ALL ON FUNCTION ug_textbooks.fn_record_movement(TEXT,TEXT,TEXT,TEXT,INTEGER,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_textbooks FROM PUBLIC;
-- Apply authenticated school/warehouse scope, dual approval for write-offs and access logs at deployment.
