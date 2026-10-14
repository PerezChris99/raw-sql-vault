-- Purpose: fail loudly when a correctness invariant is violated.
-- Engine: PostgreSQL 15+ with PostGIS; run after test fixtures.
-- No real data is used. DO blocks raise exceptions on failure.

DO $test$
DECLARE
    v_count BIGINT;
    v_revenue NUMERIC;
    v_band TEXT;
    v_rolling NUMERIC;
    v_pair_count BIGINT;
    v_first_count BIGINT;
    v_second_count BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_count FROM vault_demo.v_sales_countable;
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'ASSERT sales filter failed: expected 4 rows, got %', v_count;
    END IF;

    SELECT SUM(sale_count), SUM(revenue)
      INTO v_count, v_revenue
    FROM vault_demo.fn_sales_by_day(DATE '2024-01-01', DATE '2024-01-31');
    IF v_count <> 3 OR v_revenue <> 80.00 THEN
        RAISE EXCEPTION 'ASSERT inclusive date range failed: count %, revenue %',
            v_count, v_revenue;
    END IF;

    SELECT revenue, sale_count INTO v_revenue, v_count
    FROM vault_demo.fn_sales_by_day(DATE '2024-01-31', DATE '2024-01-31')
    WHERE sale_day = DATE '2024-01-31';
    IF v_count <> 1 OR v_revenue <> 50.00 THEN
        RAISE EXCEPTION 'ASSERT end-day 23:59:59 transaction was lost';
    END IF;

    SELECT score_band INTO v_band
    FROM vault_demo.v_customer_score_banded
    WHERE display_name = 'Synthetic Customer B';
    IF v_band IS DISTINCT FROM 'unknown' THEN
        RAISE EXCEPTION 'ASSERT NULL score must be unknown, got %', v_band;
    END IF;

    SELECT revenue_7_calendar_days INTO v_rolling
    FROM vault_demo.v_sales_rolling_7d
    WHERE sale_day = DATE '2024-01-31';
    IF v_rolling IS DISTINCT FROM 80.00 THEN
        RAISE EXCEPTION 'ASSERT seven-day window for 2024-01-31 expected 80, got %', v_rolling;
    END IF;

    SELECT revenue_7_calendar_days INTO v_rolling
    FROM vault_demo.v_sales_rolling_7d
    WHERE sale_day = DATE '2024-02-01';
    IF v_rolling IS DISTINCT FROM 170.00 THEN
        RAISE EXCEPTION 'ASSERT seven-day window for 2024-02-01 expected 170, got %', v_rolling;
    END IF;

    SELECT COUNT(*) INTO v_pair_count
    FROM vault_demo.v_spatial_duplicate_pairs;
    IF v_pair_count <> 1 THEN
        RAISE EXCEPTION 'ASSERT spatial pairing expected one candidate, got %', v_pair_count;
    END IF;

    IF EXISTS (
        SELECT 1 FROM vault_demo.v_spatial_duplicate_pairs WHERE a_id >= b_id
    ) THEN
        RAISE EXCEPTION 'ASSERT spatial pairs are not canonically ordered';
    END IF;

    SELECT COUNT(*) INTO v_first_count
    FROM vault_demo.fn_insert_users_batch(
        ARRAY['Synthetic Batch A', 'Synthetic Batch B'],
        ARRAY['synthetic-a@example.test', 'synthetic-b@example.test']
    );
    SELECT COUNT(*) INTO v_second_count
    FROM vault_demo.fn_insert_users_batch(
        ARRAY['Synthetic Batch A', 'Synthetic Batch B'],
        ARRAY['synthetic-a@example.test', 'synthetic-b@example.test']
    );
    IF v_first_count <> 2 OR v_second_count <> 0 THEN
        RAISE EXCEPTION 'ASSERT batch idempotency failed: first %, second %',
            v_first_count, v_second_count;
    END IF;

    BEGIN
        PERFORM * FROM vault_demo.fn_insert_users_batch(
            ARRAY['Mismatched'], ARRAY['one@example.test', 'two@example.test']
        );
        RAISE EXCEPTION 'ASSERT unequal input lengths were not rejected';
    EXCEPTION WHEN SQLSTATE '2202E' THEN
        NULL; -- Expected validation error.
    END;

    RAISE NOTICE 'PASS: six correctness patterns and negative input case';
END;
$test$;