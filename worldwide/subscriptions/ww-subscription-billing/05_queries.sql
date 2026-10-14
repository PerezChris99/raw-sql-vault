-- 20 read-only examples; never group monetary totals across currencies.
-- 01 Current subscription list.
SELECT * FROM subscription_demo.v_subscription_health ORDER BY status,subscription_ref;
-- 02 Invoices by balance state.
SELECT * FROM subscription_demo.v_invoice_balance ORDER BY due_date,invoice_ref;
-- 03 Outstanding amount by currency.
SELECT currency,SUM(outstanding_amount) FROM subscription_demo.v_invoice_balance WHERE status NOT IN('void','paid') GROUP BY currency;
-- 04 Overdue invoices.
SELECT * FROM subscription_demo.v_invoice_balance WHERE balance_status='overdue';
-- 05 Payment sum by invoice.
SELECT invoice_ref,paid_amount,amount_due,outstanding_amount FROM subscription_demo.v_invoice_balance;
-- 06 Revenue received by currency/month.
SELECT date_trunc('month',paid_at AT TIME ZONE 'UTC') month_utc,currency,SUM(amount) received FROM subscription_demo.payments GROUP BY 1,currency ORDER BY 1,currency;
-- 07 Subscriptions nearing renewal.
SELECT subscription_ref,current_period_end FROM subscription_demo.subscriptions WHERE status IN('active','past_due') AND current_period_end<CURRENT_DATE+30 ORDER BY current_period_end;
-- 08 Customers with no subscription.
SELECT customer_ref FROM subscription_demo.customers c WHERE NOT EXISTS(SELECT 1 FROM subscription_demo.subscriptions s WHERE s.customer_id=c.customer_id);
-- 09 Plans by billing interval.
SELECT billing_interval,currency,COUNT(*),AVG(price_amount) average_price FROM subscription_demo.plans WHERE is_active GROUP BY billing_interval,currency;
-- 10 Subscription status counts.
SELECT status,COUNT(*) FROM subscription_demo.subscriptions GROUP BY status;
-- 11 Invoice event history.
SELECT i.invoice_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM subscription_demo.invoice_events e JOIN subscription_demo.invoices i USING(invoice_id) ORDER BY i.invoice_ref,e.happened_at;
-- 12 Payment retries collision check (should be empty).
SELECT idempotency_key,COUNT(*) FROM subscription_demo.payments GROUP BY idempotency_key HAVING COUNT(*)>1;
-- 13 Invoices without payments.
SELECT invoice_ref FROM subscription_demo.invoices i WHERE NOT EXISTS(SELECT 1 FROM subscription_demo.payments p WHERE p.invoice_id=i.invoice_id);
-- 14 Paid invoices with mismatched payment sum (should be empty).
SELECT invoice_ref FROM subscription_demo.v_invoice_balance WHERE status='paid' AND outstanding_amount<>0;
-- 15 Failed/open invoices by plan.
SELECT plan_code,status,COUNT(*) FROM subscription_demo.v_invoice_balance GROUP BY plan_code,status;
-- 16 Top invoice balances.
SELECT invoice_ref,outstanding_amount,currency FROM subscription_demo.v_invoice_balance ORDER BY outstanding_amount DESC LIMIT 10;
-- 17 Billing-period overlap candidates.
SELECT a.subscription_ref,a.period_start,b.period_start FROM subscription_demo.invoices a JOIN subscription_demo.invoices b ON a.subscription_id=b.subscription_id AND a.invoice_id<b.invoice_id AND daterange(a.period_start,a.period_end,'[)')&&daterange(b.period_start,b.period_end,'[)');
-- 18 Customers by active subscription count.
SELECT c.customer_ref,COUNT(s.subscription_id) FILTER(WHERE s.status='active') active_count FROM subscription_demo.customers c LEFT JOIN subscription_demo.subscriptions s USING(customer_id) GROUP BY c.customer_ref;
-- 19 Payments with missing external references (should be empty).
SELECT payment_ref FROM subscription_demo.payments WHERE external_reference IS NULL;
-- 20 Future invoices due within 7 days.
SELECT invoice_ref,due_date,status FROM subscription_demo.invoices WHERE due_date>=CURRENT_DATE AND due_date<CURRENT_DATE+7 AND status<>'paid' ORDER BY due_date;