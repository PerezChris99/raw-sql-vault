-- Purpose: prevent journal-line edits after the parent journal has been posted or reversed.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_sme_ledger.fn_guard_posted_journal_line()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path=pg_catalog,ug_sme_ledger AS $$
DECLARE v_journal_id BIGINT; v_status TEXT;
BEGIN
 v_journal_id:=CASE WHEN TG_OP='DELETE' THEN OLD.journal_id ELSE NEW.journal_id END;
 SELECT status INTO v_status FROM ug_sme_ledger.journal_entries WHERE journal_id=v_journal_id FOR UPDATE;
 IF v_status<>'draft' THEN RAISE EXCEPTION 'Posted/reversed journal lines are immutable; use an evidenced reversal' USING ERRCODE='check_violation'; END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; ELSE RETURN NEW; END IF;
END; $$;
DROP TRIGGER IF EXISTS trg_guard_posted_journal_line ON ug_sme_ledger.journal_lines;
CREATE TRIGGER trg_guard_posted_journal_line
BEFORE INSERT OR UPDATE OR DELETE ON ug_sme_ledger.journal_lines
FOR EACH ROW EXECUTE FUNCTION ug_sme_ledger.fn_guard_posted_journal_line();
