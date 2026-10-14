-- Purpose: all-or-nothing validated batch load and point-in-time feature lookup.
-- Engine: PostgreSQL 15+.
-- These routines are SECURITY INVOKER; grant needed read/write rights to the pipeline role.

CREATE OR REPLACE FUNCTION analytics_demo.fn_load_sales_batch(p_batch_id UUID)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = pg_catalog, analytics_demo
AS $function$
DECLARE
    v_bad_count BIGINT;
    v_inserted BIGINT;
BEGIN
    IF p_batch_id IS NULL THEN
        RAISE EXCEPTION 'batch id is required' USING ERRCODE = '22004';
    END IF;

    SELECT COUNT(*) INTO v_bad_count
    FROM analytics_demo.v_staging_sales_quality
    WHERE batch_id = p_batch_id AND quality_status <> 'accepted';
    IF v_bad_count > 0 THEN
        RAISE EXCEPTION 'batch % has % rejected staging rows', p_batch_id, v_bad_count
            USING ERRCODE = '23514';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM analytics_demo.staging_sales WHERE batch_id = p_batch_id) THEN
        RAISE EXCEPTION 'batch % not found', p_batch_id USING ERRCODE = 'P0002';
    END IF;

    INSERT INTO analytics_demo.dim_dates(calendar_date, calendar_year, calendar_month, calendar_day, calendar_quarter)
    SELECT DISTINCT (s.sold_at AT TIME ZONE 'UTC')::date,
           EXTRACT(YEAR FROM s.sold_at AT TIME ZONE 'UTC')::INTEGER,
           EXTRACT(MONTH FROM s.sold_at AT TIME ZONE 'UTC')::INTEGER,
           EXTRACT(DAY FROM s.sold_at AT TIME ZONE 'UTC')::INTEGER,
           EXTRACT(QUARTER FROM s.sold_at AT TIME ZONE 'UTC')::INTEGER
    FROM analytics_demo.staging_sales s
    WHERE s.batch_id = p_batch_id
    ON CONFLICT (calendar_date) DO NOTHING;

    INSERT INTO analytics_demo.fact_sales
        (calendar_date, product_key, location_key, source_system, source_sale_id,
         sold_at, amount, currency, batch_id)
    SELECT (s.sold_at AT TIME ZONE 'UTC')::date,
           p.product_key, l.location_key, s.source_system, s.source_sale_id,
           s.sold_at, s.amount, upper(btrim(s.currency))::CHAR(3), s.batch_id
    FROM analytics_demo.staging_sales s
    JOIN analytics_demo.dim_products p ON p.source_sku = s.source_sku
    JOIN analytics_demo.dim_locations l ON l.locality_code = s.locality_code
    WHERE s.batch_id = p_batch_id
    ON CONFLICT (source_system, source_sale_id) DO NOTHING;

    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    RETURN v_inserted;
END;
$function$;

CREATE OR REPLACE FUNCTION analytics_demo.fn_features_as_of(
    p_entity_type TEXT,
    p_entity_id TEXT,
    p_prediction_at TIMESTAMPTZ
)
RETURNS TABLE (
    feature_name TEXT,
    feature_timestamp TIMESTAMPTZ,
    source_available_at TIMESTAMPTZ,
    numeric_value NUMERIC,
    text_value TEXT
)
LANGUAGE sql
STABLE
SET search_path = pg_catalog, analytics_demo
AS $function$
    SELECT DISTINCT ON (v.feature_name)
           v.feature_name, v.feature_timestamp, v.source_available_at,
           v.numeric_value, v.text_value
    FROM analytics_demo.feature_values v
    JOIN analytics_demo.feature_registry r
      ON r.feature_name = v.feature_name AND r.entity_type = v.entity_type
    WHERE v.entity_type = p_entity_type
      AND v.entity_id = p_entity_id
      AND r.active = TRUE
      AND v.feature_timestamp <= p_prediction_at
      AND v.source_available_at <= p_prediction_at
    ORDER BY v.feature_name, v.feature_timestamp DESC, v.source_available_at DESC;
$function$;

COMMENT ON FUNCTION analytics_demo.fn_features_as_of(TEXT, TEXT, TIMESTAMPTZ) IS
    'Returns only features whose event time and known-at time are no later than prediction time.';