-- Purpose: inspect account ledger and period reporting access paths.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_sme_ledger.journal_entries;
ANALYZE ug_sme_ledger.journal_lines;
EXPLAIN (COSTS, VERBOSE)
SELECT account_id,SUM(debit),SUM(credit) FROM ug_sme_ledger.journal_lines WHERE account_id=1 GROUP BY account_id;
EXPLAIN (COSTS, VERBOSE)
SELECT period_id,transaction_date,status FROM ug_sme_ledger.journal_entries WHERE period_id=1 ORDER BY transaction_date;
