-- Purpose: cursor pagination without scanning deep OFFSET ranges.
-- Engine: PostgreSQL 15+; requires vault_demo.v_sales_countable.
-- Rerun safety: CREATE OR REPLACE FUNCTION.
-- Client sends NULL for the first page, then the largest sale_id returned.
-- Page size is clamped to protect the query from unbounded client requests.

CREATE OR REPLACE FUNCTION vault_demo.fn_sales_page(
    p_after_sale_id BIGINT DEFAULT NULL,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    sale_id BIGINT,
    customer_id BIGINT,
    amount NUMERIC(18,2),
    currency CHAR(3),
    status TEXT,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog, vault_demo
AS $function$
DECLARE
    v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
BEGIN
    IF p_after_sale_id IS NULL THEN
        RETURN QUERY
        SELECT s.sale_id, s.customer_id, s.amount, s.currency, s.status, s.created_at
        FROM vault_demo.v_sales_countable AS s
        ORDER BY s.sale_id
        LIMIT v_limit;
    ELSE
        RETURN QUERY
        SELECT s.sale_id, s.customer_id, s.amount, s.currency, s.status, s.created_at
        FROM vault_demo.v_sales_countable AS s
        WHERE s.sale_id > p_after_sale_id
        ORDER BY s.sale_id
        LIMIT v_limit;
    END IF;
END;
$function$;

COMMENT ON FUNCTION vault_demo.fn_sales_page(BIGINT, INTEGER) IS
    'Returns at most 100 countable sales after a stable sale_id cursor.';