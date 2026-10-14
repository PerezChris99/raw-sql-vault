-- Purpose: order value, receipt progress and three-way invoice match exception reporting.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_sme_procure.v_purchase_order_value AS
SELECT po.po_ref,po.status,s.supplier_ref,po.currency_code,po.ordered_on,po.expected_on,
 SUM(l.ordered_quantity*l.unit_price+l.tax_amount)::NUMERIC(16,2) AS order_value
FROM ug_sme_procure.purchase_orders po JOIN ug_sme_procure.suppliers s USING(supplier_id)
JOIN ug_sme_procure.purchase_order_lines l USING(purchase_order_id)
GROUP BY po.purchase_order_id,po.po_ref,po.status,s.supplier_ref,po.currency_code,po.ordered_on,po.expected_on;

CREATE OR REPLACE VIEW ug_sme_procure.v_receipt_progress AS
SELECT po.po_ref,l.line_no,l.item_ref,l.ordered_quantity,
 COALESCE(SUM(grl.quantity_received-grl.quantity_rejected) FILTER(WHERE gr.status IN ('accepted','partial')),0) AS net_accepted_quantity,
 l.ordered_quantity-COALESCE(SUM(grl.quantity_received-grl.quantity_rejected) FILTER(WHERE gr.status IN ('accepted','partial')),0) AS outstanding_quantity
FROM ug_sme_procure.purchase_orders po JOIN ug_sme_procure.purchase_order_lines l USING(purchase_order_id)
LEFT JOIN ug_sme_procure.goods_receipts gr USING(purchase_order_id)
LEFT JOIN ug_sme_procure.goods_receipt_lines grl ON grl.receipt_id=gr.receipt_id AND grl.po_line_id=l.po_line_id
GROUP BY po.purchase_order_id,po.po_ref,l.po_line_id,l.line_no,l.item_ref,l.ordered_quantity;

CREATE OR REPLACE VIEW ug_sme_procure.v_invoice_match_exceptions AS
SELECT i.invoice_ref,i.supplier_invoice_number,po.po_ref,i.invoice_amount,
 COALESCE(ov.order_value,0) AS order_value,i.status
FROM ug_sme_procure.supplier_invoices i JOIN ug_sme_procure.purchase_orders po USING(purchase_order_id)
LEFT JOIN ug_sme_procure.v_purchase_order_value ov USING(po_ref)
WHERE i.status IN ('received','exception') OR i.invoice_amount>COALESCE(ov.order_value,0);
