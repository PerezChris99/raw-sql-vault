-- Candidate indexes; measure query plans before retaining.
CREATE INDEX IF NOT EXISTS ix_trade_applicant_sector ON trade_demo.applicant_refs(sector_code,business_type) WHERE is_active;
CREATE INDEX IF NOT EXISTS ix_trade_milestone_owner_due ON trade_demo.milestones(owner_ref,due_date) WHERE status NOT IN('completed','cancelled');