-- Purpose: synthetic supplier, input products, lots and opening stock movements.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_agri_inputs.suppliers(supplier_ref,supplier_name,source_reference) VALUES
 ('UGSUP-DEMO-001','Synthetic Supplier Alpha','SYNTHETIC-SUPPLIER'),
 ('UGSUP-DEMO-002','Synthetic Supplier Beta','SYNTHETIC-SUPPLIER')
ON CONFLICT(supplier_ref) DO NOTHING;

INSERT INTO ug_agri_inputs.input_products(product_code,product_name,input_type,unit_code) VALUES
 ('DEMO-MAIZE-SEED','Synthetic maize seed','seed','KG'),
 ('DEMO-FERTILISER','Synthetic fertiliser','fertiliser','KG'),
 ('DEMO-HOE','Synthetic hand tool','tool','UNIT')
ON CONFLICT(product_code) DO NOTHING;

INSERT INTO ug_agri_inputs.lots(lot_ref,product_id,supplier_id,supplier_lot_ref,received_on,expires_on,warehouse_ref,source_document_ref)
SELECT v.lot_ref,p.product_id,s.supplier_id,v.supplier_lot_ref,DATE '2026-01-10',v.expires_on,
       'SYN-WAREHOUSE-01',v.source_ref
FROM (VALUES
 ('UGLOT-DEMO-001','DEMO-MAIZE-SEED','UGSUP-DEMO-001','SUP-LOT-001',DATE '2027-01-10','SYN-GRN-001'),
 ('UGLOT-DEMO-002','DEMO-FERTILISER','UGSUP-DEMO-002','SUP-LOT-002',DATE '2027-01-10','SYN-GRN-002')
) AS v(lot_ref,product_code,supplier_ref,supplier_lot_ref,expires_on,source_ref)
JOIN ug_agri_inputs.input_products p ON p.product_code=v.product_code
JOIN ug_agri_inputs.suppliers s ON s.supplier_ref=v.supplier_ref
ON CONFLICT(lot_ref) DO NOTHING;

INSERT INTO ug_agri_inputs.stock_movements(movement_ref,idempotency_key,lot_id,movement_type,quantity,movement_at,source_document_ref,reason,recorded_by)
SELECT v.movement_ref,v.idempotency_key,l.lot_id,'received',v.quantity,TIMESTAMPTZ '2026-01-10 10:00:00+03',
       v.source_ref,'Synthetic opening stock receipt','synthetic-seed'
FROM (VALUES
 ('UGMOV-DEMO-001','agri-seed-key-001','UGLOT-DEMO-001',1000.000::numeric,'SYN-GRN-001'),
 ('UGMOV-DEMO-002','agri-seed-key-002','UGLOT-DEMO-002',5000.000::numeric,'SYN-GRN-002')
) AS v(movement_ref,idempotency_key,lot_ref,quantity,source_ref)
JOIN ug_agri_inputs.lots l ON l.lot_ref=v.lot_ref
ON CONFLICT(movement_ref) DO NOTHING;
