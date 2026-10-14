-- Candidate indexes only; measure against expected workloads.
CREATE INDEX IF NOT EXISTS ix_social_milestone_type_due ON social_demo.service_milestones(milestone_type,due_date) WHERE status NOT IN('completed','cancelled');
CREATE INDEX IF NOT EXISTS ix_social_programme_enrolment_date ON social_demo.enrolments(programme_id,opened_at DESC);