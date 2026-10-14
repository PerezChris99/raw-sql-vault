-- Candidate indexes only; profile representative synthetic volumes before retaining.
CREATE INDEX IF NOT EXISTS ix_nms_batch_expiry_status ON nms_demo.batches(expiry_date,batch_status);
CREATE INDEX IF NOT EXISTS ix_nms_dispatch_warehouse_date ON nms_demo.dispatches(warehouse_id,dispatch_date DESC);
CREATE INDEX IF NOT EXISTS ix_nms_receipt_idempotency ON nms_demo.receipt_entries(idempotency_key);