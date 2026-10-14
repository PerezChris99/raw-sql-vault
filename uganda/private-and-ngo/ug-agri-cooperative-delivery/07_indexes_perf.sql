-- Candidate indexes only; evaluate with representative synthetic workloads.
CREATE INDEX IF NOT EXISTS ix_coop_delivery_date_state ON coop_demo.deliveries(delivery_date,status);
CREATE INDEX IF NOT EXISTS ix_coop_member_deliveries ON coop_demo.deliveries(member_id,delivery_date DESC);
CREATE INDEX IF NOT EXISTS ix_coop_payment_idempotency ON coop_demo.payments(idempotency_key);