-- Purpose: trial balance, journal integrity and accounting period reports.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Trial balance across posted entries.
SELECT * FROM ug_sme_ledger.v_trial_balance ORDER BY account_code;
-- 02. Draft journals that need balanced lines before posting.
SELECT * FROM ug_sme_ledger.v_journal_balance_check WHERE status='draft' ORDER BY transaction_date,journal_ref;
-- 03. Period summary; totals must reconcile.
SELECT * FROM ug_sme_ledger.v_period_summary ORDER BY starts_on;
-- 04. Posted journal line trace.
SELECT j.journal_ref,j.transaction_date,a.account_code,a.account_name,l.debit,l.credit,l.line_description_redacted,j.posted_by_ref,j.posting_evidence_ref
FROM ug_sme_ledger.journal_entries j JOIN ug_sme_ledger.journal_lines l USING(journal_id)
JOIN ug_sme_ledger.accounts a USING(account_id) WHERE j.status IN ('posted','reversed')
ORDER BY j.transaction_date,j.journal_ref,l.line_no;
-- 05. Posted journals that are not balanced (should return zero).
SELECT * FROM ug_sme_ledger.v_journal_balance_check WHERE status IN ('posted','reversed') AND (line_count<2 OR imbalance<>0);
