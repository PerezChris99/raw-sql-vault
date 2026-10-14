-- Purpose: route departure punctuality and disruption reporting.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_transport.v_departure_performance AS
SELECT r.route_ref,o.operator_ref,s.service_date,
 COUNT(DISTINCT s.schedule_id) AS scheduled_departures,
 COUNT(DISTINCT obs.observation_id) FILTER(WHERE obs.observation_status IN ('departed','delayed')) AS observed_departures,
 COUNT(DISTINCT obs.observation_id) FILTER(WHERE obs.observation_status='cancelled') AS cancelled_departures,
 COUNT(DISTINCT obs.observation_id) FILTER(WHERE obs.observation_status='not_observed') AS missing_observations,
 round(100.0*COUNT(DISTINCT obs.observation_id) FILTER(WHERE obs.observation_status='departed' AND obs.delay_minutes<=5)
 /NULLIF(COUNT(DISTINCT obs.observation_id) FILTER(WHERE obs.observation_status IN ('departed','delayed')),0),2) AS on_time_percent
FROM ug_transport.departure_schedules s JOIN ug_transport.routes r USING(route_id)
JOIN ug_transport.operators o USING(operator_id)
LEFT JOIN ug_transport.departure_observations obs USING(schedule_id)
GROUP BY r.route_ref,o.operator_ref,s.service_date;

CREATE OR REPLACE VIEW ug_transport.v_open_disruptions AS
SELECT d.disruption_ref,r.route_ref,d.started_at,d.category,d.summary_redacted,d.source_ref,d.status
FROM ug_transport.disruptions d JOIN ug_transport.routes r USING(route_id)
WHERE d.status='open';

CREATE OR REPLACE VIEW ug_transport.v_missing_departure_evidence AS
SELECT s.schedule_ref,r.route_ref,s.service_date,s.scheduled_at,s.status
FROM ug_transport.departure_schedules s JOIN ug_transport.routes r USING(route_id)
WHERE s.scheduled_at<CURRENT_TIMESTAMP AND s.status IN ('scheduled','missed')
AND NOT EXISTS(SELECT 1 FROM ug_transport.departure_observations o WHERE o.schedule_id=s.schedule_id);
