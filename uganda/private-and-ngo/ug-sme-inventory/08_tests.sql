-- Purpose: verify movement idempotency and prevent negative stock.
-- Engine: PostgreSQL 15+.
-- Entire test is rolled back so no test movement remains in the fixture ledger.

BEGIN;
DO $test$
DECLARE
    v_before BIGINT;
    v_after BIGINT;
    v_first_id BIGINT;
    v_second_id BIGINT;
    v_product_id BIGINT;
BEGIN
    SELECT product_id INTO v_product_id
    FROM sme_stock_demo.products WHERE sku = 'DEMO-TEA-UG' FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'synthetic product seed missing'; END IF;

    DELETE FROM sme_stock_demo.stock_movements
    WHERE idempotency_key = 'TEST-AUTOPILOT-STOCK-RECEIPT';

    SELECT COALESCE(SUM(quantity_delta), 0)::BIGINT INTO v_before
    FROM sme_stock_demo.stock_movements WHERE product_id = v_product_id;

    v_first_id := sme_stock_demo.fn_record_stock_movement(
        'DEMO-TEA-UG', 5, 'receipt', 'TEST-AUTOPILOT-STOCK-RECEIPT', 'test', 'test-suite'
    );
    v_second_id := sme_stock_demo.fn_record_stock_movement(
        'DEMO-TEA-UG', 5, 'receipt', 'TEST-AUTOPILOT-STOCK-RECEIPT', 'test', 'test-suite'
    );

    SELECT COALESCE(SUM(quantity_delta), 0)::BIGINT INTO v_after
    FROM sme_stock_demo.stock_movements WHERE product_id = v_product_id;

    IF v_first_id <> v_second_id OR v_after <> v_before + 5 THEN
        RAISE EXCEPTION 'ASSERT idempotency failed: ids %, %, stock before %, after %',
            v_first_id, v_second_id, v_before, v_after;
    END IF;

    BEGIN
        PERFORM sme_stock_demo.fn_record_stock_movement(
            'DEMO-TEA-UG', -999999, 'sale', 'TEST-AUTOPILOT-STOCK-UNDERFLOW', 'test', 'test-suite'
        );
        RAISE EXCEPTION 'ASSERT negative stock movement was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    SELECT COALESCE(SUM(quantity_delta), 0)::BIGINT INTO v_after
    FROM sme_stock_demo.stock_movements WHERE product_id = v_product_id;
    IF v_after <> v_before + 5 THEN
        RAISE EXCEPTION 'ASSERT underflow rejection changed the balance';
    END IF;
END;
$test$;
ROLLBACK;