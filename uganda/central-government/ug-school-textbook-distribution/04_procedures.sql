-- Purpose: record stock movements without allowing stock underflow or duplicate requests.
-- Engine: PostgreSQL 15+. Prerequisite: 01_schema.sql. Rerunnable.
CREATE OR REPLACE FUNCTION ug_textbooks.fn_record_movement(
 p_movement_ref TEXT,p_warehouse_ref TEXT,p_textbook_code TEXT,p_movement_type TEXT,p_quantity INTEGER,
 p_source_ref TEXT,p_reason TEXT,p_actor_ref TEXT,p_idempotency_key TEXT
) RETURNS BIGINT LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ug_textbooks AS $$
DECLARE v_wh BIGINT; v_book BIGINT; v_balance BIGINT; v_id BIGINT;
BEGIN
 IF p_quantity IS NULL OR p_quantity<=0 OR length(btrim(COALESCE(p_reason,'')))=0
 OR length(btrim(COALESCE(p_actor_ref,'')))=0 OR length(btrim(COALESCE(p_source_ref,'')))=0 THEN
  RAISE EXCEPTION 'Positive quantity, source, actor and reason are required' USING ERRCODE='invalid_parameter_value';
 END IF;
 SELECT warehouse_id INTO v_wh FROM ug_textbooks.warehouses WHERE warehouse_ref=p_warehouse_ref AND is_active FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Active warehouse not found' USING ERRCODE='no_data_found'; END IF;
 SELECT textbook_id INTO v_book FROM ug_textbooks.textbooks WHERE textbook_code=p_textbook_code AND is_active;
 IF NOT FOUND THEN RAISE EXCEPTION 'Active textbook not found' USING ERRCODE='no_data_found'; END IF;
 IF p_movement_type NOT IN ('opening','receipt','dispatch','return_in','write_off','correction') THEN
  RAISE EXCEPTION 'Unsupported movement type' USING ERRCODE='invalid_parameter_value';
 END IF;
 PERFORM 1 FROM ug_textbooks.stock_movements WHERE warehouse_id=v_wh AND textbook_id=v_book FOR UPDATE;
 SELECT COALESCE(SUM(quantity_delta),0) INTO v_balance FROM ug_textbooks.stock_movements
 WHERE warehouse_id=v_wh AND textbook_id=v_book;
 IF p_movement_type IN ('dispatch','write_off') AND v_balance<p_quantity THEN
  RAISE EXCEPTION 'Insufficient stock: available %, requested %',v_balance,p_quantity USING ERRCODE='check_violation';
 END IF;
 INSERT INTO ug_textbooks.stock_movements(movement_ref,warehouse_id,textbook_id,movement_type,quantity_delta,source_ref,reason,recorded_by,idempotency_key)
 VALUES(p_movement_ref,v_wh,v_book,p_movement_type,
   CASE WHEN p_movement_type IN ('dispatch','write_off') THEN -p_quantity ELSE p_quantity END,
   p_source_ref,p_reason,p_actor_ref,p_idempotency_key)
 RETURNING movement_id INTO v_id;
 RETURN v_id;
END; $$;
