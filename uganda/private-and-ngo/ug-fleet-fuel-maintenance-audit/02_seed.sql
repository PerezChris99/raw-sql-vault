-- Purpose: synthetic fleet records. Safe to rerun.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql.
INSERT INTO ug_fleet.vehicles(vehicle_ref,vehicle_type,fuel_type,locality_ref,status)
VALUES('UGVEH-DEMO-01','light_truck','diesel','SYN-LOCALITY-01','active')
ON CONFLICT(vehicle_ref) DO NOTHING;
INSERT INTO ug_fleet.fuel_events(fuel_ref,idempotency_key,vehicle_id,supplier_ref,fuel_date,quantity_litres,unit_price,odometer_reading,receipt_ref,recorded_by_ref,evidence_ref)
SELECT 'UGFUEL-DEMO-001','fleet-fuel-demo-idem-001',vehicle_id,'SYN-FUEL-SUPPLIER',TIMESTAMPTZ '2026-10-01 10:00:00+03',40,5200,12500,'SYN-FUEL-RECEIPT-001','SYN-FLEET-CLERK','SYN-FUEL-EVIDENCE-001'
FROM ug_fleet.vehicles WHERE vehicle_ref='UGVEH-DEMO-01'
ON CONFLICT(fuel_ref) DO NOTHING;
