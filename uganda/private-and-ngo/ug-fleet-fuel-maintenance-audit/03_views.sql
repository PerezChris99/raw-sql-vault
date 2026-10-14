-- Purpose: fuel cost, odometer gaps, maintenance queue and exception candidates.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE VIEW ug_fleet.v_fuel_summary AS
SELECT v.vehicle_ref,v.vehicle_type,COUNT(f.fuel_event_id) AS fuel_events,
 COALESCE(SUM(f.quantity_litres),0) AS litres_issued,
 COALESCE(SUM(f.quantity_litres*f.unit_price),0)::NUMERIC(16,2) AS total_fuel_cost,
 MIN(f.fuel_date) AS first_fuel_event,MAX(f.fuel_date) AS latest_fuel_event
FROM ug_fleet.vehicles v LEFT JOIN ug_fleet.fuel_events f USING(vehicle_id)
GROUP BY v.vehicle_id,v.vehicle_ref,v.vehicle_type;

CREATE OR REPLACE VIEW ug_fleet.v_fuel_anomaly_candidates AS
WITH ordered AS (
 SELECT f.*,LAG(odometer_reading) OVER(PARTITION BY vehicle_id ORDER BY fuel_date,fuel_event_id) AS prior_odometer,
        LAG(fuel_date) OVER(PARTITION BY vehicle_id ORDER BY fuel_date,fuel_event_id) AS prior_date
 FROM ug_fleet.fuel_events f
)
SELECT v.vehicle_ref,o.fuel_ref,o.fuel_date,o.quantity_litres,o.unit_price,o.odometer_reading,o.prior_odometer,
 CASE WHEN o.prior_odometer IS NOT NULL AND o.odometer_reading<o.prior_odometer THEN 'odometer_regression'
      WHEN o.prior_odometer IS NOT NULL AND o.odometer_reading=o.prior_odometer THEN 'no_distance_since_prior_event'
      WHEN o.quantity_litres>150 THEN 'large_fuel_quantity_review'
      ELSE 'review_context' END AS candidate_reason
FROM ordered o JOIN ug_fleet.vehicles v USING(vehicle_id)
WHERE (o.prior_odometer IS NOT NULL AND o.odometer_reading<=o.prior_odometer) OR o.quantity_litres>150;

CREATE OR REPLACE VIEW ug_fleet.v_maintenance_queue AS
SELECT v.vehicle_ref,m.maintenance_ref,m.issue_category,m.priority,m.reported_at,m.odometer_reading,m.status
FROM ug_fleet.maintenance_orders m JOIN ug_fleet.vehicles v USING(vehicle_id)
WHERE m.status NOT IN ('completed','cancelled');
