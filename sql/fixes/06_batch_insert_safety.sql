-- Purpose: safely insert batches of synthetic users without dynamic SQL.
-- Engine: PostgreSQL 15+; depends on vault_demo.users.
-- Rerun safety: CREATE OR REPLACE FUNCTION.
-- Call values through bound parameters. Never interpolate untrusted strings.
-- SECURITY INVOKER is the safe default; grant only required rights to callers.

CREATE OR REPLACE FUNCTION vault_demo.fn_insert_users_batch(
    p_names TEXT[],
    p_emails TEXT[]
)
RETURNS TABLE (inserted_user_id BIGINT, inserted_email TEXT)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, vault_demo
AS $function$
BEGIN
    IF p_names IS NULL OR p_emails IS NULL THEN
        RAISE EXCEPTION 'names and emails arrays are required'
            USING ERRCODE = '22004';
    END IF;

    IF cardinality(p_names) <> cardinality(p_emails) THEN
        RAISE EXCEPTION 'names and emails must have equal lengths'
            USING ERRCODE = '2202E';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM unnest(p_names, p_emails) AS pair(display_name, email)
        WHERE pair.display_name IS NULL
           OR length(btrim(pair.display_name)) = 0
           OR pair.email IS NULL
           OR length(btrim(pair.email)) < 3
    ) THEN
        RAISE EXCEPTION 'batch contains a blank name or email'
            USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM unnest(p_names, p_emails) AS pair(display_name, email)
        GROUP BY lower(btrim(email))
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'batch contains repeated email addresses'
            USING ERRCODE = '23505';
    END IF;

    RETURN QUERY
    INSERT INTO vault_demo.users AS target (display_name, email)
    SELECT btrim(pair.display_name), lower(btrim(pair.email))
    FROM unnest(p_names, p_emails) AS pair(display_name, email)
    ON CONFLICT (email) DO NOTHING
    RETURNING target.user_id, target.email;
END;
$function$;

COMMENT ON FUNCTION vault_demo.fn_insert_users_batch(TEXT[], TEXT[]) IS
    'Validates and idempotently inserts a bound batch; errors roll back the calling statement.';