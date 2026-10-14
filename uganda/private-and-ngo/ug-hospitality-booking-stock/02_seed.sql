-- Purpose: synthetic property, resource and stock fixture. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_hospitality.properties(property_ref,property_name,locality_ref,property_type)
VALUES('UGHOT-DEMO-01','Synthetic guesthouse','SYN-LOCALITY-01','guesthouse')
ON CONFLICT(property_ref) DO NOTHING;
INSERT INTO ug_hospitality.resources(property_id,resource_ref,resource_type,capacity)
SELECT property_id,'UGHRES-DEMO-01','room',2 FROM ug_hospitality.properties WHERE property_ref='UGHOT-DEMO-01'
ON CONFLICT(resource_ref) DO NOTHING;
INSERT INTO ug_hospitality.inventory_items(property_id,item_ref,item_name,unit_code,reorder_level)
SELECT property_id,'UGHITEM-DEMO-01','Synthetic bottled water','bottle',12 FROM ug_hospitality.properties WHERE property_ref='UGHOT-DEMO-01'
ON CONFLICT(item_ref) DO NOTHING;
INSERT INTO ug_hospitality.stock_movements(movement_ref,idempotency_key,item_id,quantity_delta,movement_type,source_ref,reason,recorded_by_ref)
SELECT 'UGHSTK-DEMO-OPEN','hospitality-stock-open-001',item_id,100,'opening','SYN-OPENING-001','Synthetic opening stock','SYN-STOCK-CLERK'
FROM ug_hospitality.inventory_items WHERE item_ref='UGHITEM-DEMO-01'
ON CONFLICT(movement_ref) DO NOTHING;
