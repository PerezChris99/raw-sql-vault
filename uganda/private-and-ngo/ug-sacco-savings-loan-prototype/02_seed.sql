-- Purpose: synthetic SACCO member, savings account and loan application fixture. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_sacco.members(member_token,joining_source_ref,consent_or_authority_ref,joined_on)
VALUES('SYN-SACCO-MEMBER-001','SYN-MEMBER-SOURCE-001','SYN-MEMBER-AUTHORITY-001',DATE '2024-01-01')
ON CONFLICT(member_token) DO NOTHING;
INSERT INTO ug_sacco.savings_accounts(account_ref,member_id,product_code,opened_on)
SELECT 'UGSAC-SAV-DEMO-001',member_id,'SYN-ORDINARY-SAVINGS',DATE '2024-01-01'
FROM ug_sacco.members WHERE member_token='SYN-SACCO-MEMBER-001'
ON CONFLICT(account_ref) DO NOTHING;
INSERT INTO ug_sacco.savings_transactions(txn_ref,idempotency_key,savings_account_id,txn_type,amount,external_reference,occurred_at,recorded_by_ref,evidence_ref)
SELECT 'UGSAC-ST-DEMO-001','sacco-savings-idem-001',savings_account_id,'deposit',100000,'SYN-SAVINGS-RECEIPT-001',
 TIMESTAMPTZ '2026-10-01 10:00:00+03','SYN-SACCO-CLERK','SYN-SAVINGS-EVIDENCE-001'
FROM ug_sacco.savings_accounts WHERE account_ref='UGSAC-SAV-DEMO-001'
ON CONFLICT(txn_ref) DO NOTHING;
INSERT INTO ug_sacco.loan_applications(application_ref,member_id,product_code,requested_amount,purpose_redacted)
SELECT 'UGSAC-LA-DEMO-001',member_id,'SYN-SMALL-LOAN',500000,'Synthetic business equipment request'
FROM ug_sacco.members WHERE member_token='SYN-SACCO-MEMBER-001'
ON CONFLICT(application_ref) DO NOTHING;
