-- Purpose: validate checkout's idempotency, stock and rollback guarantees.
-- Engine: PostgreSQL 15+.
-- Test changes are rolled back after assertions.

BEGIN;
DO $test$
DECLARE
    v_customer BIGINT;
    v_product BIGINT;
    v_before BIGINT;
    v_after BIGINT;
    v_order_a BIGINT;
    v_order_b BIGINT;
    v_total NUMERIC;
    v_status TEXT;
    v_cart JSONB;
BEGIN
    SELECT customer_id INTO v_customer FROM shop_demo.customers
    WHERE customer_ref = 'TEST-CHECKOUT-CUSTOMER';
    SELECT product_id, stock_quantity INTO v_product, v_before
    FROM shop_demo.products WHERE sku = 'TEST-CHECKOUT-ITEM' FOR UPDATE;
    IF v_customer IS NULL OR v_product IS NULL THEN
        RAISE EXCEPTION 'test customer or product seed missing';
    END IF;

    DELETE FROM shop_demo.order_events WHERE order_id IN
        (SELECT order_id FROM shop_demo.orders WHERE idempotency_key LIKE 'TEST-AUTOPILOT-%');
    DELETE FROM shop_demo.order_items WHERE order_id IN
        (SELECT order_id FROM shop_demo.orders WHERE idempotency_key LIKE 'TEST-AUTOPILOT-%');
    DELETE FROM shop_demo.orders WHERE idempotency_key LIKE 'TEST-AUTOPILOT-%';
    UPDATE shop_demo.products SET stock_quantity = 10 WHERE product_id = v_product;
    v_before := 10;
    v_cart := jsonb_build_array(jsonb_build_object('product_id', v_product, 'quantity', 2));

    v_order_a := shop_demo.fn_checkout(
        v_customer, 'UGX', v_cart, 'TEST-AUTOPILOT-CHECKOUT'
    );
    v_order_b := shop_demo.fn_checkout(
        v_customer, 'UGX', v_cart, 'TEST-AUTOPILOT-CHECKOUT'
    );

    SELECT stock_quantity INTO v_after FROM shop_demo.products WHERE product_id = v_product;
    SELECT total_amount INTO v_total FROM shop_demo.orders WHERE order_id = v_order_a;
    IF v_order_a <> v_order_b OR v_after <> 8 OR v_total <> 2000.00 THEN
        RAISE EXCEPTION 'ASSERT checkout idempotency failed: ids %, %, stock %, total %',
            v_order_a, v_order_b, v_after, v_total;
    END IF;

    PERFORM shop_demo.fn_transition_order(v_order_a, 'cancelled', 'test-suite');
    PERFORM shop_demo.fn_transition_order(v_order_a, 'cancelled', 'test-suite retry');
    SELECT stock_quantity INTO v_after FROM shop_demo.products WHERE product_id = v_product;
    SELECT status INTO v_status FROM shop_demo.orders WHERE order_id = v_order_a;
    IF v_after <> 10 OR v_status <> 'cancelled' THEN
        RAISE EXCEPTION 'ASSERT cancellation restoration failed: stock %, status %', v_after, v_status;
    END IF;

    BEGIN
        PERFORM shop_demo.fn_checkout(
            v_customer, 'UGX',
            jsonb_build_array(jsonb_build_object('product_id', v_product, 'quantity', 1000)),
            'TEST-AUTOPILOT-OVERSELL'
        );
        RAISE EXCEPTION 'ASSERT oversized cart was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    SELECT stock_quantity INTO v_after FROM shop_demo.products WHERE product_id = v_product;
    IF v_after <> 10 OR EXISTS (
        SELECT 1 FROM shop_demo.orders WHERE idempotency_key = 'TEST-AUTOPILOT-OVERSELL'
    ) THEN
        RAISE EXCEPTION 'ASSERT failed checkout partially committed';
    END IF;
END;
$test$;
ROLLBACK;