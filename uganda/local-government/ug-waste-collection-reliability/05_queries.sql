-- Purpose: route service reliability and exception reporting.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Completion by route shift.
SELECT * FROM ug_waste.v_route_shift_summary ORDER BY planned_start,route_ref;
-- 02. Missed, blocked and unsafe collection exceptions.
SELECT * FROM ug_waste.v_missed_service_queue ORDER BY occurred_at DESC;
-- 03. Incidents awaiting resolution.
SELECT * FROM ug_waste.v_open_incidents ORDER BY reported_at;
-- 04. Repeated exceptions by route and category.
SELECT r.route_ref,i.category,COUNT(*) AS incident_count
FROM ug_waste.service_incidents i JOIN ug_waste.shifts sh USING(shift_id)
JOIN ug_waste.routes r USING(route_id)
GROUP BY r.route_ref,i.category ORDER BY incident_count DESC;
-- 05. Planned shifts without pickup evidence.
SELECT sh.shift_ref,r.route_ref,sh.planned_start
FROM ug_waste.shifts sh JOIN ug_waste.routes r USING(route_id)
LEFT JOIN ug_waste.pickup_events pe USING(shift_id)
WHERE sh.status IN ('active','completed') GROUP BY sh.shift_id,sh.shift_ref,r.route_ref,sh.planned_start
HAVING COUNT(pe.pickup_id)=0;
