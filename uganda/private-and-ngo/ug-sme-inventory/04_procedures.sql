-- Purpose: append a validated stock movement with product locking/idempotency.
-- Engine: PostgreSQL 15+; requires 01_schema.sql.
-- Rerun safety: CREATE OR REPLACE FUNCTION.
-- SECURITY DEFINER is used intentionally so runtime roles can receive EXECUTE
-- without direct ledger writes. Deploy as a trusted owner; do not grant runtime
-- roles schema CREATE, table ownership, or function replacement privileges.

CREATE OR REPLACE FUNCTION sme_stock_demo.fn_record_stock_movement(
    p_sku TEXT,
    p_quantity_delta INTEGER,
    p_reason TEXT,
    p_idempotency_key TEXT,
    p_source_ref TEXT DEFAULT NULL,
    p_actor_ref TEXT DEFAULT 'application'
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, sme_stock_demo
AS $function$
DECLARE
    v_product_id BIGINT;
    v_existing_id BIGINT;
    v_existing_product BIGINT;
    v_existing_delta INTEGER;
    v_existing_reason TEXT;
    v_on_hand BIGINT;
    v_new_id BIGINT;
BEGIN
    IF p_quantity_delta IS NULL OR p_quantity_delta = 0 THEN
        RAISE EXCEPTION 'quantity delta must be a non-zero integer' USING ERRCODE = '22023';
    END IF;
    IF p_reason IS NULL OR p_reason NOT IN ('receipt', 'sale', 'return', 'adjustment') THEN
        RAISE EXCEPTION 'invalid stock movement reason' USING ERRCODE = '22023';
    END IF;
    IF (p_reason IN ('receipt', 'return') AND p_quantity_delta < 0)
       OR (p_reason = 'sale' AND p_quantity_delta > 0) THEN
        RAISE EXCEPTION 'movement reason % conflicts with quantity delta %',
            p_reason, p_quantity_delta USING ERRCODE = '22023';
    END IF;
    IF NULLIF(btrim(p_idempotency_key), '') IS NULL OR NULLIF(btrim(p_actor_ref), '') IS NULL THEN
        RAISE EXCEPTION 'idempotency key and actor reference are required' USING ERRCODE = '22023';
    END IF;

    SELECT p.product_id INTO v_product_id
    FROM sme_stock_demo.products p
    WHERE p.sku = btrim(p_sku) AND p.is_active = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'active SKU % not found', p_sku USING ERRCODE = 'P0002';
    END IF;

    -- Recheck under the product lock so retries see a prior committed movement.
    SELECT m.movement_id, m.product_id, m.quantity_delta, m.reason
      INTO v_existing_id, v_existing_product, v_existing_delta, v_existing_reason
    FROM sme_stock_demo.stock_movements m
    WHERE m.idempotency_key = btrim(p_idempotency_key);

    IF FOUND THEN
        IF v_existing_product <> v_product_id
           OR v_existing_delta <> p_quantity_delta
           OR v_existing_reason <> p_reason THEN
            RAISE EXCEPTION 'idempotency key reused with different movement data'
                USING ERRCODE = '23505';
        END IF;
        RETURN v_existing_id;
    END IF;

    SELECT COALESCE(SUM(m.quantity_delta), 0)::BIGINT INTO v_on_hand
    FROM sme_stock_demo.stock_movements m
    WHERE m.product_id = v_product_id;

    IF v_on_hand + p_quantity_delta < 0 THEN
        RAISE EXCEPTION 'movement would make stock negative: SKU %, current %, delta %',
            p_sku, v_on_hand, p_quantity_delta USING ERRCODE = '23514';
    END IF;

    INSERT INTO sme_stock_demo.stock_movements
        (product_id, quantity_delta, reason, idempotency_key, source_ref, actor_ref)
    VALUES
        (v_product_id, p_quantity_delta, p_reason, btrim(p_idempotency_key), p_source_ref, btrim(p_actor_ref))
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING movement_id INTO v_new_id;

    IF v_new_id IS NOT NULL THEN
        RETURN v_new_id;
    END IF;

    -- A concurrent caller may have used this key against another product.
    SELECT m.movement_id, m.product_id, m.quantity_delta, m.reason
      INTO v_existing_id, v_existing_product, v_existing_delta, v_existing_reason
    FROM sme_stock_demo.stock_movements m
    WHERE m.idempotency_key = btrim(p_idempotency_key);

    IF NOT FOUND OR v_existing_product <> v_product_id
       OR v_existing_delta <> p_quantity_delta OR v_existing_reason <> p_reason THEN
        RAISE EXCEPTION 'idempotency key conflict with different movement data'
            USING ERRCODE = '23505';
    END IF;
    RETURN v_existing_id;
END;
$function$;

REVOKE ALL ON FUNCTION sme_stock_demo.fn_record_stock_movement(TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;

COMMENT ON FUNCTION sme_stock_demo.fn_record_stock_movement(TEXT, INTEGER, TEXT, TEXT, TEXT, TEXT) IS
    'Appends a validated stock event; execute as a controlled runtime role and review the definer owner.';