-- Purpose: transition action workflow and record a history event atomically.
-- Engine: PostgreSQL 15+; requires 01_schema.sql.
-- Rerun safety: CREATE OR REPLACE FUNCTION.
-- Caller must execute inside normal transaction semantics; illegal transitions raise 23514.

CREATE OR REPLACE FUNCTION opm_demo.fn_transition_action(
    p_action_id BIGINT,
    p_target_status TEXT,
    p_note TEXT,
    p_actor_ref TEXT
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, opm_demo
AS $function$
DECLARE
    v_current_status TEXT;
BEGIN
    IF p_target_status NOT IN ('planned', 'in_progress', 'blocked', 'done', 'cancelled')
       OR p_target_status IS NULL THEN
        RAISE EXCEPTION 'unknown target status: %', p_target_status
            USING ERRCODE = '23514';
    END IF;
    IF NULLIF(btrim(p_note), '') IS NULL OR NULLIF(btrim(p_actor_ref), '') IS NULL THEN
        RAISE EXCEPTION 'transition note and actor reference are required'
            USING ERRCODE = '22023';
    END IF;

    SELECT a.status INTO v_current_status
    FROM opm_demo.programme_actions AS a
    WHERE a.action_id = p_action_id AND a.is_deleted = FALSE
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'active programme action % not found', p_action_id
            USING ERRCODE = 'P0002';
    END IF;

    IF v_current_status = p_target_status THEN
        RETURN p_action_id; -- Idempotent no-op: do not create a duplicate event.
    END IF;

    IF NOT (
        (v_current_status = 'planned' AND p_target_status IN ('in_progress', 'blocked', 'cancelled'))
        OR (v_current_status = 'in_progress' AND p_target_status IN ('blocked', 'done', 'cancelled'))
        OR (v_current_status = 'blocked' AND p_target_status IN ('in_progress', 'cancelled'))
    ) THEN
        RAISE EXCEPTION 'transition not allowed: % -> %', v_current_status, p_target_status
            USING ERRCODE = '23514';
    END IF;

    UPDATE opm_demo.programme_actions
    SET status = p_target_status,
        outcome_note = CASE WHEN p_target_status = 'done' THEN p_note ELSE outcome_note END
    WHERE action_id = p_action_id;

    INSERT INTO opm_demo.action_events
        (action_id, previous_status, new_status, event_note, actor_ref)
    VALUES (p_action_id, v_current_status, p_target_status, btrim(p_note), btrim(p_actor_ref));

    RETURN p_action_id;
END;
$function$;

REVOKE ALL ON FUNCTION opm_demo.fn_transition_action(BIGINT, TEXT, TEXT, TEXT) FROM PUBLIC;

COMMENT ON FUNCTION opm_demo.fn_transition_action(BIGINT, TEXT, TEXT, TEXT) IS
    'Applies allowed workflow transitions with row locking and an atomic event record.';