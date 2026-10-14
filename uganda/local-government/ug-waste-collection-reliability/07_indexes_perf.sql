-- Purpose: inspect route shift and missed-pickup queries.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_waste.pickup_events;
ANALYZE ug_waste.service_incidents;
EXPLAIN (COSTS, VERBOSE)
SELECT shift_id,stop_id,outcome FROM ug_waste.pickup_events WHERE shift_id=1 ORDER BY occurred_at;
EXPLAIN (COSTS, VERBOSE)
SELECT incident_ref,reported_at FROM ug_waste.service_incidents WHERE status IN ('open','assigned') ORDER BY reported_at;
