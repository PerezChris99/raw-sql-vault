-- Purpose: journal preparer, independent poster and read-only reporting roles.
-- Engine: PostgreSQL 15+. Run as controlled schema owner.
DO $roles$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_sme_ledger_reader') THEN CREATE ROLE ug_sme_ledger_reader NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_sme_ledger_preparer') THEN CREATE ROLE ug_sme_ledger_preparer NOLOGIN; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='ug_sme_ledger_poster') THEN CREATE ROLE ug_sme_ledger_poster NOLOGIN; END IF;
END; $roles$;
REVOKE ALL ON SCHEMA ug_sme_ledger FROM PUBLIC;
GRANT USAGE ON SCHEMA ug_sme_ledger TO ug_sme_ledger_reader,ug_sme_ledger_preparer,ug_sme_ledger_poster;
REVOKE ALL ON ALL TABLES IN SCHEMA ug_sme_ledger FROM PUBLIC;
GRANT SELECT ON ug_sme_ledger.v_trial_balance,ug_sme_ledger.v_journal_balance_check,ug_sme_ledger.v_period_summary TO ug_sme_ledger_reader;
GRANT SELECT,INSERT,DELETE ON ug_sme_ledger.journal_entries TO ug_sme_ledger_preparer;
GRANT SELECT,INSERT,UPDATE,DELETE ON ug_sme_ledger.journal_lines TO ug_sme_ledger_preparer;
GRANT SELECT ON ug_sme_ledger.periods,ug_sme_ledger.accounts TO ug_sme_ledger_preparer;
GRANT SELECT ON ug_sme_ledger.journal_entries,ug_sme_ledger.journal_lines,ug_sme_ledger.periods TO ug_sme_ledger_poster;
GRANT EXECUTE ON FUNCTION ug_sme_ledger.fn_post_journal(TEXT,TEXT,TEXT) TO ug_sme_ledger_poster;
GRANT EXECUTE ON FUNCTION ug_sme_ledger.fn_close_period(TEXT,TEXT,TEXT) TO ug_sme_ledger_poster;
REVOKE ALL ON FUNCTION ug_sme_ledger.fn_post_journal(TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION ug_sme_ledger.fn_close_period(TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA ug_sme_ledger FROM PUBLIC;
GRANT USAGE,SELECT ON ALL SEQUENCES IN SCHEMA ug_sme_ledger TO ug_sme_ledger_preparer;
-- Header UPDATE is intentionally withheld from preparers so posted state cannot be bypassed with direct DML.
-- Map preparer and poster roles to distinct authenticated people; use audited reversals in live systems.
