-- Purpose: verify the action state machine and history with rolled-back synthetic data.
-- Engine: PostgreSQL 15+; run after 01_schema.sql, 02_seed.sql and 04_procedures.sql.
-- Destructive: no; all assertions run in a transaction that is rolled back.
BEGIN;

DO $test$
DECLARE
    v_action_id BIGINT;
    v_status TEXT;
    v_events BIGINT;
BEGIN
    INSERT INTO opm_demo.programme_actions
        (reference_code, title, sponsor_department_id, owner_department_id, status, created_by_ref)
    SELECT 'TEST-AUTOPILOT-ACTION', 'Temporary state-machine assertion',
           d.department_id, d.department_id, 'planned', 'test'
    FROM opm_demo.departments d WHERE d.department_code = 'DEMO-OPM'
    ON CONFLICT (reference_code) DO UPDATE
        SET status = 'planned', outcome_note = NULL
    RETURNING action_id INTO v_action_id;

    DELETE FROM opm_demo.action_events WHERE action_id = v_action_id;

    PERFORM opm_demo.fn_transition_action(
        v_action_id, 'in_progress', 'test transition', 'test-suite'
    );
    PERFORM opm_demo.fn_transition_action(
        v_action_id, 'in_progress', 'same-state retry must be a no-op', 'test-suite'
    );

    SELECT status INTO v_status FROM opm_demo.programme_actions WHERE action_id = v_action_id;
    SELECT COUNT(*) INTO v_events FROM opm_demo.action_events WHERE action_id = v_action_id;
    IF v_status <> 'in_progress' OR v_events <> 1 THEN
        RAISE EXCEPTION 'ASSERT allowed transition/idempotency failed: status %, events %', v_status, v_events;
    END IF;

    BEGIN
        PERFORM opm_demo.fn_transition_action(
            v_action_id, 'planned', 'illegal reverse transition', 'test-suite'
        );
        RAISE EXCEPTION 'ASSERT illegal reverse transition was accepted';
    EXCEPTION WHEN check_violation THEN
        NULL;
    END;

    SELECT status INTO v_status FROM opm_demo.programme_actions WHERE action_id = v_action_id;
    IF v_status <> 'in_progress' THEN
        RAISE EXCEPTION 'ASSERT rejected transition modified the row';
    END IF;
END;
$test$;

ROLLBACK;