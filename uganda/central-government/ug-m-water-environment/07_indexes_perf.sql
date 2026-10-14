-- Candidate indexes only; measure with representative synthetic workloads.
CREATE INDEX IF NOT EXISTS ix_water_outcome_sampled ON water_demo.water_observations(outcome,sampled_at DESC);
CREATE INDEX IF NOT EXISTS ix_water_open_priority_due ON water_demo.maintenance_jobs(priority DESC,due_date) WHERE is_deleted=FALSE AND status NOT IN('completed','cancelled');