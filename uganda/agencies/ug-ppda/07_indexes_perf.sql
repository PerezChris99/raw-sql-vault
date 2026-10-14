-- Candidate indexes only; measure before retaining.
CREATE INDEX IF NOT EXISTS ix_ppda_tenders_closing ON ppda_demo.tenders(tender_status,closing_at);
CREATE INDEX IF NOT EXISTS ix_ppda_milestones_status_due ON ppda_demo.contract_milestones(status,due_date);
CREATE INDEX IF NOT EXISTS ix_ppda_events_actor_time ON ppda_demo.milestone_events(actor_ref,happened_at DESC);