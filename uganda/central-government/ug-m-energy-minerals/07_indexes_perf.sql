-- Candidate indexes only; retain after workload measurement.
CREATE INDEX IF NOT EXISTS ix_energy_inspections_outcome_time ON energy_demo.inspections(outcome,inspected_at DESC);
CREATE INDEX IF NOT EXISTS ix_energy_actions_open_due ON energy_demo.corrective_actions(due_date,owner_ref) WHERE status NOT IN('closed','cancelled');