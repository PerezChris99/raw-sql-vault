-- Purpose: append a validated stock movement and maintain non-negative balances.
-- Engine: PostgreSQL 15+.
-- SECURITY DEFINER permits an execute-only inventory role; deploy routine under
-- trusted ownership, with no runtime schema CREATE privileges and a fixed search_path.

CREATE OR REPLACE FUNCTION medicine_demo.fn_record_movement(
    p_facility_code TEXT,
    p_batch_number TEXT,
    p_product_code TEXT,
    p_quantity_delta BIGINT,
    p_reason TEXT,
    p_idempotency_key TEXT,
    p_source_reference TEXT DEFAULT NULL,
    p_actor_reference TEXT DEFAULT 'application'
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, medicine_demo
AS $function$
DECLARE
    v_facility_id BIGINT;
    v_batch_id BIGINT;
    v_expiry DATE;
    v_status TEXT;
    v_balance BIGINT;
    v_existing RECORD;
    v_movement_id BIGINT;
BEGIN
    IF p_quantity_delta IS NULL OR p_quantity_delta = 0 THEN
        RAISE EXCEPTION 'quantity delta must be non-zero' USING ERRCODE = '22023';
    END IF;
    IF p_reason IS NULL OR p_reason NOT IN ('receipt', 'issue', 'return_to_stock', 'wastage', 'adjustment') THEN
        RAISE EXCEPTION 'invalid movement reason' USING ERRCODE = '22023';
    END IF;
    IF (p_reason IN ('receipt', 'return_to_stock') AND p_quantity_delta < 0)
       OR (p_reason IN ('issue', 'wastage') AND p_quantity_delta > 0) THEN
        RAISE EXCEPTION 'reason % conflicts with delta %', p_reason, p_quantity_delta
            USING ERRCODE = '22023';
    END IF;
    IF NULLIF(btrim(p_idempotency_key), '') IS NULL OR NULLIF(btrim(p_actor_reference), '') IS NULL THEN
        RAISE EXCEPTION 'idempotency key and actor reference are required' USING ERRCODE = '22023';
    END IF;

    SELECT facility_id INTO v_facility_id
    FROM medicine_demo.facilities
    WHERE facility_code = btrim(p_facility_code) AND is_active = TRUE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'active facility % not found', p_facility_code USING ERRCODE = 'P0002';
    END IF;

    -- Batch row lock serializes movements against that lot.
    SELECT batch_id, expiry_date, batch_status INTO v_batch_id, v_expiry, v_status
    FROM medicine_demo.medicine_batches b
    JOIN medicine_demo.medicine_products p USING (product_id)
    WHERE b.batch_number = btrim(p_batch_number)
      AND p.product_code = btrim(p_product_code)
    FOR UPDATE OF b;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'medicine batch % for product % not found', p_batch_number, p_product_code
            USING ERRCODE = 'P0002';
    END IF;

    SELECT movement_id, facility_id, batch_id, quantity_delta, movement_reason
      INTO v_existing
    FROM medicine_demo.stock_movements
    WHERE idempotency_key = btrim(p_idempotency_key);
    IF FOUND THEN
        IF v_existing.facility_id <> v_facility_id OR v_existing.batch_id <> v_batch_id
           OR v_existing.quantity_delta <> p_quantity_delta OR v_existing.movement_reason <> p_reason THEN
            RAISE EXCEPTION 'idempotency key reused with different movement data'
                USING ERRCODE = '23505';
        END IF;
        RETURN v_existing.movement_id;
    END IF;

    IF p_reason = 'issue' AND (v_expiry < CURRENT_DATE OR v_status <> 'active') THEN
        RAISE EXCEPTION 'cannot issue expired or non-active batch %', p_batch_number
            USING ERRCODE = '23514';
    END IF;
    IF p_reason = 'receipt' AND (v_expiry < CURRENT_DATE OR v_status <> 'active') THEN
        RAISE EXCEPTION 'cannot receive into expired or non-active batch %', p_batch_number
            USING ERRCODE = '23514';
    END IF;
    IF p_reason = 'return_to_stock' AND (v_expiry < CURRENT_DATE OR v_status <> 'active') THEN
        RAISE EXCEPTION 'cannot return expired or non-active stock to usable inventory'
            USING ERRCODE = '23514';
    END IF;

    SELECT COALESCE(SUM(quantity_delta), 0)::BIGINT INTO v_balance
    FROM medicine_demo.stock_movements
    WHERE facility_id = v_facility_id AND batch_id = v_batch_id;

    IF v_balance + p_quantity_delta < 0 THEN
        RAISE EXCEPTION 'movement would make balance negative: current %, delta %',
            v_balance, p_quantity_delta USING ERRCODE = '23514';
    END IF;

    INSERT INTO medicine_demo.stock_movements
        (facility_id, batch_id, quantity_delta, movement_reason, idempotency_key, source_reference, actor_reference)
    VALUES
        (v_facility_id, v_batch_id, p_quantity_delta, p_reason,
         btrim(p_idempotency_key), p_source_reference, btrim(p_actor_reference))
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING movement_id INTO v_movement_id;

    IF v_movement_id IS NOT NULL THEN
        RETURN v_movement_id;
    END IF;

    SELECT movement_id, facility_id, batch_id, quantity_delta, movement_reason
      INTO v_existing
    FROM medicine_demo.stock_movements WHERE idempotency_key = btrim(p_idempotency_key);
    IF NOT FOUND OR v_existing.facility_id <> v_facility_id OR v_existing.batch_id <> v_batch_id
       OR v_existing.quantity_delta <> p_quantity_delta OR v_existing.movement_reason <> p_reason THEN
        RAISE EXCEPTION 'idempotency key raced with different movement data' USING ERRCODE = '23505';
    END IF;
    RETURN v_existing.movement_id;
END;
$function$;

REVOKE ALL ON FUNCTION medicine_demo.fn_record_movement(TEXT, TEXT, TEXT, BIGINT, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;

COMMENT ON FUNCTION medicine_demo.fn_record_movement(TEXT, TEXT, TEXT, BIGINT, TEXT, TEXT, TEXT, TEXT) IS
    'Appends a validated stock movement; adjustments and wastage need a reasoned approval workflow in real deployments.';