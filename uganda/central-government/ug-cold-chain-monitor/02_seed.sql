-- Purpose: synthetic facilities, equipment and maintenance examples.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Safe to rerun.
INSERT INTO ug_cold_chain.facilities(facility_ref,facility_name,locality_ref,source_reference) VALUES
 ('UGFAC-DEMO-001','Synthetic Health Facility Alpha','DEMO-LOCALITY-01','SYNTHETIC-FACILITY'),
 ('UGFAC-DEMO-002','Synthetic Health Facility Beta','DEMO-LOCALITY-02','SYNTHETIC-FACILITY')
ON CONFLICT(facility_ref) DO NOTHING;

INSERT INTO ug_cold_chain.equipment(equipment_ref,facility_id,equipment_type,manufacturer_ref,serial_ref,
    temperature_min_c,temperature_max_c,commissioned_on,calibration_due_on,operational_status)
SELECT v.equipment_ref,f.facility_id,v.equipment_type,'SYNTHETIC-MANUFACTURER',v.serial_ref,
       v.min_c,v.max_c,DATE '2025-01-01',DATE '2027-01-01','active'
FROM (VALUES
 ('UGCC-DEMO-001','UGFAC-DEMO-001','vaccine_fridge','SERIAL-DEMO-001',2.00::numeric,8.00::numeric),
 ('UGCC-DEMO-002','UGFAC-DEMO-002','medical_freezer','SERIAL-DEMO-002',-25.00::numeric,-10.00::numeric)
) AS v(equipment_ref,facility_ref,equipment_type,serial_ref,min_c,max_c)
JOIN ug_cold_chain.facilities f ON f.facility_ref=v.facility_ref
ON CONFLICT(equipment_ref) DO NOTHING;

INSERT INTO ug_cold_chain.maintenance_orders(work_order_ref,equipment_id,priority,status,created_by)
SELECT 'UGWO-DEMO-001',equipment_id,'normal','open','synthetic-seed'
FROM ug_cold_chain.equipment WHERE equipment_ref='UGCC-DEMO-001'
ON CONFLICT(work_order_ref) DO NOTHING;

INSERT INTO ug_cold_chain.maintenance_events(work_order_id,from_status,to_status,actor_ref,reason)
SELECT w.work_order_id,NULL,w.status,'synthetic-seed','Synthetic work order created'
FROM ug_cold_chain.maintenance_orders w
WHERE w.work_order_ref='UGWO-DEMO-001'
AND NOT EXISTS (SELECT 1 FROM ug_cold_chain.maintenance_events e WHERE e.work_order_id=w.work_order_id);
