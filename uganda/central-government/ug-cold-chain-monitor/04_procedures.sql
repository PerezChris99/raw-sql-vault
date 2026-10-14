-- Purpose: record temperature observations and control maintenance state transitions.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_cold_chain.fn_record_temperature(
 p_equipment_ref TEXT,p_reading_ref TEXT,p_idempotency_key TEXT,p_observed_at TIMESTAMPTZ,
 p_temperature_c NUMERIC,p_sensor_ref TEXT,p_source_reference TEXT,p_recorded_by TEXT
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,ug_cold_chain
AS $$
DECLARE v_equipment ug_cold_chain.equipment%ROWTYPE; v_reading_id BIGINT; v_calibration_current BOOLEAN;
        v_kind TEXT; v_severity TEXT;
BEGIN
 SELECT * INTO v_equipment FROM ug_cold_chain.equipment WHERE equipment_ref=p_equipment_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Equipment % not found',p_equipment_ref USING ERRCODE='no_data_found'; END IF;
 IF v_equipment.operational_status='retired' THEN
   RAISE EXCEPTION 'Cannot record routine reading for retired equipment' USING ERRCODE='check_violation';
 END IF;
 IF p_observed_at IS NULL OR length(btrim(COALESCE(p_sensor_ref,'')))=0
    OR length(btrim(COALESCE(p_source_reference,'')))=0 OR length(btrim(COALESCE(p_recorded_by,'')))=0 THEN
   RAISE EXCEPTION 'Observation time, sensor, source and actor are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 v_calibration_current:=v_equipment.calibration_due_on IS NULL OR v_equipment.calibration_due_on>=p_observed_at::date;
 INSERT INTO ug_cold_chain.temperature_readings(reading_ref,idempotency_key,equipment_id,observed_at,temperature_c,
   sensor_ref,source_reference,calibration_was_current,recorded_by)
 VALUES(p_reading_ref,p_idempotency_key,v_equipment.equipment_id,p_observed_at,p_temperature_c,
   p_sensor_ref,p_source_reference,v_calibration_current,p_recorded_by)
 RETURNING reading_id INTO v_reading_id;
 IF p_temperature_c<v_equipment.temperature_min_c THEN
   v_kind:='below_minimum';
 ELSIF p_temperature_c>v_equipment.temperature_max_c THEN
   v_kind:='above_maximum';
 END IF;
 IF v_kind IS NOT NULL THEN
   v_severity:=CASE WHEN abs(p_temperature_c-CASE WHEN v_kind='below_minimum' THEN v_equipment.temperature_min_c ELSE v_equipment.temperature_max_c END)>=10
                    THEN 'critical'
                    WHEN abs(p_temperature_c-CASE WHEN v_kind='below_minimum' THEN v_equipment.temperature_min_c ELSE v_equipment.temperature_max_c END)>=5
                    THEN 'high' ELSE 'moderate' END;
   INSERT INTO ug_cold_chain.excursions(reading_id,equipment_id,excursion_kind,severity)
   VALUES(v_reading_id,v_equipment.equipment_id,v_kind,v_severity);
 END IF;
 IF NOT v_calibration_current THEN
   UPDATE ug_cold_chain.equipment SET operational_status='quarantined'
   WHERE equipment_id=v_equipment.equipment_id AND operational_status='active';
 END IF;
 RETURN v_reading_id;
END;
$$;

CREATE OR REPLACE FUNCTION ug_cold_chain.fn_transition_work_order(
 p_work_order_ref TEXT,p_target_status TEXT,p_actor_ref TEXT,p_reason TEXT,p_evidence_reference TEXT DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=pg_catalog,ug_cold_chain
AS $$
DECLARE v_order ug_cold_chain.maintenance_orders%ROWTYPE; v_event_id BIGINT;
BEGIN
 IF length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_reason,'')))=0 THEN
   RAISE EXCEPTION 'Actor and reason are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_order FROM ug_cold_chain.maintenance_orders WHERE work_order_ref=p_work_order_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Work order % not found',p_work_order_ref USING ERRCODE='no_data_found'; END IF;
 IF NOT (
   (v_order.status='open' AND p_target_status IN ('assigned','cancelled')) OR
   (v_order.status='assigned' AND p_target_status IN ('in_progress','cancelled')) OR
   (v_order.status='in_progress' AND p_target_status IN ('completed','cancelled'))
 ) THEN RAISE EXCEPTION 'Invalid work order transition % -> %',v_order.status,p_target_status USING ERRCODE='check_violation'; END IF;
 IF p_target_status='completed' AND length(btrim(COALESCE(p_evidence_reference,'')))=0 THEN
   RAISE EXCEPTION 'Completion evidence reference is required' USING ERRCODE='check_violation';
 END IF;
 UPDATE ug_cold_chain.maintenance_orders SET status=p_target_status,
   completed_at=CASE WHEN p_target_status='completed' THEN clock_timestamp() ELSE completed_at END,
   completion_reference=CASE WHEN p_target_status='completed' THEN p_evidence_reference ELSE completion_reference END
 WHERE work_order_id=v_order.work_order_id;
 INSERT INTO ug_cold_chain.maintenance_events(work_order_id,from_status,to_status,actor_ref,reason,evidence_reference)
 VALUES(v_order.work_order_id,v_order.status,p_target_status,p_actor_ref,p_reason,p_evidence_reference)
 RETURNING event_id INTO v_event_id;
 RETURN v_event_id;
END;
$$;
