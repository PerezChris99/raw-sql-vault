INSERT INTO nms_demo.warehouses(warehouse_code,warehouse_label,locality_code) VALUES
('DEMO-WH-001','Synthetic Central Warehouse','DEMO-AREA-A'),('DEMO-WH-002','Synthetic Regional Store','DEMO-AREA-B')
ON CONFLICT(warehouse_code) DO NOTHING;
INSERT INTO nms_demo.facilities(facility_code,facility_label,facility_level,locality_code) VALUES
('DEMO-FAC-001','Synthetic General Hospital','hospital','DEMO-AREA-A'),
('DEMO-FAC-002','Synthetic Health Centre','health_centre','DEMO-AREA-B')
ON CONFLICT(facility_code) DO NOTHING;
INSERT INTO nms_demo.medicines(medicine_code,medicine_label,unit_of_measure) VALUES
('DEMO-MED-A','Synthetic basic medicine A','pack'),('DEMO-MED-B','Synthetic basic medicine B','bottle')
ON CONFLICT(medicine_code) DO NOTHING;
INSERT INTO nms_demo.batches(batch_code,medicine_id,expiry_date,batch_status,source_reference)
SELECT v.batch,m.medicine_id,v.expiry,v.status,v.source
FROM (VALUES
('DEMO-LOT-A','DEMO-MED-A',DATE '2027-06-30','active','DEMO-SOURCE-A'),
('DEMO-LOT-B','DEMO-MED-B',DATE '2027-01-31','active','DEMO-SOURCE-B'),
('DEMO-LOT-R','DEMO-MED-A',DATE '2027-09-30','recalled','DEMO-RECALL-REF')
) v(batch,code,expiry,status,source) JOIN nms_demo.medicines m ON m.medicine_code=v.code
ON CONFLICT(batch_code) DO NOTHING;
INSERT INTO nms_demo.dispatches(dispatch_ref,warehouse_id,facility_id,dispatch_date,status,dispatch_document_ref)
SELECT 'DEMO-DISP-001',w.warehouse_id,f.facility_id,DATE '2026-10-05','dispatched','DEMO-DN-001'
FROM nms_demo.warehouses w CROSS JOIN nms_demo.facilities f
WHERE w.warehouse_code='DEMO-WH-001' AND f.facility_code='DEMO-FAC-001'
ON CONFLICT(dispatch_ref) DO NOTHING;
INSERT INTO nms_demo.dispatch_lines(dispatch_id,batch_id,quantity_sent)
SELECT d.dispatch_id,b.batch_id,v.quantity
FROM (VALUES('DEMO-DISP-001','DEMO-LOT-A',100),('DEMO-DISP-001','DEMO-LOT-B',40)) v(dispatch_ref,batch_code,quantity)
JOIN nms_demo.dispatches d ON d.dispatch_ref=v.dispatch_ref JOIN nms_demo.batches b ON b.batch_code=v.batch_code
ON CONFLICT(dispatch_id,batch_id) DO NOTHING;