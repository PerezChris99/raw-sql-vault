-- Purpose: public transport punctuality and service disruption queries.
-- Engine: PostgreSQL 15+. Prerequisites: schema, seed and views.
-- 01. Departure performance by route and service date.
SELECT * FROM ug_transport.v_departure_performance ORDER BY service_date,route_ref;
-- 02. Open service disruptions.
SELECT * FROM ug_transport.v_open_disruptions ORDER BY started_at;
-- 03. Past scheduled departures with no observation.
SELECT * FROM ug_transport.v_missing_departure_evidence ORDER BY scheduled_at,route_ref;
-- 04. Delay distribution by route.
SELECT r.route_ref,percentile_cont(0.5) WITHIN GROUP(ORDER BY o.delay_minutes) AS median_delay_minutes,
       percentile_cont(0.9) WITHIN GROUP(ORDER BY o.delay_minutes) AS p90_delay_minutes,
       COUNT(*) AS observations
FROM ug_transport.departure_observations o JOIN ug_transport.departure_schedules s USING(schedule_id)
JOIN ug_transport.routes r USING(route_id)
WHERE o.observation_status IN ('departed','delayed') GROUP BY r.route_ref ORDER BY r.route_ref;
-- 05. Observation coverage (missing data is not equivalent to cancelled service).
SELECT service_date,COUNT(*) AS scheduled,COUNT(*) FILTER(WHERE status='observed') AS observed_status
FROM ug_transport.departure_schedules GROUP BY service_date ORDER BY service_date;
