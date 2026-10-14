-- Purpose: idempotent aid delivery recording bounded by approved authorisation quantity.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_aid.fn_record_delivery(
 p_delivery_ref TEXT,p_idempotency_key TEXT,p_authorisation_ref TEXT,p_quantity NUMERIC,p_status TEXT,
 p_delivered_at TIMESTAMPTZ,p_point_ref TEXT,p_actor_ref TEXT,p_evidence_ref TEXT,p_exception_reason TEXT DEFAULT NULL
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_aid AS $$
DECLARE a ug_aid.authorisations%ROWTYPE; r ug_aid.recipients%ROWTYPE; v_delivered NUMERIC(14,3); v_id BIGINT;
BEGIN
 IF p_quantity IS NULL OR p_quantity<=0 OR p_status NOT IN ('delivered','partial','failed','returned')
 OR p_delivered_at IS NULL OR length(btrim(COALESCE(p_point_ref,'')))=0 OR length(btrim(COALESCE(p_actor_ref,'')))=0
 OR length(btrim(COALESCE(p_evidence_ref,'')))=0 THEN
  RAISE EXCEPTION 'Quantity, status, timestamp, point, actor and evidence are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 IF p_status IN ('failed','returned') AND length(btrim(COALESCE(p_exception_reason,'')))=0 THEN
  RAISE EXCEPTION 'Failed/returned delivery requires a reason' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO a FROM ug_aid.authorisations WHERE authorisation_ref=p_authorisation_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Authorisation not found' USING ERRCODE='no_data_found'; END IF;
 IF a.decision<>'approved' THEN RAISE EXCEPTION 'Delivery requires human-approved authorisation' USING ERRCODE='check_violation'; END IF;
 SELECT * INTO r FROM ug_aid.recipients WHERE recipient_id=a.recipient_id FOR UPDATE;
 IF r.status<>'active' THEN RAISE EXCEPTION 'Recipient token is not active' USING ERRCODE='check_violation'; END IF;
 IF p_status IN ('delivered','partial') THEN
  SELECT COALESCE(SUM(quantity_delivered),0) INTO v_delivered FROM ug_aid.deliveries
  WHERE authorisation_id=a.authorisation_id AND delivery_status IN ('delivered','partial');
  IF v_delivered+p_quantity>a.quantity THEN RAISE EXCEPTION 'Delivery exceeds approved quantity' USING ERRCODE='check_violation'; END IF;
 END IF;
 INSERT INTO ug_aid.deliveries(delivery_ref,idempotency_key,authorisation_id,quantity_delivered,delivery_status,delivered_at,delivery_point_ref,recorded_by_ref,evidence_ref,exception_reason)
 VALUES(p_delivery_ref,p_idempotency_key,a.authorisation_id,p_quantity,p_status,p_delivered_at,p_point_ref,p_actor_ref,p_evidence_ref,p_exception_reason)
 RETURNING delivery_id INTO v_id;
 INSERT INTO ug_aid.audit_events(entity_type,entity_ref,event_type,actor_ref,reason_redacted,evidence_ref)
 VALUES('delivery',p_delivery_ref,p_status,p_actor_ref,'Aid delivery outcome recorded',p_evidence_ref);
 RETURN v_id;
END; $$;
