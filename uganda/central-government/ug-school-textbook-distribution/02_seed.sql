-- Purpose: synthetic textbook and stock fixtures. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_textbooks.textbooks(textbook_code,title,subject_code,grade_level,edition)
VALUES('SYN-MATH-P4','Synthetic Primary Mathematics','MATHEMATICS','P4','DEMO-EDITION-1')
ON CONFLICT(textbook_code) DO NOTHING;
INSERT INTO ug_textbooks.warehouses(warehouse_ref,warehouse_name,locality_ref)
VALUES('UGTB-WH-DEMO-01','Synthetic central store','SYN-LOCALITY-01')
ON CONFLICT(warehouse_ref) DO NOTHING;
INSERT INTO ug_textbooks.stock_movements(movement_ref,warehouse_id,textbook_id,movement_type,quantity_delta,source_ref,reason,recorded_by,idempotency_key)
SELECT 'UGTB-MV-DEMO-OPEN',w.warehouse_id,t.textbook_id,'opening',1000,'SYN-OPENING-STOCK','Initial synthetic stock','SYN-STOREKEEPER','textbook-open-stock-001'
FROM ug_textbooks.warehouses w CROSS JOIN ug_textbooks.textbooks t
WHERE w.warehouse_ref='UGTB-WH-DEMO-01' AND t.textbook_code='SYN-MATH-P4'
ON CONFLICT(movement_ref) DO NOTHING;
INSERT INTO ug_textbooks.allocations(allocation_ref,textbook_id,destination_school_ref,academic_year,allocated_quantity,approved_by_ref,approval_evidence_ref)
SELECT 'UGTB-AL-DEMO-01',textbook_id,'SYN-SCHOOL-01','2026/2027',120,'SYN-EDU-APPROVER','SYN-ALLOCATION-AUTH-001'
FROM ug_textbooks.textbooks WHERE textbook_code='SYN-MATH-P4'
ON CONFLICT(allocation_ref) DO NOTHING;
