-- Purpose: record pickup outcomes and prevent duplicate source submissions.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_waste.fn_record_pickup(
 p_pickup_ref TEXT,p_idempotency_key TEXT,p_shift_ref TEXT,p_stop_ref TEXT,p_outcome TEXT,
 p_volume NUMERIC,p_unit_code TEXT,p_occurred_at TIMESTAMPTZ,p_actor_ref TEXT,p_evidence_ref TEXT,p_exception_reason TEXT DEFAULT NULL
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_waste AS $$
DECLARE sh ug_waste.shifts%ROWTYPE; st ug_waste.route_stops%ROWTYPE; v_id BIGINT;
BEGIN
 IF p_outcome NOT IN ('collected','partial','missed','blocked','unsafe_to_collect')
 OR p_occurred_at IS NULL OR length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Valid outcome, timestamp, actor and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 IF p_outcome IN ('missed','blocked','unsafe_to_collect') AND length(btrim(COALESCE(p_exception_reason,'')))=0 THEN
  RAISE EXCEPTION 'Exception reason is required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO sh FROM ug_waste.shifts WHERE shift_ref=p_shift_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Shift not found' USING ERRCODE='no_data_found'; END IF;
 IF sh.status NOT IN ('active','completed') THEN RAISE EXCEPTION 'Pickup requires an active or completed shift' USING ERRCODE='check_violation'; END IF;
 SELECT * INTO st FROM ug_waste.route_stops WHERE stop_ref=p_stop_ref AND route_id=sh.route_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Stop does not belong to shift route' USING ERRCODE='foreign_key_violation'; END IF;
 INSERT INTO ug_waste.pickup_events(pickup_ref,idempotency_key,shift_id,stop_id,outcome,volume_estimate,unit_code,occurred_at,recorded_by_ref,evidence_ref,exception_reason)
 VALUES(p_pickup_ref,p_idempotency_key,sh.shift_id,st.stop_id,p_outcome,p_volume,p_unit_code,p_occurred_at,p_actor_ref,p_evidence_ref,p_exception_reason)
 RETURNING pickup_id INTO v_id;
 RETURN v_id;
END; $$;
