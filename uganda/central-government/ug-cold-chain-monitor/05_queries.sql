-- Purpose: operational queries for cold-chain monitoring and maintenance.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- All fixture references are synthetic; bind parameters in application code.

-- 01. Latest reading per item of equipment.
SELECT * FROM ug_cold_chain.v_latest_temperature ORDER BY facility_ref,equipment_ref;

-- 02. Unresolved temperature excursions by severity.
SELECT * FROM ug_cold_chain.v_open_excursions ORDER BY
 CASE severity WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'moderate' THEN 3 ELSE 4 END,detected_at;

-- 03. Active maintenance queue.
SELECT * FROM ug_cold_chain.v_maintenance_queue
ORDER BY CASE priority WHEN 'urgent' THEN 1 WHEN 'high' THEN 2 WHEN 'normal' THEN 3 ELSE 4 END,reported_at;

-- 04. Equipment with overdue calibration.
SELECT e.equipment_ref,e.equipment_type,f.facility_ref,e.calibration_due_on,e.operational_status
FROM ug_cold_chain.equipment e JOIN ug_cold_chain.facilities f USING(facility_id)
WHERE e.calibration_due_on<CURRENT_DATE AND e.operational_status<>'retired'
ORDER BY e.calibration_due_on;

-- 05. Reading history for an equipment reference.
SELECT r.observed_at,r.temperature_c,r.sensor_ref,r.source_reference,r.calibration_was_current,r.recorded_by
FROM ug_cold_chain.temperature_readings r JOIN ug_cold_chain.equipment e USING(equipment_id)
WHERE e.equipment_ref='UGCC-DEMO-001' ORDER BY r.observed_at DESC;

-- 06. Excursion count and resolution lag.
SELECT severity,status,COUNT(*) AS excursion_count,
       AVG(EXTRACT(EPOCH FROM (COALESCE(resolved_at,now())-detected_at))/3600.0) AS average_hours_open
FROM ug_cold_chain.excursions GROUP BY severity,status ORDER BY severity,status;

-- 07. Equipment with no reading in the last 24 hours.
SELECT e.equipment_ref,f.facility_ref,MAX(r.observed_at) AS last_reading
FROM ug_cold_chain.equipment e JOIN ug_cold_chain.facilities f USING(facility_id)
LEFT JOIN ug_cold_chain.temperature_readings r ON r.equipment_id=e.equipment_id
WHERE e.operational_status IN ('active','quarantined')
GROUP BY e.equipment_id,e.equipment_ref,f.facility_ref
HAVING MAX(r.observed_at)<now()-INTERVAL '24 hours' OR MAX(r.observed_at) IS NULL;

-- 08. Work orders with missing completion evidence (should return zero).
SELECT work_order_ref FROM ug_cold_chain.maintenance_orders
WHERE status='completed' AND (completed_at IS NULL OR completion_reference IS NULL);

-- 09. Temperature range exceptions without an excursion row (should return zero if readings entered via function).
SELECT r.reading_ref,e.equipment_ref,r.temperature_c,e.temperature_min_c,e.temperature_max_c
FROM ug_cold_chain.temperature_readings r JOIN ug_cold_chain.equipment e USING(equipment_id)
LEFT JOIN ug_cold_chain.excursions x USING(reading_id)
WHERE (r.temperature_c<e.temperature_min_c OR r.temperature_c>e.temperature_max_c) AND x.excursion_id IS NULL;

-- 10. Facility-level equipment status.
SELECT f.facility_ref,f.facility_name,e.operational_status,COUNT(*) AS equipment_count
FROM ug_cold_chain.equipment e JOIN ug_cold_chain.facilities f USING(facility_id)
GROUP BY f.facility_ref,f.facility_name,e.operational_status
ORDER BY f.facility_ref,e.operational_status;
