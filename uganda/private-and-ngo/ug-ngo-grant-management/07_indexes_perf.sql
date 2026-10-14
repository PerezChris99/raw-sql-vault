-- Candidate indexes only; assess plan and write overhead before retention.
CREATE INDEX IF NOT EXISTS ix_ngo_grant_end_status ON ngo_demo.grants(status,end_date);
CREATE INDEX IF NOT EXISTS ix_ngo_expense_idempotency ON ngo_demo.expenditures(idempotency_key);
CREATE INDEX IF NOT EXISTS ix_ngo_milestone_project_due ON ngo_demo.milestones(project_id,due_date);
CREATE INDEX IF NOT EXISTS ix_ngo_outcome_project_indicator ON ngo_demo.outcome_observations(project_id,indicator_code,period_end DESC);