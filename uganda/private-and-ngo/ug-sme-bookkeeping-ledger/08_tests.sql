-- Purpose: assertions for balanced posting, immutable posted lines and period close guard.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed, views and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_count BIGINT; v_journal BIGINT; v_line BIGINT;
BEGIN
 PERFORM ug_sme_ledger.fn_post_journal('UGLED-J-DEMO-001','SYN-POSTER','SYN-POSTING-EVIDENCE-001');
 SELECT journal_id INTO v_journal FROM ug_sme_ledger.journal_entries WHERE journal_ref='UGLED-J-DEMO-001';
 BEGIN
  INSERT INTO ug_sme_ledger.journal_lines(journal_id,line_no,account_id,debit,credit,line_description_redacted)
  SELECT v_journal,3,account_id,1,0,'Should be blocked after posting' FROM ug_sme_ledger.accounts WHERE account_code='1000';
  RAISE EXCEPTION 'ASSERT posted journal line mutation was accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 SELECT COUNT(*) INTO v_count FROM ug_sme_ledger.v_journal_balance_check WHERE journal_ref='UGLED-J-DEMO-001' AND status='posted' AND imbalance=0 AND line_count=2;
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT balanced journal did not post correctly'; END IF;
 PERFORM ug_sme_ledger.fn_close_period('UGLED-P-DEMO-01','SYN-CLOSER','SYN-PERIOD-CLOSE-EVIDENCE');
 SELECT COUNT(*) INTO v_count FROM ug_sme_ledger.periods WHERE period_ref='UGLED-P-DEMO-01' AND status='closed';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT period did not close'; END IF;
END; $test$;
ROLLBACK;
