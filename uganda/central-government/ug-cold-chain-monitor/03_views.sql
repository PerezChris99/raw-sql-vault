-- Purpose: equipment status, temperature history and unresolved risk queues.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_cold_chain.v_latest_temperature AS
SELECT DISTINCT ON (r.equipment_id)
       r.equipment_id,e.equipment_ref,f.facility_ref,f.facility_name,r.reading_ref,
       r.observed_at,r.temperature_c,e.temperature_min_c,e.temperature_max_c,
       r.calibration_was_current,r.source_reference,
       (r.temperature_c<e.temperature_min_c OR r.temperature_c>e.temperature_max_c) AS outside_configured_range
FROM ug_cold_chain.temperature_readings r
JOIN ug_cold_chain.equipment e USING(equipment_id)
JOIN ug_cold_chain.facilities f USING(facility_id)
ORDER BY r.equipment_id,r.observed_at DESC,r.reading_id DESC;

CREATE OR REPLACE VIEW ug_cold_chain.v_open_excursions AS
SELECT x.excursion_id,x.excursion_kind,x.severity,x.status,x.detected_at,
       e.equipment_ref,f.facility_ref,f.facility_name,r.reading_ref,r.observed_at,r.temperature_c,
       e.temperature_min_c,e.temperature_max_c
FROM ug_cold_chain.excursions x
JOIN ug_cold_chain.equipment e USING(equipment_id)
JOIN ug_cold_chain.facilities f USING(facility_id)
JOIN ug_cold_chain.temperature_readings r USING(reading_id)
WHERE x.status IN ('open','investigating');

CREATE OR REPLACE VIEW ug_cold_chain.v_maintenance_queue AS
SELECT w.work_order_ref,w.priority,w.status,w.reported_at,w.assigned_to_ref,
       e.equipment_ref,e.equipment_type,f.facility_ref,f.facility_name,w.excursion_id
FROM ug_cold_chain.maintenance_orders w
JOIN ug_cold_chain.equipment e USING(equipment_id)
JOIN ug_cold_chain.facilities f USING(facility_id)
WHERE w.status NOT IN ('completed','cancelled');
