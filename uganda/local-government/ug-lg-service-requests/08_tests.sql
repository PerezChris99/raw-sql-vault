-- Purpose: verify state transitions and result constraints using rollback.
-- Engine: PostgreSQL 15+.
BEGIN;

DO $test$
DECLARE
    v_id BIGINT;
    v_status TEXT;
    v_events BIGINT;
BEGIN
    INSERT INTO service_demo.service_requests
        (request_ref, request_type, description, locality_id, priority, status, due_at)
    SELECT 'TEST-AUTOPILOT-SERVICE', 'other', 'Temporary service transition test.',
           l.locality_id, 3, 'new', now() + INTERVAL '1 day'
    FROM service_demo.localities l WHERE l.locality_code = 'DEMO-DISTRICT-001'
    ON CONFLICT (request_ref) DO UPDATE SET status = 'new', resolved_at = NULL
    RETURNING request_id INTO v_id;

    DELETE FROM service_demo.request_events WHERE request_id = v_id;
    PERFORM service_demo.fn_transition_request(v_id, 'triaged', 'valid transition', 'test-suite');
    PERFORM service_demo.fn_transition_request(v_id, 'triaged', 'idempotent retry', 'test-suite');

    SELECT status INTO v_status FROM service_demo.service_requests WHERE request_id = v_id;
    SELECT COUNT(*) INTO v_events FROM service_demo.request_events WHERE request_id = v_id;
    IF v_status <> 'triaged' OR v_events <> 1 THEN
        RAISE EXCEPTION 'ASSERT transition/idempotency failed: status %, events %', v_status, v_events;
    END IF;

    BEGIN
        PERFORM service_demo.fn_transition_request(v_id, 'new', 'invalid reverse', 'test-suite');
        RAISE EXCEPTION 'ASSERT invalid reverse transition was accepted';
    EXCEPTION WHEN check_violation THEN NULL;
    END;

    IF EXISTS (
        SELECT 1 FROM service_demo.service_requests
        WHERE request_id = v_id AND status = 'resolved' AND resolved_at IS NULL
    ) THEN RAISE EXCEPTION 'ASSERT resolved timestamp missing'; END IF;
END;
$test$;
ROLLBACK;