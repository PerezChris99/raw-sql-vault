-- Purpose: savings balances, loan review queue and principal-only outstanding balance.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_sacco.v_savings_balances AS
SELECT a.account_ref,m.member_token,a.product_code,a.currency_code,a.status,
 COALESCE(SUM(CASE WHEN t.txn_type IN ('deposit','correction_credit') THEN t.amount ELSE -t.amount END),0)::NUMERIC(16,2) AS balance
FROM ug_sacco.savings_accounts a JOIN ug_sacco.members m USING(member_id)
LEFT JOIN ug_sacco.savings_transactions t USING(savings_account_id)
GROUP BY a.savings_account_id,a.account_ref,m.member_token,a.product_code,a.currency_code,a.status;

CREATE OR REPLACE VIEW ug_sacco.v_loan_review_queue AS
SELECT a.application_ref,m.member_token,a.product_code,a.requested_amount,a.status,a.submitted_at
FROM ug_sacco.loan_applications a JOIN ug_sacco.members m USING(member_id)
WHERE a.status IN ('submitted','under_review');

CREATE OR REPLACE VIEW ug_sacco.v_loan_principal_balance AS
SELECT l.loan_ref,m.member_token,l.approved_principal,l.currency_code,l.status,
 COALESCE(SUM(CASE WHEN t.txn_type IN ('disbursement','principal_correction_debit') THEN t.amount
                   WHEN t.txn_type IN ('repayment','principal_correction_credit') THEN -t.amount END),0)::NUMERIC(16,2) AS principal_balance
FROM ug_sacco.loans l JOIN ug_sacco.members m USING(member_id)
LEFT JOIN ug_sacco.loan_transactions t USING(loan_id)
GROUP BY l.loan_id,l.loan_ref,m.member_token,l.approved_principal,l.currency_code,l.status;
