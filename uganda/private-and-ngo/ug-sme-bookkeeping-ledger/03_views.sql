-- Purpose: posted trial balance, journal balance checks and period ledger summaries.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_sme_ledger.v_trial_balance AS
SELECT a.account_code,a.account_name,a.account_type,
 COALESCE(SUM(l.debit) FILTER(WHERE j.status IN ('posted','reversed')),0)::NUMERIC(16,2) AS debits,
 COALESCE(SUM(l.credit) FILTER(WHERE j.status IN ('posted','reversed')),0)::NUMERIC(16,2) AS credits,
 COALESCE(SUM(l.debit-l.credit) FILTER(WHERE j.status IN ('posted','reversed')),0)::NUMERIC(16,2) AS net_debit
FROM ug_sme_ledger.accounts a
LEFT JOIN ug_sme_ledger.journal_lines l USING(account_id)
LEFT JOIN ug_sme_ledger.journal_entries j USING(journal_id)
GROUP BY a.account_id,a.account_code,a.account_name,a.account_type;

CREATE OR REPLACE VIEW ug_sme_ledger.v_journal_balance_check AS
SELECT j.journal_ref,j.transaction_date,j.status,
 COUNT(l.line_id) AS line_count,COALESCE(SUM(l.debit),0)::NUMERIC(16,2) AS total_debit,
 COALESCE(SUM(l.credit),0)::NUMERIC(16,2) AS total_credit,
 COALESCE(SUM(l.debit)-SUM(l.credit),0)::NUMERIC(16,2) AS imbalance
FROM ug_sme_ledger.journal_entries j LEFT JOIN ug_sme_ledger.journal_lines l USING(journal_id)
GROUP BY j.journal_id,j.journal_ref,j.transaction_date,j.status;

CREATE OR REPLACE VIEW ug_sme_ledger.v_period_summary AS
SELECT p.period_ref,p.starts_on,p.ends_on,p.status,COUNT(j.journal_id) FILTER(WHERE j.status='posted') AS posted_journals,
 COALESCE(SUM(l.debit) FILTER(WHERE j.status='posted'),0)::NUMERIC(16,2) AS posted_debits,
 COALESCE(SUM(l.credit) FILTER(WHERE j.status='posted'),0)::NUMERIC(16,2) AS posted_credits
FROM ug_sme_ledger.periods p LEFT JOIN ug_sme_ledger.journal_entries j USING(period_id)
LEFT JOIN ug_sme_ledger.journal_lines l USING(journal_id)
GROUP BY p.period_id,p.period_ref,p.starts_on,p.ends_on,p.status;
