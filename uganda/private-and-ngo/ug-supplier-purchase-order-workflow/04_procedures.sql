-- Purpose: evidence-backed invoice match decision using order ceiling and accepted receipt value.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_sme_procure.fn_review_invoice(
 p_invoice_ref TEXT,p_decision TEXT,p_reviewer_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_sme_procure AS $$
DECLARE i ug_sme_procure.supplier_invoices%ROWTYPE; v_order NUMERIC(16,2); v_received NUMERIC(16,2); v_id BIGINT;
BEGIN
 IF p_decision NOT IN ('approved','rejected','exception') OR length(btrim(COALESCE(p_reviewer_ref,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Decision, reviewer and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO i FROM ug_sme_procure.supplier_invoices WHERE invoice_ref=p_invoice_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Invoice not found' USING ERRCODE='no_data_found'; END IF;
 IF i.status NOT IN ('received','matched','exception') THEN RAISE EXCEPTION 'Invoice is not reviewable' USING ERRCODE='check_violation'; END IF;
 SELECT COALESCE(SUM(l.ordered_quantity*l.unit_price+l.tax_amount),0) INTO v_order
 FROM ug_sme_procure.purchase_order_lines l WHERE l.purchase_order_id=i.purchase_order_id;
 SELECT COALESCE(SUM((grl.quantity_received-grl.quantity_rejected)*l.unit_price),0) INTO v_received
 FROM ug_sme_procure.goods_receipt_lines grl JOIN ug_sme_procure.goods_receipts gr USING(receipt_id)
 JOIN ug_sme_procure.purchase_order_lines l ON l.po_line_id=grl.po_line_id
 WHERE gr.purchase_order_id=i.purchase_order_id AND gr.status IN ('accepted','partial');
 IF p_decision='approved' AND (i.invoice_amount>v_order OR i.invoice_amount>v_received) THEN
  RAISE EXCEPTION 'Invoice exceeds order value or accepted goods value' USING ERRCODE='check_violation';
 END IF;
 UPDATE ug_sme_procure.supplier_invoices SET status=p_decision WHERE invoice_id=i.invoice_id;
 RETURN i.invoice_id;
END; $$;
