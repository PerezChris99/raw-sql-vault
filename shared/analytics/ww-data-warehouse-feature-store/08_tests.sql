-- Purpose: verify batch load idempotency and point-in-time feature correctness.
-- Engine: PostgreSQL 15+.
-- Transaction is rolled back so tests can be repeated without accumulating facts.

BEGIN;
DO $test$
DECLARE
    v_batch UUID := '11111111-1111-4111-8111-111111111111';
    v_first BIGINT;
    v_second BIGINT;
    v_count BIGINT;
    v_total NUMERIC;
    v_feature NUMERIC;
    v_feature_time TIMESTAMPTZ;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM analytics_demo.v_staging_sales_quality
    WHERE batch_id = v_batch AND quality_status <> 'accepted';
    IF v_count <> 0 THEN RAISE EXCEPTION 'fixture batch has rejected rows: %', v_count; END IF;

    v_first := analytics_demo.fn_load_sales_batch(v_batch);
    v_second := analytics_demo.fn_load_sales_batch(v_batch);
    IF v_first <> 3 OR v_second <> 0 THEN
        RAISE EXCEPTION 'ASSERT load idempotency failed: first %, second %', v_first, v_second;
    END IF;

    SELECT COUNT(*), SUM(amount) INTO v_count, v_total
    FROM analytics_demo.fact_sales WHERE batch_id = v_batch;
    IF v_count <> 3 OR v_total <> 17000.00 THEN
        RAISE EXCEPTION 'ASSERT loaded fact values wrong: count %, total %', v_count, v_total;
    END IF;

    SELECT numeric_value, feature_timestamp INTO v_feature, v_feature_time
    FROM analytics_demo.fn_features_as_of(
        'product', 'DEMO-SKU-001', TIMESTAMPTZ '2026-10-12 23:59:59+00'
    )
    WHERE feature_name = 'avg_units_7d';

    IF v_feature IS DISTINCT FROM 12.5
       OR v_feature_time IS DISTINCT FROM TIMESTAMPTZ '2026-10-10 00:00:00+00' THEN
        RAISE EXCEPTION 'ASSERT point-in-time cutoff failed: value %, timestamp %', v_feature, v_feature_time;
    END IF;
END;
$test$;
ROLLBACK;