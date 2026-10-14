CREATE OR REPLACE VIEW ura_demo.v_filing_reconciliation AS
SELECT f.filing_ref,a.taxpayer_ref,f.tax_type,f.period_start,f.period_end,f.revision_no,
 f.declared_payable,f.assessed_payable,f.assessed_payable-f.declared_payable AS assessment_difference,
 f.currency,f.status,
 COALESCE(p.paid_amount,0)::NUMERIC(20,2) AS paid_amount,
 f.assessed_payable-COALESCE(p.paid_amount,0) AS outstanding_amount,
 CASE WHEN f.status='disputed' THEN 'disputed'
 WHEN COALESCE(p.paid_amount,0)>=f.assessed_payable THEN 'settled_or_overpaid'
 WHEN f.period_end<CURRENT_DATE AND COALESCE(p.paid_amount,0)<f.assessed_payable THEN 'outstanding_past_period'
 ELSE 'open_balance' END AS reconciliation_status
FROM ura_demo.filings f JOIN ura_demo.tax_accounts a USING(account_id)
LEFT JOIN(SELECT filing_id,SUM(amount) paid_amount FROM ura_demo.payments GROUP BY filing_id)p USING(filing_id);
CREATE OR REPLACE VIEW ura_demo.v_filing_exceptions AS
SELECT * FROM ura_demo.v_filing_reconciliation
WHERE status='disputed' OR assessment_difference<>0 OR outstanding_amount>0;
COMMENT ON VIEW ura_demo.v_filing_exceptions IS 'Synthetic reconciliation follow-up only; no fraud or legal-compliance conclusion.';