-- Purpose: inspect scheduled departures and observation lookups.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_transport.departure_schedules;
ANALYZE ug_transport.departure_observations;
EXPLAIN (COSTS, VERBOSE)
SELECT route_id,service_date,scheduled_at FROM ug_transport.departure_schedules
WHERE service_date=DATE '2026-10-16' ORDER BY scheduled_at;
EXPLAIN (COSTS, VERBOSE)
SELECT schedule_id,observation_status,delay_minutes FROM ug_transport.departure_observations WHERE schedule_id=1;
