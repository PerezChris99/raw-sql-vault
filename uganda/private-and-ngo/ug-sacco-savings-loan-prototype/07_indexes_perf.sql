-- Purpose: inspect savings account and loan ledger balance lookups.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_sacco.savings_transactions;
ANALYZE ug_sacco.loan_transactions;
EXPLAIN (COSTS, VERBOSE)
SELECT savings_account_id,SUM(amount) FROM ug_sacco.savings_transactions WHERE savings_account_id=1 GROUP BY savings_account_id;
EXPLAIN (COSTS, VERBOSE)
SELECT loan_id,txn_type,SUM(amount) FROM ug_sacco.loan_transactions WHERE loan_id=1 GROUP BY loan_id,txn_type;
