-- Purpose: synthetic supplier and purchase order fixture. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_sme_procure.suppliers(supplier_ref,supplier_name,status,due_diligence_ref,reviewed_by_ref,reviewed_at)
VALUES('UGSUPP-DEMO-01','Synthetic stationery supplier','active','SYN-DUE-DILIGENCE-001','SYN-OWNER-01',now())
ON CONFLICT(supplier_ref) DO NOTHING;
INSERT INTO ug_sme_procure.purchase_requests(request_ref,requesting_unit_ref,requested_by_ref,reason,status,reviewed_by_ref,reviewed_at,review_evidence_ref)
VALUES('UGPR-DEMO-01','SYN-OFFICE-01','SYN-REQUESTER-01','Synthetic stationery replenishment','approved','SYN-APPROVER-01',now(),'SYN-PR-APPROVAL-001')
ON CONFLICT(request_ref) DO NOTHING;
INSERT INTO ug_sme_procure.purchase_orders(po_ref,request_id,supplier_id,ordered_on,expected_on,status,approved_by_ref,approval_evidence_ref)
SELECT 'UGPO-DEMO-01',r.request_id,s.supplier_id,CURRENT_DATE,CURRENT_DATE+14,'issued','SYN-APPROVER-01','SYN-PO-APPROVAL-001'
FROM ug_sme_procure.purchase_requests r CROSS JOIN ug_sme_procure.suppliers s
WHERE r.request_ref='UGPR-DEMO-01' AND s.supplier_ref='UGSUPP-DEMO-01'
ON CONFLICT(po_ref) DO NOTHING;
INSERT INTO ug_sme_procure.purchase_order_lines(purchase_order_id,line_no,item_ref,description,ordered_quantity,unit_price,tax_amount)
SELECT purchase_order_id,1,'SYN-ITEM-PAPER','Synthetic paper cartons',10,85000,0
FROM ug_sme_procure.purchase_orders WHERE po_ref='UGPO-DEMO-01'
ON CONFLICT(purchase_order_id,line_no) DO NOTHING;
