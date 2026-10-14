-- 20 read-only reports over synthetic aggregate records only.
-- 01 Filing reconciliation.
SELECT * FROM ura_demo.v_filing_reconciliation ORDER BY taxpayer_ref,tax_type,period_end;
-- 02 Exception queue.
SELECT * FROM ura_demo.v_filing_exceptions ORDER BY reconciliation_status,taxpayer_ref;
-- 03 Declared vs assessed amount by tax type.
SELECT tax_type,currency,SUM(declared_payable) declared,SUM(assessed_payable) assessed FROM ura_demo.v_filing_reconciliation GROUP BY tax_type,currency;
-- 04 Outstanding by reconciliation state.
SELECT reconciliation_status,currency,SUM(outstanding_amount) FROM ura_demo.v_filing_reconciliation GROUP BY reconciliation_status,currency;
-- 05 Filings per status.
SELECT status,COUNT(*) FROM ura_demo.filings GROUP BY status;
-- 06 Revisions by account and period.
SELECT taxpayer_ref,tax_type,period_start,COUNT(*) revision_count,MAX(revision_no) latest_revision FROM ura_demo.filings f JOIN ura_demo.tax_accounts a USING(account_id) GROUP BY taxpayer_ref,tax_type,period_start;
-- 07 Accounts with no filings.
SELECT taxpayer_ref FROM ura_demo.tax_accounts a WHERE NOT EXISTS(SELECT 1 FROM ura_demo.filings f WHERE f.account_id=a.account_id);
-- 08 Payment entries per filing.
SELECT f.filing_ref,COUNT(p.payment_id) payments,COALESCE(SUM(p.amount),0) paid_amount FROM ura_demo.filings f LEFT JOIN ura_demo.payments p USING(filing_id) GROUP BY f.filing_ref;
-- 09 Filing history.
SELECT f.filing_ref,e.previous_status,e.new_status,e.actor_ref,e.happened_at FROM ura_demo.filing_events e JOIN ura_demo.filings f USING(filing_id) ORDER BY f.filing_ref,e.happened_at;
-- 10 Latest event per filing.
SELECT DISTINCT ON(filing_id) filing_id,new_status,happened_at FROM ura_demo.filing_events ORDER BY filing_id,happened_at DESC,event_id DESC;
-- 11 Payments by channel and currency.
SELECT channel,currency,COUNT(*),SUM(amount) FROM ura_demo.payments GROUP BY channel,currency;
-- 12 Payment records per UTC month.
SELECT date_trunc('month',created_at AT TIME ZONE 'UTC') month_utc,currency,SUM(amount) FROM ura_demo.payments GROUP BY 1,currency ORDER BY 1,currency;
-- 13 Assessment difference ranked by magnitude.
SELECT filing_ref,assessment_difference,ROW_NUMBER() OVER(ORDER BY ABS(assessment_difference) DESC) AS difference_rank FROM ura_demo.v_filing_reconciliation;
-- 14 Period end in upcoming 30 days.
SELECT filing_ref,period_end,status FROM ura_demo.filings WHERE period_end>=CURRENT_DATE AND period_end<CURRENT_DATE+30 ORDER BY period_end;
-- 15 Settled or overpaid balances for review (not a legal conclusion).
SELECT filing_ref,paid_amount,assessed_payable FROM ura_demo.v_filing_reconciliation WHERE reconciliation_status='settled_or_overpaid';
-- 16 Negative/invalid payable scan (should be empty due to constraints).
SELECT filing_ref FROM ura_demo.filings WHERE declared_payable<0 OR assessed_payable<0;
-- 17 Duplicate payment idempotency keys (should be empty).
SELECT idempotency_key,COUNT(*) FROM ura_demo.payments GROUP BY idempotency_key HAVING COUNT(*)>1;
-- 18 Payments with absent source refs (should be empty).
SELECT payment_ref FROM ura_demo.payments WHERE external_reference IS NULL;
-- 19 Active account count by opaque area code.
SELECT registered_area_code,account_type,COUNT(*) FROM ura_demo.tax_accounts WHERE is_active GROUP BY registered_area_code,account_type;
-- 20 Disputed filings needing follow-up.
SELECT filing_ref,taxpayer_ref,assessment_difference,outstanding_amount FROM ura_demo.v_filing_exceptions WHERE status='disputed';