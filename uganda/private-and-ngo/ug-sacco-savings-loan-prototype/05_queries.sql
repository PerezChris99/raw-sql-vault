-- Purpose: restricted SACCO savings and loan oversight queries.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Savings balances; member token output is restricted.
SELECT * FROM ug_sacco.v_savings_balances ORDER BY account_ref;
-- 02. Applications waiting for human decision.
SELECT * FROM ug_sacco.v_loan_review_queue ORDER BY submitted_at,application_ref;
-- 03. Principal-only outstanding balances. Interest, fees and penalties are intentionally excluded.
SELECT * FROM ug_sacco.v_loan_principal_balance ORDER BY loan_ref;
-- 04. Duplicate external transaction references (unique constraints should prevent these).
SELECT external_reference,COUNT(*) FROM ug_sacco.loan_transactions GROUP BY external_reference HAVING COUNT(*)>1;
-- 05. Savings accounts with negative balances requiring investigation.
SELECT * FROM ug_sacco.v_savings_balances WHERE balance<0;
-- 06. Loan balances greater than approved principal (should return zero absent approved corrections).
SELECT * FROM ug_sacco.v_loan_principal_balance WHERE principal_balance>approved_principal;
