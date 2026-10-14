CREATE OR REPLACE VIEW subscription_demo.v_invoice_balance AS
SELECT i.invoice_ref,s.subscription_ref,c.customer_ref,p.plan_code,i.period_start,i.period_end,
 i.amount_due,i.currency,i.due_date,i.status,
 COALESCE(pay.paid_amount,0)::NUMERIC(18,2) AS paid_amount,
 i.amount_due-COALESCE(pay.paid_amount,0) AS outstanding_amount,
 CASE WHEN i.status='paid' THEN 'paid' WHEN i.status='void' THEN 'void'
 WHEN i.due_date<CURRENT_DATE AND COALESCE(pay.paid_amount,0)<i.amount_due THEN 'overdue'
 WHEN COALESCE(pay.paid_amount,0)>0 THEN 'part_paid' ELSE 'unpaid' END AS balance_status
FROM subscription_demo.invoices i JOIN subscription_demo.subscriptions s USING(subscription_id)
JOIN subscription_demo.customers c USING(customer_id) JOIN subscription_demo.plans p USING(plan_id)
LEFT JOIN(SELECT invoice_id,SUM(amount) paid_amount FROM subscription_demo.payments GROUP BY invoice_id) pay USING(invoice_id);
CREATE OR REPLACE VIEW subscription_demo.v_subscription_health AS
SELECT s.subscription_ref,c.customer_ref,p.plan_code,p.billing_interval,p.price_amount,p.currency,
 s.status,s.current_period_start,s.current_period_end,s.cancel_at_period_end
FROM subscription_demo.subscriptions s JOIN subscription_demo.customers c USING(customer_id)
JOIN subscription_demo.plans p USING(plan_id);
COMMENT ON VIEW subscription_demo.v_invoice_balance IS 'Balance is based on recorded synthetic payment entries, not external processor settlement.';