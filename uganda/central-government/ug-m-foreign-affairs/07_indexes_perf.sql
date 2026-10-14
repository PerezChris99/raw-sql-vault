-- Candidate indexes; validate against a measured workload.
CREATE INDEX IF NOT EXISTS ix_diplomacy_publication_time ON diplomacy_demo.engagements(publication_state,held_at DESC);
CREATE INDEX IF NOT EXISTS ix_diplomacy_commitments_owner_due ON diplomacy_demo.commitments(owner_ref,due_date) WHERE status NOT IN('completed','cancelled');