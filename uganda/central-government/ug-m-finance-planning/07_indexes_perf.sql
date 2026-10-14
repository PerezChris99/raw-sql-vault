-- Candidate indexes only; measure with EXPLAIN on representative synthetic data.
CREATE INDEX IF NOT EXISTS ix_finance_budget_vote_year ON finance_demo.budget_lines(vote_code,fiscal_year_start);
CREATE INDEX IF NOT EXISTS ix_finance_release_idempotency ON finance_demo.releases(idempotency_key);
CREATE INDEX IF NOT EXISTS ix_finance_expenditure_idempotency ON finance_demo.expenditures(idempotency_key);