-- Purpose: serialize fuel event recording and reject odometer regressions.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_fleet.fn_record_fuel(
 p_fuel_ref TEXT,p_idempotency_key TEXT,p_vehicle_ref TEXT,p_supplier_ref TEXT,p_fuel_date TIMESTAMPTZ,
 p_quantity_litres NUMERIC,p_unit_price NUMERIC,p_odometer NUMERIC,p_receipt_ref TEXT,p_actor_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_fleet AS $$
DECLARE v ug_fleet.vehicles%ROWTYPE; v_latest NUMERIC(14,1); v_id BIGINT;
BEGIN
 IF p_quantity_litres IS NULL OR p_quantity_litres<=0 OR p_unit_price IS NULL OR p_unit_price<0
 OR p_odometer IS NULL OR p_odometer<0 OR p_fuel_date IS NULL OR length(btrim(COALESCE(p_actor_ref,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Fuel quantity, price, odometer, date, actor and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v FROM ug_fleet.vehicles WHERE vehicle_ref=p_vehicle_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Vehicle not found' USING ERRCODE='no_data_found'; END IF;
 IF v.status<>'active' THEN RAISE EXCEPTION 'Fuel event requires active vehicle status' USING ERRCODE='check_violation'; END IF;
 SELECT odometer_reading INTO v_latest FROM ug_fleet.fuel_events WHERE vehicle_id=v.vehicle_id
 ORDER BY fuel_date DESC,fuel_event_id DESC LIMIT 1;
 IF v_latest IS NOT NULL AND p_odometer<v_latest THEN RAISE EXCEPTION 'Odometer reading regressed' USING ERRCODE='check_violation'; END IF;
 INSERT INTO ug_fleet.fuel_events(fuel_ref,idempotency_key,vehicle_id,supplier_ref,fuel_date,quantity_litres,unit_price,odometer_reading,receipt_ref,recorded_by_ref,evidence_ref)
 VALUES(p_fuel_ref,p_idempotency_key,v.vehicle_id,p_supplier_ref,p_fuel_date,p_quantity_litres,p_unit_price,p_odometer,p_receipt_ref,p_actor_ref,p_evidence_ref)
 RETURNING fuel_event_id INTO v_id;
 INSERT INTO ug_fleet.audit_events(vehicle_id,event_type,actor_ref,reason,evidence_ref)
 VALUES(v.vehicle_id,'fuel_recorded',p_actor_ref,'Fuel event recorded: '||p_fuel_ref,p_evidence_ref);
 RETURN v_id;
END; $$;
