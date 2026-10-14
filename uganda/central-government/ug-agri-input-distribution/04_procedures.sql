-- Purpose: record traceable stock movements with lot-level locking and underflow protection.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql and 03_views.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_agri_inputs.fn_record_movement(
 p_movement_ref TEXT,p_idempotency_key TEXT,p_lot_ref TEXT,p_movement_type TEXT,p_quantity NUMERIC,
 p_recipient_ref TEXT,p_movement_at TIMESTAMPTZ,p_source_document_ref TEXT,p_reason TEXT,p_recorded_by TEXT
) RETURNS BIGINT
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_agri_inputs
AS $$
DECLARE v_lot ug_agri_inputs.lots%ROWTYPE; v_balance NUMERIC(14,3); v_id BIGINT;
BEGIN
 IF p_movement_type NOT IN ('received','issued','returned','writeoff') OR p_quantity IS NULL OR p_quantity<=0
    OR p_movement_at IS NULL OR length(btrim(COALESCE(p_source_document_ref,'')))=0
    OR length(btrim(COALESCE(p_reason,'')))=0 OR length(btrim(COALESCE(p_recorded_by,'')))=0 THEN
  RAISE EXCEPTION 'Valid movement type, positive quantity, timestamp, source, reason and actor are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 IF p_movement_type='issued' AND length(btrim(COALESCE(p_recipient_ref,'')))=0 THEN
  RAISE EXCEPTION 'Issued stock requires an opaque recipient reference' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT * INTO v_lot FROM ug_agri_inputs.lots WHERE lot_ref=p_lot_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Lot % not found',p_lot_ref USING ERRCODE='no_data_found'; END IF;
 IF v_lot.lot_status<>'available' AND p_movement_type IN ('issued','returned') THEN
  RAISE EXCEPTION 'Lot is not available for issue or return' USING ERRCODE='check_violation';
 END IF;
 IF v_lot.expires_on IS NOT NULL AND v_lot.expires_on<p_movement_at::date AND p_movement_type IN ('issued','returned') THEN
  RAISE EXCEPTION 'Expired lot cannot be issued or returned into usable stock' USING ERRCODE='check_violation';
 END IF;
 SELECT COALESCE(SUM(CASE WHEN movement_type IN ('received','returned') THEN quantity ELSE -quantity END),0)
 INTO v_balance FROM ug_agri_inputs.stock_movements WHERE lot_id=v_lot.lot_id;
 IF p_movement_type IN ('issued','writeoff') AND v_balance<p_quantity THEN
  RAISE EXCEPTION 'Movement would underflow lot balance; available %, requested %',v_balance,p_quantity USING ERRCODE='check_violation';
 END IF;
 INSERT INTO ug_agri_inputs.stock_movements(movement_ref,idempotency_key,lot_id,movement_type,quantity,recipient_ref,movement_at,source_document_ref,reason,recorded_by)
 VALUES(p_movement_ref,p_idempotency_key,v_lot.lot_id,p_movement_type,p_quantity,p_recipient_ref,p_movement_at,p_source_document_ref,p_reason,p_recorded_by)
 RETURNING movement_id INTO v_id;
 RETURN v_id;
END;
$$;
