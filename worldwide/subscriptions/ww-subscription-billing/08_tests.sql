-- PostgreSQL 15+; all test changes roll back.
BEGIN;
DO $test$
DECLARE v_payment_a BIGINT;v_payment_b BIGINT;v_paid NUMERIC;v_outstanding NUMERIC;v_status TEXT;
BEGIN
 DELETE FROM subscription_demo.invoice_events WHERE invoice_id=(SELECT invoice_id FROM subscription_demo.invoices WHERE invoice_ref='DEMO-INVOICE-001');
 DELETE FROM subscription_demo.payments WHERE invoice_id=(SELECT invoice_id FROM subscription_demo.invoices WHERE invoice_ref='DEMO-INVOICE-001');
 UPDATE subscription_demo.invoices SET status='open',paid_at=NULL WHERE invoice_ref='DEMO-INVOICE-001';
 v_payment_a:=subscription_demo.fn_record_payment('TEST-SUB-PAY-001','DEMO-INVOICE-001',4000,'UGX','TEST-PROCESSOR-REF-001','TEST-SUB-IDEM-001');
 v_payment_b:=subscription_demo.fn_record_payment('TEST-SUB-PAY-001','DEMO-INVOICE-001',4000,'UGX','TEST-PROCESSOR-REF-001','TEST-SUB-IDEM-001');
 IF v_payment_a<>v_payment_b THEN RAISE EXCEPTION 'ASSERT payment idempotency failed'; END IF;
 SELECT paid_amount,outstanding_amount,status INTO v_paid,v_outstanding,v_status FROM subscription_demo.v_invoice_balance WHERE invoice_ref='DEMO-INVOICE-001';
 IF v_paid<>4000 OR v_outstanding<>6000 OR v_status<>'open' THEN RAISE EXCEPTION 'ASSERT partial balance wrong'; END IF;
 BEGIN
  PERFORM subscription_demo.fn_record_payment('TEST-SUB-OVER','DEMO-INVOICE-001',7000,'UGX','TEST-PROCESSOR-OVER','TEST-SUB-OVER-IDEM');
  RAISE EXCEPTION 'ASSERT overpayment accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM subscription_demo.fn_record_payment('TEST-SUB-PAY-002','DEMO-INVOICE-001',6000,'UGX','TEST-PROCESSOR-REF-002','TEST-SUB-IDEM-002');
 SELECT paid_amount,outstanding_amount,status INTO v_paid,v_outstanding,v_status FROM subscription_demo.v_invoice_balance WHERE invoice_ref='DEMO-INVOICE-001';
 IF v_paid<>10000 OR v_outstanding<>0 OR v_status<>'paid' THEN RAISE EXCEPTION 'ASSERT paid invoice balance wrong'; END IF;
END; $test$;
ROLLBACK;