-- Purpose: route completion, missed-service and incident reporting.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_waste.v_route_shift_summary AS
SELECT sh.shift_ref,r.route_ref,a.area_ref,sh.planned_start,sh.status,
 COUNT(DISTINCT rs.stop_id) AS planned_stops,
 COUNT(DISTINCT pe.stop_id) FILTER(WHERE pe.outcome IN ('collected','partial')) AS serviced_stops,
 COUNT(DISTINCT pe.stop_id) FILTER(WHERE pe.outcome IN ('missed','blocked','unsafe_to_collect')) AS exception_stops,
 round(100.0*COUNT(DISTINCT pe.stop_id) FILTER(WHERE pe.outcome IN ('collected','partial'))/NULLIF(COUNT(DISTINCT rs.stop_id),0),2) AS service_completion_percent
FROM ug_waste.shifts sh JOIN ug_waste.routes r USING(route_id)
JOIN ug_waste.service_areas a USING(area_id)
JOIN ug_waste.route_stops rs USING(route_id)
LEFT JOIN ug_waste.pickup_events pe ON pe.shift_id=sh.shift_id AND pe.stop_id=rs.stop_id
GROUP BY sh.shift_id,sh.shift_ref,r.route_ref,a.area_ref,sh.planned_start,sh.status;

CREATE OR REPLACE VIEW ug_waste.v_missed_service_queue AS
SELECT sh.shift_ref,r.route_ref,a.area_ref,rs.stop_ref,pe.outcome,pe.exception_reason,pe.occurred_at,pe.recorded_by_ref
FROM ug_waste.pickup_events pe JOIN ug_waste.shifts sh USING(shift_id)
JOIN ug_waste.routes r USING(route_id) JOIN ug_waste.service_areas a USING(area_id)
JOIN ug_waste.route_stops rs USING(stop_id)
WHERE pe.outcome IN ('missed','blocked','unsafe_to_collect');

CREATE OR REPLACE VIEW ug_waste.v_open_incidents AS
SELECT i.incident_ref,i.category,i.summary_redacted,i.reported_at,i.status,sh.shift_ref,r.route_ref
FROM ug_waste.service_incidents i JOIN ug_waste.shifts sh USING(shift_id)
JOIN ug_waste.routes r USING(route_id) WHERE i.status IN ('open','assigned');
