-- ============================================================================
-- Corruption Report Auditor - Trend Analysis Functions
-- Description: Advanced trend detection and forecasting functions
-- ============================================================================

-- ============================================================================
-- Moving Average Analysis
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_moving_average_trends(
    p_window_size INTEGER DEFAULT 7,
    p_lookback_days INTEGER DEFAULT 90
)
RETURNS TABLE (
    report_date DATE,
    daily_count BIGINT,
    moving_avg NUMERIC,
    deviation_from_avg NUMERIC,
    is_anomaly BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    WITH daily_counts AS (
        SELECT 
            d.dt::DATE as report_date,
            COALESCE(COUNT(r.report_id), 0) as daily_count
        FROM generate_series(
            CURRENT_DATE - (p_lookback_days || ' days')::INTERVAL,
            CURRENT_DATE,
            INTERVAL '1 day'
        ) d(dt)
        LEFT JOIN reports r ON r.reported_date::DATE = d.dt::DATE
        GROUP BY d.dt
    ),
    with_moving_avg AS (
        SELECT 
            dc.report_date,
            dc.daily_count,
            ROUND(AVG(dc.daily_count) OVER (
                ORDER BY dc.report_date
                ROWS BETWEEN p_window_size - 1 PRECEDING AND CURRENT ROW
            )::NUMERIC, 2) as moving_avg,
            ROUND(STDDEV(dc.daily_count) OVER (
                ORDER BY dc.report_date
                ROWS BETWEEN p_window_size - 1 PRECEDING AND CURRENT ROW
            )::NUMERIC, 2) as moving_stddev
        FROM daily_counts dc
    )
    SELECT 
        wma.report_date,
        wma.daily_count::BIGINT,
        wma.moving_avg,
        ROUND((wma.daily_count - wma.moving_avg)::NUMERIC, 2) as deviation_from_avg,
        CASE 
            WHEN wma.moving_stddev > 0 
            THEN ABS(wma.daily_count - wma.moving_avg) > (2 * wma.moving_stddev)
            ELSE FALSE
        END as is_anomaly
    FROM with_moving_avg wma
    ORDER BY wma.report_date;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_moving_average_trends IS 'Calculates moving averages and detects anomalies';

-- ============================================================================
-- Seasonal Pattern Detection
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_seasonal_patterns()
RETURNS TABLE (
    day_of_week VARCHAR,
    avg_reports NUMERIC,
    day_index INTEGER,
    relative_volume NUMERIC
) AS $$
DECLARE
    v_overall_avg NUMERIC;
BEGIN
    SELECT AVG(daily_count)::NUMERIC INTO v_overall_avg
    FROM (
        SELECT reported_date::DATE, COUNT(*) as daily_count
        FROM reports
        WHERE reported_date >= CURRENT_DATE - INTERVAL '1 year'
        GROUP BY reported_date::DATE
    ) dc;
    
    RETURN QUERY
    SELECT 
        TO_CHAR(r.reported_date, 'Day')::VARCHAR as day_of_week,
        ROUND(AVG(daily_count)::NUMERIC, 2) as avg_reports,
        EXTRACT(DOW FROM r.reported_date)::INTEGER as day_index,
        ROUND(AVG(daily_count) / NULLIF(v_overall_avg, 0) * 100, 2) as relative_volume
    FROM (
        SELECT reported_date::DATE, COUNT(*) as daily_count
        FROM reports
        WHERE reported_date >= CURRENT_DATE - INTERVAL '1 year'
        GROUP BY reported_date::DATE
    ) r
    CROSS JOIN LATERAL (SELECT r.reported_date) dt
    GROUP BY TO_CHAR(r.reported_date, 'Day'), EXTRACT(DOW FROM r.reported_date)
    ORDER BY EXTRACT(DOW FROM r.reported_date);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_seasonal_patterns IS 'Detects day-of-week patterns in report submissions';

-- ============================================================================
-- Monthly Seasonality
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_monthly_seasonality()
RETURNS TABLE (
    month_name VARCHAR,
    month_number INTEGER,
    avg_reports NUMERIC,
    relative_volume NUMERIC,
    years_analyzed INTEGER
) AS $$
DECLARE
    v_overall_avg NUMERIC;
BEGIN
    SELECT AVG(monthly_count)::NUMERIC INTO v_overall_avg
    FROM (
        SELECT DATE_TRUNC('month', reported_date) as month, COUNT(*) as monthly_count
        FROM reports
        GROUP BY DATE_TRUNC('month', reported_date)
    ) mc;
    
    RETURN QUERY
    SELECT 
        TO_CHAR(DATE_TRUNC('month', r.reported_date), 'Month')::VARCHAR as month_name,
        EXTRACT(MONTH FROM r.reported_date)::INTEGER as month_number,
        ROUND(AVG(monthly_count)::NUMERIC, 2) as avg_reports,
        ROUND(AVG(monthly_count) / NULLIF(v_overall_avg, 0) * 100, 2) as relative_volume,
        COUNT(DISTINCT EXTRACT(YEAR FROM r.reported_date))::INTEGER as years_analyzed
    FROM (
        SELECT reported_date, COUNT(*) OVER (
            PARTITION BY DATE_TRUNC('month', reported_date)
        ) as monthly_count
        FROM reports
    ) r
    GROUP BY TO_CHAR(DATE_TRUNC('month', r.reported_date), 'Month'), 
             EXTRACT(MONTH FROM r.reported_date)
    ORDER BY month_number;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_monthly_seasonality IS 'Analyzes monthly patterns across historical data';

-- ============================================================================
-- Category Trend Analysis
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_category_trends(
    p_months INTEGER DEFAULT 12
)
RETURNS TABLE (
    category VARCHAR,
    current_month_count BIGINT,
    prev_month_count BIGINT,
    mom_change_pct NUMERIC,
    three_month_avg NUMERIC,
    trend_direction VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH monthly_category AS (
        SELECT 
            c.name as category,
            DATE_TRUNC('month', r.reported_date)::DATE as month,
            COUNT(*) as report_count
        FROM reports r
        JOIN categories c ON r.category_id = c.category_id
        WHERE r.reported_date >= DATE_TRUNC('month', CURRENT_DATE) - (p_months || ' months')::INTERVAL
        GROUP BY c.name, DATE_TRUNC('month', r.reported_date)
    ),
    with_lag AS (
        SELECT 
            mc.category,
            mc.month,
            mc.report_count,
            LAG(mc.report_count) OVER (PARTITION BY mc.category ORDER BY mc.month) as prev_month,
            AVG(mc.report_count) OVER (
                PARTITION BY mc.category 
                ORDER BY mc.month 
                ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
            ) as three_month_avg
        FROM monthly_category mc
    )
    SELECT 
        wl.category,
        wl.report_count::BIGINT as current_month_count,
        COALESCE(wl.prev_month, 0)::BIGINT as prev_month_count,
        ROUND(100.0 * (wl.report_count - COALESCE(wl.prev_month, 0)) / 
            NULLIF(wl.prev_month, 0), 2) as mom_change_pct,
        ROUND(wl.three_month_avg::NUMERIC, 2),
        CASE 
            WHEN wl.report_count > wl.three_month_avg * 1.1 THEN 'Increasing'
            WHEN wl.report_count < wl.three_month_avg * 0.9 THEN 'Decreasing'
            ELSE 'Stable'
        END::VARCHAR as trend_direction
    FROM with_lag wl
    WHERE wl.month = DATE_TRUNC('month', CURRENT_DATE)
    ORDER BY wl.report_count DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_category_trends IS 'Analyzes month-over-month trends by category with direction';

-- ============================================================================
-- Department Performance Trends
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_department_performance_trends(
    p_quarters INTEGER DEFAULT 4
)
RETURNS TABLE (
    department VARCHAR,
    quarter VARCHAR,
    cases_received BIGINT,
    cases_resolved BIGINT,
    resolution_rate NUMERIC,
    avg_resolution_days NUMERIC,
    sla_compliance NUMERIC,
    performance_score NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.name::VARCHAR as department,
        ('Q' || EXTRACT(QUARTER FROM r.reported_date)::TEXT || ' ' || 
         EXTRACT(YEAR FROM r.reported_date)::TEXT)::VARCHAR as quarter,
        COUNT(*)::BIGINT as cases_received,
        COUNT(*) FILTER (WHERE r.resolution_date IS NOT NULL)::BIGINT as cases_resolved,
        ROUND(100.0 * COUNT(*) FILTER (WHERE r.resolution_date IS NOT NULL) / 
            NULLIF(COUNT(*), 0), 2) as resolution_rate,
        ROUND(AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400) 
            FILTER (WHERE r.resolution_date IS NOT NULL)::NUMERIC, 2) as avg_resolution_days,
        ROUND(100.0 * COUNT(*) FILTER (WHERE r.resolution_date <= r.target_resolution_date) / 
            NULLIF(COUNT(*) FILTER (WHERE r.resolution_date IS NOT NULL), 0), 2) as sla_compliance,
        -- Composite performance score (resolution rate * 0.4 + SLA compliance * 0.4 + inverse of avg days * 0.2)
        ROUND(
            (COALESCE(100.0 * COUNT(*) FILTER (WHERE r.resolution_date IS NOT NULL) / NULLIF(COUNT(*), 0), 0) * 0.4) +
            (COALESCE(100.0 * COUNT(*) FILTER (WHERE r.resolution_date <= r.target_resolution_date) / 
                NULLIF(COUNT(*) FILTER (WHERE r.resolution_date IS NOT NULL), 0), 0) * 0.4) +
            (GREATEST(0, 100 - COALESCE(AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400) 
                FILTER (WHERE r.resolution_date IS NOT NULL), 100)) * 0.2)
        , 2) as performance_score
    FROM reports r
    JOIN departments d ON r.department_id = d.department_id
    WHERE r.reported_date >= DATE_TRUNC('quarter', CURRENT_DATE) - (p_quarters || ' quarters')::INTERVAL
    GROUP BY d.name, EXTRACT(QUARTER FROM r.reported_date), EXTRACT(YEAR FROM r.reported_date)
    ORDER BY EXTRACT(YEAR FROM MIN(r.reported_date)) DESC, 
             EXTRACT(QUARTER FROM MIN(r.reported_date)) DESC, 
             performance_score DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_department_performance_trends IS 'Quarterly department performance with composite scoring';

-- ============================================================================
-- Cumulative Resolution Curve
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_cumulative_resolution_curve(
    p_cohort_start DATE DEFAULT CURRENT_DATE - INTERVAL '6 months',
    p_cohort_end DATE DEFAULT CURRENT_DATE - INTERVAL '3 months'
)
RETURNS TABLE (
    days_since_filing INTEGER,
    cumulative_resolved BIGINT,
    total_in_cohort BIGINT,
    pct_resolved NUMERIC
) AS $$
DECLARE
    v_total BIGINT;
BEGIN
    SELECT COUNT(*) INTO v_total
    FROM reports
    WHERE reported_date::DATE BETWEEN p_cohort_start AND p_cohort_end;
    
    RETURN QUERY
    WITH cohort AS (
        SELECT 
            r.report_id,
            r.reported_date,
            r.resolution_date,
            CASE 
                WHEN r.resolution_date IS NOT NULL 
                THEN EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400
                ELSE NULL
            END as days_to_resolve
        FROM reports r
        WHERE r.reported_date::DATE BETWEEN p_cohort_start AND p_cohort_end
    ),
    day_series AS (
        SELECT generate_series(0, 180) as day_num
    )
    SELECT 
        ds.day_num::INTEGER as days_since_filing,
        COUNT(c.report_id) FILTER (WHERE c.days_to_resolve <= ds.day_num)::BIGINT as cumulative_resolved,
        v_total::BIGINT as total_in_cohort,
        ROUND(100.0 * COUNT(c.report_id) FILTER (WHERE c.days_to_resolve <= ds.day_num) / 
            NULLIF(v_total, 0), 2) as pct_resolved
    FROM day_series ds
    CROSS JOIN cohort c
    GROUP BY ds.day_num
    ORDER BY ds.day_num;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_cumulative_resolution_curve IS 'Shows cumulative resolution percentage over time for a cohort';

-- ============================================================================
-- Escalation Pattern Analysis
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_escalation_patterns()
RETURNS TABLE (
    from_department VARCHAR,
    to_department VARCHAR,
    escalation_count BIGINT,
    avg_days_before_escalation NUMERIC,
    avg_days_to_resolve_after NUMERIC,
    resolution_after_escalation_pct NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE(df.name, 'Direct')::VARCHAR as from_department,
        dt.name::VARCHAR as to_department,
        COUNT(*)::BIGINT as escalation_count,
        ROUND(AVG(EXTRACT(EPOCH FROM (e.escalated_at - r.reported_date))/86400)::NUMERIC, 2) as avg_days_before_escalation,
        ROUND(AVG(EXTRACT(EPOCH FROM (e.resolved_at - e.escalated_at))/86400) 
            FILTER (WHERE e.resolved_at IS NOT NULL)::NUMERIC, 2) as avg_days_to_resolve_after,
        ROUND(100.0 * COUNT(*) FILTER (WHERE e.resolved_at IS NOT NULL) / 
            NULLIF(COUNT(*), 0), 2) as resolution_after_escalation_pct
    FROM escalations e
    JOIN reports r ON e.report_id = r.report_id
    LEFT JOIN departments df ON e.escalated_from = df.department_id
    JOIN departments dt ON e.escalated_to = dt.department_id
    GROUP BY df.name, dt.name
    HAVING COUNT(*) >= 1
    ORDER BY escalation_count DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_escalation_patterns IS 'Analyzes patterns in case escalations between departments';

-- ============================================================================
-- Workload Forecast
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_workload_forecast(
    p_forecast_days INTEGER DEFAULT 30
)
RETURNS TABLE (
    forecast_date DATE,
    expected_new_reports NUMERIC,
    expected_resolutions NUMERIC,
    projected_open_cases NUMERIC,
    confidence VARCHAR
) AS $$
DECLARE
    v_current_open BIGINT;
    v_avg_daily_new NUMERIC;
    v_avg_daily_resolved NUMERIC;
    v_stddev_new NUMERIC;
BEGIN
    -- Get current open cases
    SELECT COUNT(*) INTO v_current_open
    FROM reports r
    JOIN statuses s ON r.status_id = s.status_id
    WHERE s.is_terminal = FALSE;
    
    -- Calculate averages from last 90 days
    SELECT 
        AVG(new_reports),
        AVG(resolved_reports),
        STDDEV(new_reports)
    INTO v_avg_daily_new, v_avg_daily_resolved, v_stddev_new
    FROM daily_statistics
    WHERE stat_date >= CURRENT_DATE - INTERVAL '90 days';
    
    RETURN QUERY
    SELECT 
        (CURRENT_DATE + (gs.day_num || ' days')::INTERVAL)::DATE as forecast_date,
        ROUND(v_avg_daily_new, 2) as expected_new_reports,
        ROUND(v_avg_daily_resolved, 2) as expected_resolutions,
        ROUND(v_current_open + (gs.day_num * (v_avg_daily_new - v_avg_daily_resolved)), 0) as projected_open_cases,
        CASE 
            WHEN gs.day_num <= 7 THEN 'High'
            WHEN gs.day_num <= 14 THEN 'Medium'
            ELSE 'Low'
        END::VARCHAR as confidence
    FROM generate_series(1, p_forecast_days) gs(day_num)
    ORDER BY gs.day_num;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_workload_forecast IS 'Projects future workload based on historical trends';
