-- PostgreSQL 15+; synthetic test writes are rolled back.
BEGIN;
DO $test$
DECLARE v_id BIGINT;v_a BIGINT;v_b BIGINT;v_count BIGINT;v_paid NUMERIC;
BEGIN
 INSERT INTO ura_demo.filings(filing_ref,account_id,tax_type,period_start,period_end,revision_no,filed_at,declared_payable,assessed_payable,currency,status,source_document_ref)
 SELECT 'TEST-AUTOPILOT-URA',account_id,'other_demo',DATE '2026-07-01',DATE '2026-07-31',1,now(),50000,50000,'UGX','assessed','TEST-SOURCE'
 FROM ura_demo.tax_accounts WHERE taxpayer_ref='DEMO-TAXPAYER-A'
 ON CONFLICT(filing_ref) DO UPDATE SET assessed_payable=50000,status='assessed'
 RETURNING filing_id INTO v_id;
 DELETE FROM ura_demo.payments WHERE filing_id=v_id;
 v_a:=ura_demo.fn_record_payment('TEST-URA-PAY-1','TEST-AUTOPILOT-URA',DATE '2026-08-01',20000,'UGX','bank_transfer','TEST-EXT-1','TEST-URA-IDEM-1');
 v_b:=ura_demo.fn_record_payment('TEST-URA-PAY-1','TEST-AUTOPILOT-URA',DATE '2026-08-01',20000,'UGX','bank_transfer','TEST-EXT-1','TEST-URA-IDEM-1');
 IF v_a<>v_b THEN RAISE EXCEPTION 'ASSERT payment idempotency failed'; END IF;
 SELECT COUNT(*),SUM(amount) INTO v_count,v_paid FROM ura_demo.payments WHERE filing_id=v_id;
 IF v_count<>1 OR v_paid<>20000 THEN RAISE EXCEPTION 'ASSERT retry double-posted: count %, paid %',v_count,v_paid; END IF;
 BEGIN
  PERFORM ura_demo.fn_record_payment('TEST-URA-OVER','TEST-AUTOPILOT-URA',DATE '2026-08-02',40000,'UGX','bank_transfer','TEST-EXT-OVER','TEST-URA-IDEM-OVER');
  RAISE EXCEPTION 'ASSERT overpayment accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 BEGIN
  PERFORM ura_demo.fn_record_payment('TEST-URA-WRONG-CURRENCY','TEST-AUTOPILOT-URA',DATE '2026-08-02',1000,'USD','bank_transfer','TEST-EXT-USD','TEST-URA-IDEM-USD');
  RAISE EXCEPTION 'ASSERT currency mismatch accepted';
 EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
END; $test$;
ROLLBACK;