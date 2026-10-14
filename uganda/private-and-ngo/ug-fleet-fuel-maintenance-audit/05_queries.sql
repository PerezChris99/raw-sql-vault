-- Purpose: fleet fuel spend, maintenance backlog and exception investigation.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Fuel spend and litres by vehicle.
SELECT * FROM ug_fleet.v_fuel_summary ORDER BY vehicle_ref;
-- 02. Odometer/fuel quantity candidates for human review.
SELECT * FROM ug_fleet.v_fuel_anomaly_candidates ORDER BY fuel_date DESC;
-- 03. Open maintenance queue.
SELECT * FROM ug_fleet.v_maintenance_queue ORDER BY priority DESC,reported_at;
-- 04. Fuel cost per litre by vehicle (weighted average).
SELECT vehicle_ref,ROUND(total_fuel_cost/NULLIF(litres_issued,0),2) AS weighted_unit_cost
FROM ug_fleet.v_fuel_summary WHERE litres_issued>0 ORDER BY vehicle_ref;
-- 05. Fuel events lacking evidence (should return zero).
SELECT fuel_ref FROM ug_fleet.fuel_events WHERE evidence_ref IS NULL OR receipt_ref IS NULL;
