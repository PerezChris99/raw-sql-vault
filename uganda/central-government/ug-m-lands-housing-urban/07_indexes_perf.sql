-- Candidate indexes; verify with measured query plans.
CREATE INDEX IF NOT EXISTS ix_urban_inspections_outcome ON urban_demo.inspections(outcome,inspected_at DESC);
CREATE INDEX IF NOT EXISTS ix_urban_actions_owner_due ON urban_demo.actions(owner_ref,due_date) WHERE status NOT IN('closed','cancelled');