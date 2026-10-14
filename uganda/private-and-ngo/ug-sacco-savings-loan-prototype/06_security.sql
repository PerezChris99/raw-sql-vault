-- Purpose: separate member-service, transaction clerk, loan reviewer and audit-reader roles.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_sacco_reader') THEN CREATE ROLE ug_sacco_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_sacco_txn_clerk') THEN CREATE ROLE ug_sacco_txn_clerk NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_sacco_loan_reviewer') THEN CREATE ROLE ug_sacco_loan_reviewer NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_sacco FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_sacco TO ug_sacco_reader,ug_sacco_txn_clerk,ug_sacco_loan_reviewer;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_sacco FROM PUBLIC;
GRANT SELECT ON ug_sacco.v_savings_balances,ug_sacco.v_loan_principal_balance TO ug_sacco_reader;
GRANT SELECT ON ug_sacco.savings_accounts,ug_sacco.savings_transactions,ug_sacco.loans,ug_sacco.loan_transactions TO ug_sacco_txn_clerk;
GRANT EXECUTE ON FUNCTION ug_sacco.fn_record_loan_transaction(TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,TIMESTAMPTZ,TEXT,TEXT) TO ug_sacco_txn_clerk;
GRANT SELECT ON ug_sacco.loan_applications,ug_sacco.members TO ug_sacco_loan_reviewer;
GRANT EXECUTE ON FUNCTION ug_sacco.fn_review_loan_application(TEXT,TEXT,NUMERIC,TEXT,TEXT,TEXT) TO ug_sacco_loan_reviewer;
REVOKE ALL ON FUNCTION ug_sacco.fn_record_loan_transaction(TEXT,TEXT,TEXT,TEXT,NUMERIC,TEXT,TIMESTAMPTZ,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_sacco.fn_review_loan_application(TEXT,TEXT,NUMERIC,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_sacco FROM PUBLIC;
-- Real deployment requires member row scope, dual control, reconciliation and licensed compliance review.
