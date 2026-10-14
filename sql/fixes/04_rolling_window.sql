-- Purpose: calculate a 7-calendar-day rolling revenue total.
-- Engine: PostgreSQL 15+; depends on v_sales_countable.
-- Rerun safety: CREATE OR REPLACE VIEW and CREATE INDEX IF NOT EXISTS.
-- A date cast to timestamp is used because RANGE interval offsets require
-- an ordered value supporting timestamp interval arithmetic. Missing dates
-- do not expand the window to earlier observations.

CREATE OR REPLACE VIEW vault_demo.v_daily_sales AS
SELECT
    (s.created_at AT TIME ZONE 'UTC')::date AS sale_day,
    SUM(s.amount)::numeric(18,2) AS revenue,
    COUNT(*)::bigint AS sale_count
FROM vault_demo.v_sales_countable AS s
GROUP BY (s.created_at AT TIME ZONE 'UTC')::date;

CREATE OR REPLACE VIEW vault_demo.v_sales_rolling_7d AS
SELECT
    d.sale_day,
    d.revenue,
    d.sale_count,
    SUM(d.revenue) OVER (
        ORDER BY d.sale_day::timestamp
        RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW
    )::numeric(18,2) AS revenue_7_calendar_days
FROM vault_demo.v_daily_sales AS d;

CREATE INDEX IF NOT EXISTS ix_sales_live_created_at
    ON vault_demo.sales(created_at)
    WHERE is_deleted = FALSE AND status IN ('paid', 'shipped', 'delivered');

COMMENT ON VIEW vault_demo.v_sales_rolling_7d IS
    'Seven calendar days ending on each observed sale day; gaps do not extend the range.';