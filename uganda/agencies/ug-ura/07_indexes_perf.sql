-- Candidate indexes only; retain after EXPLAIN on representative synthetic data.
CREATE INDEX IF NOT EXISTS ix_ura_account_tax_period ON ura_demo.filings(account_id,tax_type,period_end DESC);
CREATE INDEX IF NOT EXISTS ix_ura_filing_status_period ON ura_demo.filings(status,period_end);
CREATE INDEX IF NOT EXISTS ix_ura_payment_idempotency ON ura_demo.payments(idempotency_key);