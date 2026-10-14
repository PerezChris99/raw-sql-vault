-- Purpose: assert stock balance, idempotency, expired-lot and delta-sign invariants.
-- Engine: PostgreSQL 15+; run after the V0001 bootstrap migration.
-- Every test mutation is rolled back.
BEGIN;
DO $test$
DECLARE
    v_first BIGINT;
    v_second BIGINT;
    v_balance BIGINT;
    v_facility BIGINT;
    v_batch BIGINT;
BEGIN
    SELECT facility_id INTO v_facility FROM medicine_demo.facilities WHERE facility_code='DEMO-HF-001';
    SELECT batch_id INTO v_batch FROM medicine_demo.medicine_batches WHERE batch_number='DEMO-LOT-A';
    IF v_facility IS NULL OR v_batch IS NULL THEN RAISE EXCEPTION 'medicine fixtures missing'; END IF;

    DELETE FROM medicine_demo.stock_movements WHERE idempotency_key = 'TEST-MED-ISSUE-001';
    v_first := medicine_demo.fn_record_movement(
        'DEMO-HF-001', 'DEMO-LOT-A', 'DEMO-MED-001', -5, 'issue',
        'TEST-MED-ISSUE-001', 'synthetic-test', 'test-suite'
    );
    v_second := medicine_demo.fn_record_movement(
        'DEMO-HF-001', 'DEMO-LOT-A', 'DEMO-MED-001', -5, 'issue',
        'TEST-MED-ISSUE-001', 'synthetic-test', 'test-suite'
    );
    IF v_first <> v_second THEN RAISE EXCEPTION 'ASSERT repeated idempotency key returned different movement ids'; END IF;

    SELECT SUM(quantity_delta)::BIGINT INTO v_balance
    FROM medicine_demo.stock_movements WHERE facility_id=v_facility AND batch_id=v_batch;
    IF v_balance <> 95 THEN RAISE EXCEPTION 'ASSERT active batch expected 95 after one issue, got %', v_balance; END IF;

    BEGIN
        PERFORM medicine_demo.fn_record_movement(
            'DEMO-HF-001', 'DEMO-LOT-EXPIRED', 'DEMO-MED-001', -1, 'issue',
            'TEST-MED-EXPIRED-ISSUE', 'test', 'test-suite'
        );
        RAISE EXCEPTION 'ASSERT expired medicine issue was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    BEGIN
        PERFORM medicine_demo.fn_record_movement(
            'DEMO-HF-001', 'DEMO-LOT-A', 'DEMO-MED-001', -1, 'receipt',
            'TEST-MED-INVALID-SIGN', 'test', 'test-suite'
        );
        RAISE EXCEPTION 'ASSERT negative receipt delta was accepted';
    EXCEPTION WHEN invalid_parameter_value THEN NULL;
    END;

    BEGIN
        PERFORM medicine_demo.fn_record_movement(
            'DEMO-HF-001', 'DEMO-LOT-A', 'DEMO-MED-001', -9999, 'issue',
            'TEST-MED-UNDERFLOW', 'test', 'test-suite'
        );
        RAISE EXCEPTION 'ASSERT issue larger than stock was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    SELECT SUM(quantity_delta)::BIGINT INTO v_balance
    FROM medicine_demo.stock_movements WHERE facility_id=v_facility AND batch_id=v_batch;
    IF v_balance <> 95 THEN RAISE EXCEPTION 'ASSERT failed movement altered stock: %', v_balance; END IF;
END;
$test$;
ROLLBACK;