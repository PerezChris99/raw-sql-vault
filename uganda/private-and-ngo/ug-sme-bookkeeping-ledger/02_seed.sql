-- Purpose: synthetic chart of accounts, accounting period and balanced example journal.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_sme_ledger.accounts(account_code,account_name,account_type) VALUES
('1000','Cash clearing','asset'),
('3000','Owner capital','equity'),
('4000','Service revenue','income'),
('5000','Operating expense','expense')
ON CONFLICT(account_code) DO NOTHING;
INSERT INTO ug_sme_ledger.periods(period_ref,starts_on,ends_on)
VALUES('UGLED-P-DEMO-01',DATE '2026-10-01',DATE '2026-10-31')
ON CONFLICT(period_ref) DO NOTHING;
INSERT INTO ug_sme_ledger.journal_entries(journal_ref,idempotency_key,period_id,transaction_date,description_redacted,source_type,source_ref,created_by_ref)
SELECT 'UGLED-J-DEMO-001','sme-ledger-journal-demo-001',period_id,DATE '2026-10-05','Synthetic owner capital contribution','opening_ref','SYN-SOURCE-001','SYN-BOOKKEEPER'
FROM ug_sme_ledger.periods WHERE period_ref='UGLED-P-DEMO-01'
ON CONFLICT(journal_ref) DO NOTHING;
INSERT INTO ug_sme_ledger.journal_lines(journal_id,line_no,account_id,debit,credit,line_description_redacted)
SELECT j.journal_id,v.line_no,a.account_id,v.debit,v.credit,v.description
FROM ug_sme_ledger.journal_entries j
CROSS JOIN (VALUES(1,'1000',1000000::NUMERIC,0::NUMERIC,'Synthetic cash received'),
                   (2,'3000',0::NUMERIC,1000000::NUMERIC,'Synthetic owner capital')) v(line_no,account_code,debit,credit,description)
JOIN ug_sme_ledger.accounts a ON a.account_code=v.account_code
WHERE j.journal_ref='UGLED-J-DEMO-001'
ON CONFLICT(journal_id,line_no) DO NOTHING;
