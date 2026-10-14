-- Purpose: inspect vehicle fuel history and open maintenance queries.
-- Engine: PostgreSQL 15+. Run after representative synthetic data is loaded.
ANALYZE ug_fleet.fuel_events;
ANALYZE ug_fleet.maintenance_orders;
EXPLAIN (COSTS, VERBOSE)
SELECT fuel_date,odometer_reading,quantity_litres FROM ug_fleet.fuel_events WHERE vehicle_id=1 ORDER BY fuel_date DESC;
EXPLAIN (COSTS, VERBOSE)
SELECT maintenance_ref,priority,reported_at FROM ug_fleet.maintenance_orders WHERE status NOT IN ('completed','cancelled') ORDER BY reported_at;
