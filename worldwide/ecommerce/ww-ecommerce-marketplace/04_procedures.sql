-- Purpose: atomically place a cart as an order, reserve stock and log status.
-- Engine: PostgreSQL 15+.
-- SECURITY DEFINER is required for a narrow EXECUTE-only application role.
-- Deploy with trusted ownership, no runtime CREATE rights on shop_demo, fixed path,
-- and narrow EXECUTE grants. This is a demonstrator, not a payment processor.

CREATE OR REPLACE FUNCTION shop_demo.fn_checkout(
    p_customer_id BIGINT,
    p_currency CHAR(3),
    p_items JSONB,
    p_idempotency_key TEXT
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, shop_demo
AS $function$
DECLARE
    v_order_id BIGINT;
    v_existing_customer BIGINT;
    v_existing_currency CHAR(3);
    v_existing_payload JSONB;
    v_line RECORD;
    v_product_price NUMERIC(18,2);
    v_product_currency CHAR(3);
    v_stock BIGINT;
    v_total NUMERIC(18,2) := 0;
BEGIN
    IF p_customer_id IS NULL OR p_currency IS NULL OR length(btrim(p_idempotency_key)) = 0
       OR p_idempotency_key IS NULL THEN
        RAISE EXCEPTION 'customer, currency and idempotency key are required' USING ERRCODE = '22023';
    END IF;
    IF jsonb_typeof(p_items) IS DISTINCT FROM 'array' OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'items must be a non-empty JSON array' USING ERRCODE = '22023';
    END IF;
    IF EXISTS (
        SELECT 1 FROM jsonb_array_elements(p_items) AS e(item)
        WHERE jsonb_typeof(e.item) IS DISTINCT FROM 'object'
           OR jsonb_typeof(e.item -> 'product_id') IS DISTINCT FROM 'number'
           OR jsonb_typeof(e.item -> 'quantity') IS DISTINCT FROM 'number'
    ) THEN
        RAISE EXCEPTION 'each item requires numeric product_id and quantity fields' USING ERRCODE = '22023';
    END IF;
    IF EXISTS (
        SELECT 1 FROM jsonb_array_elements(p_items) AS e(item)
        WHERE (e.item ->> 'product_id')::NUMERIC <= 0
           OR (e.item ->> 'product_id')::NUMERIC <> trunc((e.item ->> 'product_id')::NUMERIC)
           OR (e.item ->> 'quantity')::NUMERIC <= 0
           OR (e.item ->> 'quantity')::NUMERIC <> trunc((e.item ->> 'quantity')::NUMERIC)
           OR (e.item ->> 'quantity')::NUMERIC > 2147483647
    ) THEN
        RAISE EXCEPTION 'product ids and quantities must be positive integers in range' USING ERRCODE = '22023';
    END IF;

    -- Serialise retries for a key, including the same key submitted concurrently.
    PERFORM pg_advisory_xact_lock(hashtextextended(btrim(p_idempotency_key), 0));

    SELECT o.order_id, o.customer_id, o.currency, o.request_payload
      INTO v_order_id, v_existing_customer, v_existing_currency, v_existing_payload
    FROM shop_demo.orders o
    WHERE o.idempotency_key = btrim(p_idempotency_key);

    IF FOUND THEN
        IF v_existing_customer <> p_customer_id OR v_existing_currency <> p_currency
           OR v_existing_payload IS DISTINCT FROM p_items THEN
            RAISE EXCEPTION 'idempotency key reused with different checkout payload'
                USING ERRCODE = '23505';
        END IF;
        RETURN v_order_id;
    END IF;

    PERFORM 1 FROM shop_demo.customers c
    WHERE c.customer_id = p_customer_id AND c.is_active = TRUE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'active customer % not found', p_customer_id USING ERRCODE = '23503';
    END IF;

    -- Stable ascending product order reduces deadlock risk across multi-item carts.
    FOR v_line IN
        SELECT (e.item ->> 'product_id')::BIGINT AS product_id,
               SUM((e.item ->> 'quantity')::BIGINT) AS quantity
        FROM jsonb_array_elements(p_items) AS e(item)
        GROUP BY (e.item ->> 'product_id')::BIGINT
        ORDER BY (e.item ->> 'product_id')::BIGINT
    LOOP
        SELECT p.unit_price, p.currency, p.stock_quantity
          INTO v_product_price, v_product_currency, v_stock
        FROM shop_demo.products p
        WHERE p.product_id = v_line.product_id AND p.is_active = TRUE
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'active product % not found', v_line.product_id USING ERRCODE = '23503';
        END IF;
        IF v_product_currency <> p_currency THEN
            RAISE EXCEPTION 'cart currency does not match product currency for product %', v_line.product_id
                USING ERRCODE = '22023';
        END IF;
        IF v_stock < v_line.quantity THEN
            RAISE EXCEPTION 'insufficient stock for product %: available %, requested %',
                v_line.product_id, v_stock, v_line.quantity USING ERRCODE = '23514';
        END IF;

        UPDATE shop_demo.products
        SET stock_quantity = stock_quantity - v_line.quantity
        WHERE product_id = v_line.product_id;
        v_total := v_total + v_product_price * v_line.quantity;
    END LOOP;

    INSERT INTO shop_demo.orders
        (customer_id, currency, status, total_amount, idempotency_key, request_payload)
    VALUES (p_customer_id, p_currency, 'placed', v_total, btrim(p_idempotency_key), p_items)
    RETURNING order_id INTO v_order_id;

    INSERT INTO shop_demo.order_items(order_id, product_id, quantity, unit_price)
    SELECT v_order_id, cart.product_id, cart.quantity, p.unit_price
    FROM (
        SELECT (e.item ->> 'product_id')::BIGINT AS product_id,
               SUM((e.item ->> 'quantity')::BIGINT) AS quantity
        FROM jsonb_array_elements(p_items) AS e(item)
        GROUP BY (e.item ->> 'product_id')::BIGINT
    ) AS cart
    JOIN shop_demo.products p ON p.product_id = cart.product_id;

    INSERT INTO shop_demo.order_events(order_id, previous_status, new_status, actor_ref, event_note)
    VALUES (v_order_id, NULL, 'placed', 'checkout-service', 'Order placed and stock reserved');

    RETURN v_order_id;
END;
$function$;

REVOKE ALL ON FUNCTION shop_demo.fn_checkout(BIGINT, CHAR, JSONB, TEXT) FROM PUBLIC;

CREATE OR REPLACE FUNCTION shop_demo.fn_transition_order(
    p_order_id BIGINT,
    p_target_status TEXT,
    p_actor_ref TEXT
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, shop_demo
AS $function$
DECLARE
    v_status TEXT;
    v_item RECORD;
BEGIN
    IF p_target_status NOT IN ('placed', 'paid', 'fulfilled', 'cancelled')
       OR p_target_status IS NULL OR NULLIF(btrim(p_actor_ref), '') IS NULL THEN
        RAISE EXCEPTION 'invalid target status or actor reference' USING ERRCODE = '22023';
    END IF;

    SELECT status INTO v_status
    FROM shop_demo.orders WHERE order_id = p_order_id FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'order % not found', p_order_id USING ERRCODE = 'P0002'; END IF;
    IF v_status = p_target_status THEN RETURN p_order_id; END IF;

    IF NOT (
        (v_status = 'placed' AND p_target_status IN ('paid', 'cancelled'))
        OR (v_status = 'paid' AND p_target_status = 'fulfilled')
    ) THEN
        RAISE EXCEPTION 'order transition not allowed: % -> %', v_status, p_target_status
            USING ERRCODE = '23514';
    END IF;

    IF v_status = 'placed' AND p_target_status = 'cancelled' THEN
        FOR v_item IN
            SELECT product_id, quantity FROM shop_demo.order_items
            WHERE order_id = p_order_id ORDER BY product_id
        LOOP
            PERFORM 1 FROM shop_demo.products
            WHERE product_id = v_item.product_id FOR UPDATE;
            UPDATE shop_demo.products
            SET stock_quantity = stock_quantity + v_item.quantity
            WHERE product_id = v_item.product_id;
        END LOOP;
    END IF;

    UPDATE shop_demo.orders SET status = p_target_status WHERE order_id = p_order_id;
    INSERT INTO shop_demo.order_events(order_id, previous_status, new_status, actor_ref, event_note)
    VALUES (p_order_id, v_status, p_target_status, btrim(p_actor_ref), 'Status transition');
    RETURN p_order_id;
END;
$function$;

REVOKE ALL ON FUNCTION shop_demo.fn_transition_order(BIGINT, TEXT, TEXT) FROM PUBLIC;

COMMENT ON FUNCTION shop_demo.fn_checkout(BIGINT, CHAR, JSONB, TEXT) IS
    'Atomic checkout demo. Does not process payments, taxes, shipping or refunds.';
COMMENT ON FUNCTION shop_demo.fn_transition_order(BIGINT, TEXT, TEXT) IS
    'Transitions order state; cancelling a placed order restores its reserved stock once.';