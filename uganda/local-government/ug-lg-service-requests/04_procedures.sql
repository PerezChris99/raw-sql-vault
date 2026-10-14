-- Purpose: change request status and append an event atomically.
-- Engine: PostgreSQL 15+; requires 01_schema.sql.
-- Rerun safety: CREATE OR REPLACE FUNCTION.

CREATE OR REPLACE FUNCTION service_demo.fn_transition_request(
    p_request_id BIGINT,
    p_target_status TEXT,
    p_note TEXT,
    p_actor_ref TEXT
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, service_demo
AS $function$
DECLARE
    v_current TEXT;
BEGIN
    IF p_target_status IS NULL OR p_target_status NOT IN
       ('new', 'triaged', 'in_progress', 'blocked', 'resolved', 'cancelled') THEN
        RAISE EXCEPTION 'invalid target status: %', p_target_status USING ERRCODE = '23514';
    END IF;
    IF NULLIF(btrim(p_note), '') IS NULL OR NULLIF(btrim(p_actor_ref), '') IS NULL THEN
        RAISE EXCEPTION 'note and actor reference are required' USING ERRCODE = '22023';
    END IF;

    SELECT status INTO v_current
    FROM service_demo.service_requests
    WHERE request_id = p_request_id AND is_deleted = FALSE
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'active request % not found', p_request_id USING ERRCODE = 'P0002';
    END IF;
    IF v_current = p_target_status THEN
        RETURN p_request_id;
    END IF;

    IF NOT (
        (v_current = 'new' AND p_target_status IN ('triaged', 'cancelled'))
        OR (v_current = 'triaged' AND p_target_status IN ('in_progress', 'cancelled'))
        OR (v_current = 'in_progress' AND p_target_status IN ('blocked', 'resolved', 'cancelled'))
        OR (v_current = 'blocked' AND p_target_status IN ('in_progress', 'cancelled'))
    ) THEN
        RAISE EXCEPTION 'transition not allowed: % -> %', v_current, p_target_status
            USING ERRCODE = '23514';
    END IF;

    UPDATE service_demo.service_requests
    SET status = p_target_status,
        resolved_at = CASE WHEN p_target_status = 'resolved' THEN clock_timestamp() ELSE NULL END
    WHERE request_id = p_request_id;

    INSERT INTO service_demo.request_events
        (request_id, previous_status, new_status, event_note, actor_ref)
    VALUES (p_request_id, v_current, p_target_status, btrim(p_note), btrim(p_actor_ref));

    RETURN p_request_id;
END;
$function$;

REVOKE ALL ON FUNCTION service_demo.fn_transition_request(BIGINT, TEXT, TEXT, TEXT) FROM PUBLIC;