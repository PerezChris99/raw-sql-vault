-- Candidate indexes only; benchmark with representative data.
CREATE INDEX IF NOT EXISTS ix_pos_receipt_terminal_time ON pos_demo.sales(terminal_ref,occurred_at DESC);
CREATE INDEX IF NOT EXISTS ix_pos_return_line ON pos_demo.returns(sale_line_id,created_at DESC);
CREATE INDEX IF NOT EXISTS ix_pos_stock_reason_time ON pos_demo.stock_events(reason,happened_at DESC);