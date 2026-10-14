-- Candidate indexes only; validate with representative synthetic workload.
CREATE INDEX IF NOT EXISTS ix_subscription_customer_status ON subscription_demo.subscriptions(customer_id,status);
CREATE INDEX IF NOT EXISTS ix_subscription_invoice_period ON subscription_demo.invoices(subscription_id,period_start);
CREATE INDEX IF NOT EXISTS ix_subscription_payment_idempotency ON subscription_demo.payments(idempotency_key);