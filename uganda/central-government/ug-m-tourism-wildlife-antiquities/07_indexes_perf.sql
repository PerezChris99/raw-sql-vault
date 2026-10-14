-- Candidate indexes only; measure on representative synthetic data.
CREATE INDEX IF NOT EXISTS ix_tourism_inspections_outcome_time ON tourism_demo.inspections(outcome,inspected_at DESC);
CREATE INDEX IF NOT EXISTS ix_tourism_action_due_owner ON tourism_demo.actions(owner_ref,due_date) WHERE status NOT IN('closed','cancelled');