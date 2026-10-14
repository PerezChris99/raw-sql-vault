-- Purpose: report calendar days without losing transactions on the end date.
-- Engine: PostgreSQL 15+; depends on v_sales_countable.
-- Rerun safety: CREATE OR REPLACE FUNCTION.
-- Parameters are calendar dates in UTC; p_end is inclusive at the API boundary.
-- Predicate becomes [UTC start midnight, UTC midnight after p_end), enabling index use.

CREATE OR REPLACE FUNCTION vault_demo.fn_sales_by_day(
    p_start DATE,
    p_end DATE
)
RETURNS TABLE (
    sale_day DATE,
    sale_count BIGINT,
    revenue NUMERIC
)
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog, vault_demo
AS $function$
BEGIN
    IF p_start IS NULL OR p_end IS NULL THEN
        RAISE EXCEPTION 'start and end dates are required'
            USING ERRCODE = '22004';
    END IF;

    IF p_end < p_start THEN
        RAISE EXCEPTION 'end date (%) precedes start date (%)', p_end, p_start
            USING ERRCODE = '22007';
    END IF;

    RETURN QUERY
    WITH calendar AS (
        SELECT g::date AS day
        FROM generate_series(
            p_start::timestamp,
            p_end::timestamp,
            INTERVAL '1 day'
        ) AS g
    ),
    daily AS (
        SELECT
            (s.created_at AT TIME ZONE 'UTC')::date AS day,
            COUNT(*)::bigint AS orders,
            SUM(s.amount)::numeric AS total_amount
        FROM vault_demo.v_sales_countable AS s
        WHERE s.created_at >= (p_start::timestamp AT TIME ZONE 'UTC')
          AND s.created_at < ((p_end + 1)::timestamp AT TIME ZONE 'UTC')
        GROUP BY (s.created_at AT TIME ZONE 'UTC')::date
    )
    SELECT c.day, COALESCE(d.orders, 0), COALESCE(d.total_amount, 0)
    FROM calendar AS c
    LEFT JOIN daily AS d ON d.day = c.day
    ORDER BY c.day;
END;
$function$;

COMMENT ON FUNCTION vault_demo.fn_sales_by_day(DATE, DATE) IS
    'Reports UTC calendar dates inclusively using a half-open timestamptz predicate.';