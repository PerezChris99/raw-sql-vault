-- Purpose: assertions for invoice approval requiring accepted goods and amount ceilings.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and procedures. Disposable DB only.
BEGIN;
DO $test$
DECLARE v_supplier BIGINT; v_po BIGINT; v_invoice BIGINT; v_count BIGINT;
BEGIN
 SELECT supplier_id INTO v_supplier FROM ug_sme_procure.suppliers WHERE supplier_ref='UGSUPP-DEMO-01';
 SELECT purchase_order_id INTO v_po FROM ug_sme_procure.purchase_orders WHERE po_ref='UGPO-DEMO-01';
 INSERT INTO ug_sme_procure.supplier_invoices(invoice_ref,supplier_id,purchase_order_id,supplier_invoice_number,invoice_date,invoice_amount,evidence_ref)
 VALUES('UGINV-DEMO-001',v_supplier,v_po,'SYN-INVOICE-001',CURRENT_DATE,1000,'SYN-INVOICE-EVIDENCE-001');
 BEGIN
  PERFORM ug_sme_procure.fn_review_invoice('UGINV-DEMO-001','approved','SYN-REVIEWER','SYN-REVIEW-EVIDENCE');
  RAISE EXCEPTION 'ASSERT invoice with no receipt was approved';
 EXCEPTION WHEN check_violation THEN NULL; END;
 PERFORM ug_sme_procure.fn_review_invoice('UGINV-DEMO-001','exception','SYN-REVIEWER','SYN-MISSING-RECEIPT-001');
 SELECT COUNT(*) INTO v_count FROM ug_sme_procure.supplier_invoices WHERE invoice_ref='UGINV-DEMO-001' AND status='exception';
 IF v_count<>1 THEN RAISE EXCEPTION 'ASSERT invoice exception status missing'; END IF;
END; $test$;
ROLLBACK;
