-- Purpose: serialise booking conflict checks and guard stock consumption.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_hospitality.fn_book_resource(
 p_reservation_ref TEXT,p_idempotency_key TEXT,p_resource_ref TEXT,p_customer_token TEXT,
 p_starts_at TIMESTAMPTZ,p_ends_at TIMESTAMPTZ,p_party_size INTEGER,p_source_ref TEXT,p_actor_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_hospitality AS $$
DECLARE r ug_hospitality.resources%ROWTYPE; v_id BIGINT;
BEGIN
 IF p_starts_at IS NULL OR p_ends_at IS NULL OR p_ends_at<=p_starts_at OR p_party_size IS NULL OR p_party_size<=0
 OR length(btrim(COALESCE(p_customer_token,'')))=0 OR length(btrim(COALESCE(p_actor_ref,'')))=0
 OR length(btrim(COALESCE(p_source_ref,'')))=0 THEN RAISE EXCEPTION 'Valid dates, party size, customer token, source and actor are required' USING ERRCODE='invalid_parameter_value'; END IF;
 SELECT * INTO r FROM ug_hospitality.resources WHERE resource_ref=p_resource_ref FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Resource not found' USING ERRCODE='no_data_found'; END IF;
 IF r.status<>'active' OR p_party_size>r.capacity THEN RAISE EXCEPTION 'Resource inactive or capacity exceeded' USING ERRCODE='check_violation'; END IF;
 IF EXISTS(SELECT 1 FROM ug_hospitality.reservations b WHERE b.resource_id=r.resource_id
 AND b.status IN ('requested','confirmed','checked_in') AND b.starts_at<p_ends_at AND b.ends_at>p_starts_at) THEN
  RAISE EXCEPTION 'Resource is already booked for an overlapping interval' USING ERRCODE='exclusion_violation';
 END IF;
 INSERT INTO ug_hospitality.reservations(reservation_ref,idempotency_key,resource_id,customer_token,starts_at,ends_at,party_size,status,source_ref,recorded_by_ref)
 VALUES(p_reservation_ref,p_idempotency_key,r.resource_id,p_customer_token,p_starts_at,p_ends_at,p_party_size,'confirmed',p_source_ref,p_actor_ref)
 RETURNING reservation_id INTO v_id;
 RETURN v_id;
END; $$;

CREATE OR REPLACE FUNCTION ug_hospitality.fn_consume_stock(
 p_movement_ref TEXT,p_idempotency_key TEXT,p_item_ref TEXT,p_quantity NUMERIC,p_source_ref TEXT,p_reason TEXT,p_actor_ref TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_hospitality AS $$
DECLARE i ug_hospitality.inventory_items%ROWTYPE; v_balance NUMERIC(14,3); v_id BIGINT;
BEGIN
 IF p_quantity IS NULL OR p_quantity<=0 OR length(btrim(COALESCE(p_source_ref,'')))=0
 OR length(btrim(COALESCE(p_reason,'')))=0 OR length(btrim(COALESCE(p_actor_ref,'')))=0 THEN
  RAISE EXCEPTION 'Positive quantity, source, reason and actor are required' USING ERRCODE='invalid_parameter_value'; END IF;
 SELECT * INTO i FROM ug_hospitality.inventory_items WHERE item_ref=p_item_ref AND is_active FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Active inventory item not found' USING ERRCODE='no_data_found'; END IF;
 SELECT COALESCE(SUM(quantity_delta),0) INTO v_balance FROM ug_hospitality.stock_movements WHERE item_id=i.item_id;
 IF v_balance<p_quantity THEN RAISE EXCEPTION 'Insufficient stock' USING ERRCODE='check_violation'; END IF;
 INSERT INTO ug_hospitality.stock_movements(movement_ref,idempotency_key,item_id,quantity_delta,movement_type,source_ref,reason,recorded_by_ref)
 VALUES(p_movement_ref,p_idempotency_key,i.item_id,-p_quantity,'order_consumption',p_source_ref,p_reason,p_actor_ref)
 RETURNING movement_id INTO v_id;
 RETURN v_id;
END; $$;
