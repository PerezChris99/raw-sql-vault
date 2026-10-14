-- Candidate indexes only; benchmark the actual workload before retention.
CREATE INDEX IF NOT EXISTS ix_ict_work_owner_due ON ict_demo.work_items(owner_ref,due_at) WHERE status NOT IN('resolved','cancelled');
CREATE INDEX IF NOT EXISTS ix_ict_assets_service_environment ON ict_demo.assets(service_id,environment,lifecycle);