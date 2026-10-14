-- Purpose: record authorised departure observations with idempotency and route/stop consistency.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_transport.fn_record_observation(
 p_observation_ref TEXT,p_idempotency_key TEXT,p_schedule_ref TEXT,p_observation_status TEXT,
 p_observed_at TIMESTAMPTZ,p_delay_minutes INTEGER,p_source_type TEXT,p_source_ref TEXT,p_actor_ref TEXT,p_evidence_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_transport AS $$
DECLARE s ug_transport.departure_schedules%ROWTYPE; v_id BIGINT;
BEGIN
 IF p_observation_status NOT IN ('departed','delayed','cancelled','not_observed')
 OR p_source_type NOT IN ('authorised_manual','operator_report','approved_sensor','survey')
 OR length(btrim(COALESCE(p_source_ref,'')))=0 OR length(btrim(COALESCE(p_actor_ref,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Valid status, source, actor and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 IF p_observation_status<>'not_observed' AND p_observed_at IS NULL THEN
  RAISE EXCEPTION 'Observation timestamp is required' USING ERRCODE='invalid_parameter_value';
 END IF;
 IF p_observation_status IN ('departed','delayed') AND (p_delay_minutes IS NULL OR p_delay_minutes<0) THEN
  RAISE EXCEPTION 'Departure delay must be a non-negative minute value' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO s FROM ug_transport.departure_schedules WHERE schedule_ref=p_schedule_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Schedule not found' USING ERRCODE='no_data_found'; END IF;
 IF s.status IN ('cancelled','missed') THEN RAISE EXCEPTION 'Schedule already closed as cancelled/missed' USING ERRCODE='check_violation'; END IF;
 INSERT INTO ug_transport.departure_observations(observation_ref,idempotency_key,schedule_id,observed_at,observation_status,delay_minutes,source_type,source_ref,recorded_by_ref,evidence_ref)
 VALUES(p_observation_ref,p_idempotency_key,s.schedule_id,p_observed_at,p_observation_status,p_delay_minutes,p_source_type,p_source_ref,p_actor_ref,p_evidence_ref)
 RETURNING observation_id INTO v_id;
 UPDATE ug_transport.departure_schedules SET status=CASE WHEN p_observation_status='not_observed' THEN status ELSE 'observed' END
 WHERE schedule_id=s.schedule_id;
 RETURN v_id;
END; $$;
