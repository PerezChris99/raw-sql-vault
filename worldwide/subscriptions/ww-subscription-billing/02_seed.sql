INSERT INTO subscription_demo.customers(customer_ref) VALUES('DEMO-CUST-A'),('DEMO-CUST-B')
ON CONFLICT(customer_ref) DO NOTHING;
INSERT INTO subscription_demo.plans(plan_code,plan_name,billing_interval,price_amount,currency) VALUES
('DEMO-MONTHLY','Synthetic monthly service plan','monthly',10000,'UGX'),
('DEMO-ANNUAL','Synthetic annual service plan','annual',100000,'UGX'),
('DEMO-USD-MONTHLY','Synthetic international plan','monthly',12.00,'USD')
ON CONFLICT(plan_code) DO NOTHING;
INSERT INTO subscription_demo.subscriptions(subscription_ref,customer_id,plan_id,status,started_at,current_period_start,current_period_end)
SELECT v.ref,c.customer_id,p.plan_id,v.status,v.started,v.ps,v.pe
FROM (VALUES
('DEMO-SUB-A','DEMO-CUST-A','DEMO-MONTHLY','active',TIMESTAMPTZ '2026-09-20 00:00:00+00',DATE '2026-10-01',DATE '2026-11-01'),
('DEMO-SUB-B','DEMO-CUST-B','DEMO-ANNUAL','past_due',TIMESTAMPTZ '2025-10-01 00:00:00+00',DATE '2026-10-01',DATE '2027-10-01')
) v(ref,customer_ref,plan_code,status,started,ps,pe)
JOIN subscription_demo.customers c ON c.customer_ref=v.customer_ref
JOIN subscription_demo.plans p ON p.plan_code=v.plan_code
ON CONFLICT(subscription_ref) DO NOTHING;
INSERT INTO subscription_demo.invoices(invoice_ref,subscription_id,period_start,period_end,amount_due,currency,due_date,status)
SELECT 'DEMO-INVOICE-001',s.subscription_id,DATE '2026-10-01',DATE '2026-11-01',10000,'UGX',DATE '2026-10-20','open'
FROM subscription_demo.subscriptions s WHERE s.subscription_ref='DEMO-SUB-A'
ON CONFLICT(invoice_ref) DO NOTHING;
INSERT INTO subscription_demo.invoice_events(invoice_id,previous_status,new_status,note,actor_ref)
SELECT i.invoice_id,NULL,'open','Synthetic invoice created','seed-script'
FROM subscription_demo.invoices i WHERE i.invoice_ref='DEMO-INVOICE-001'
AND NOT EXISTS(SELECT 1 FROM subscription_demo.invoice_events e WHERE e.invoice_id=i.invoice_id);