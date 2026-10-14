-- Purpose: purchase order, goods receipt and invoice reconciliation queries.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Purchase order value.
SELECT * FROM ug_sme_procure.v_purchase_order_value ORDER BY po_ref;
-- 02. Lines not fully received.
SELECT * FROM ug_sme_procure.v_receipt_progress WHERE outstanding_quantity>0 ORDER BY po_ref,line_no;
-- 03. Invoices needing match review.
SELECT * FROM ug_sme_procure.v_invoice_match_exceptions ORDER BY invoice_ref;
-- 04. Approved invoices exceeding accepted goods value (should return zero).
SELECT i.invoice_ref,i.invoice_amount,
 COALESCE(SUM((grl.quantity_received-grl.quantity_rejected)*l.unit_price),0) AS accepted_goods_value
FROM ug_sme_procure.supplier_invoices i
JOIN ug_sme_procure.purchase_order_lines l USING(purchase_order_id)
LEFT JOIN ug_sme_procure.goods_receipts gr ON gr.purchase_order_id=i.purchase_order_id AND gr.status IN ('accepted','partial')
LEFT JOIN ug_sme_procure.goods_receipt_lines grl ON grl.receipt_id=gr.receipt_id AND grl.po_line_id=l.po_line_id
WHERE i.status='approved'
GROUP BY i.invoice_id,i.invoice_ref,i.invoice_amount
HAVING i.invoice_amount>COALESCE(SUM((grl.quantity_received-grl.quantity_rejected)*l.unit_price),0);
-- 05. Suppliers with open purchase orders.
SELECT s.supplier_ref,COUNT(*) AS open_orders
FROM ug_sme_procure.suppliers s JOIN ug_sme_procure.purchase_orders po USING(supplier_id)
WHERE po.status IN ('issued','part_received') GROUP BY s.supplier_ref ORDER BY s.supplier_ref;
