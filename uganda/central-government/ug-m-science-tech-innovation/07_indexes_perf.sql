-- Candidate indexes. Retain only after measuring read/write workload.
CREATE INDEX IF NOT EXISTS ix_innovation_proposal_status_time ON innovation_demo.proposals(status,submitted_at DESC);
CREATE INDEX IF NOT EXISTS ix_innovation_milestone_due_status ON innovation_demo.milestones(due_date,status) WHERE status NOT IN('completed','cancelled');