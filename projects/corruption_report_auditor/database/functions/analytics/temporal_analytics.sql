-- ============================================================================
-- Corruption Report Auditor - Temporal Analytics Functions
-- Description: Stored functions for temporal analysis using FILTER, INTERVAL, AGE()
-- ============================================================================

-- ============================================================================
-- Core Query Function (Implements Sample SQL from Requirements)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_category_status_report(
    p_lookback_interval INTERVAL DEFAULT INTERVAL '1 year'
)
RETURNS TABLE (
    category VARCHAR,
    open_cases BIGINT,
    resolved_cases BIGINT,
    escalated_cases BIGINT,
    dismissed_cases BIGINT,
    total_cases BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.name as category,
        COUNT(*) FILTER (WHERE s.name IN ('open', 'under_review', 'investigation', 'pending_evidence', 'pending_witness')) as open_cases,
        COUNT(*) FILTER (WHERE s.name = 'resolved') as resolved_cases,
        COUNT(*) FILTER (WHERE s.name = 'escalated') as escalated_cases,
        COUNT(*) FILTER (WHERE s.name = 'dismissed') as dismissed_cases,
        COUNT(*) as total_cases
    FROM reports r
    JOIN categories c ON r.category_id = c.category_id
    JOIN statuses s ON r.status_id = s.status_id
    WHERE r.reported_date > CURRENT_DATE - p_lookback_interval
    GROUP BY c.name
    ORDER BY open_cases DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_category_status_report IS 'Core temporal query - status distribution by category using FILTER clause';

-- ============================================================================
-- Aging Analysis Function
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_aging_analysis(
    p_department_id UUID DEFAULT NULL
)
RETURNS TABLE (
    department VARCHAR,
    age_bucket VARCHAR,
    case_count BIGINT,
    total_amount NUMERIC,
    avg_priority NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        d.name as department,
        CASE 
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '30 days' THEN '0-30 days'
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '60 days' THEN '31-60 days'
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '90 days' THEN '61-90 days'
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '180 days' THEN '91-180 days'
            ELSE 'Over 180 days'
        END as age_bucket,
        COUNT(*) as case_count,
        SUM(COALESCE(r.estimated_amount, 0)) as total_amount,
        ROUND(AVG(r.priority)::NUMERIC, 2) as avg_priority
    FROM reports r
    JOIN departments d ON r.department_id = d.department_id
    JOIN statuses s ON r.status_id = s.status_id
    WHERE s.is_terminal = FALSE
    AND (p_department_id IS NULL OR r.department_id = p_department_id)
    GROUP BY d.name, 
        CASE 
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '30 days' THEN '0-30 days'
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '60 days' THEN '31-60 days'
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '90 days' THEN '61-90 days'
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '180 days' THEN '91-180 days'
            ELSE 'Over 180 days'
        END
    ORDER BY d.name, 
        MIN(CASE 
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '30 days' THEN 1
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '60 days' THEN 2
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '90 days' THEN 3
            WHEN AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '180 days' THEN 4
            ELSE 5
        END);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_aging_analysis IS 'Case aging analysis with configurable buckets using AGE() function';

-- ============================================================================
-- Monthly Trends with Gap Filling
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_monthly_trends(
    p_months INTEGER DEFAULT 12
)
RETURNS TABLE (
    month DATE,
    new_reports BIGINT,
    resolved BIGINT,
    net_change BIGINT,
    running_open BIGINT,
    yoy_change_pct NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH months AS (
        SELECT generate_series(
            DATE_TRUNC('month', CURRENT_DATE - (p_months || ' months')::INTERVAL),
            DATE_TRUNC('month', CURRENT_DATE),
            INTERVAL '1 month'
        )::DATE as month
    ),
    monthly_data AS (
        SELECT 
            DATE_TRUNC('month', r.reported_date)::DATE as report_month,
            COUNT(*) as new_reports,
            COUNT(*) FILTER (WHERE r.resolution_date IS NOT NULL 
                AND DATE_TRUNC('month', r.resolution_date) = DATE_TRUNC('month', r.reported_date)) as resolved_same_month
        FROM reports r
        WHERE r.reported_date >= CURRENT_DATE - ((p_months + 12) || ' months')::INTERVAL
        GROUP BY DATE_TRUNC('month', r.reported_date)::DATE
    ),
    resolved_data AS (
        SELECT 
            DATE_TRUNC('month', r.resolution_date)::DATE as resolution_month,
            COUNT(*) as total_resolved
        FROM reports r
        WHERE r.resolution_date IS NOT NULL
        AND r.resolution_date >= CURRENT_DATE - ((p_months + 12) || ' months')::INTERVAL
        GROUP BY DATE_TRUNC('month', r.resolution_date)::DATE
    )
    SELECT 
        m.month,
        COALESCE(md.new_reports, 0)::BIGINT as new_reports,
        COALESCE(rd.total_resolved, 0)::BIGINT as resolved,
        (COALESCE(md.new_reports, 0) - COALESCE(rd.total_resolved, 0))::BIGINT as net_change,
        SUM(COALESCE(md.new_reports, 0) - COALESCE(rd.total_resolved, 0)) 
            OVER (ORDER BY m.month)::BIGINT as running_open,
        ROUND(
            100.0 * (COALESCE(md.new_reports, 0) - LAG(COALESCE(md.new_reports, 0), 12) OVER (ORDER BY m.month)) /
            NULLIF(LAG(COALESCE(md.new_reports, 0), 12) OVER (ORDER BY m.month), 0)
        , 2) as yoy_change_pct
    FROM months m
    LEFT JOIN monthly_data md ON m.month = md.report_month
    LEFT JOIN resolved_data rd ON m.month = rd.resolution_month
    ORDER BY m.month;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_monthly_trends IS 'Monthly trends with gap filling using generate_series and year-over-year comparison';

-- ============================================================================
-- Time-to-Resolution Analysis
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_resolution_time_analysis(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '1 year',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    category VARCHAR,
    priority INTEGER,
    cases_resolved BIGINT,
    avg_days_to_resolve NUMERIC,
    min_days NUMERIC,
    max_days NUMERIC,
    median_days NUMERIC,
    p90_days NUMERIC,
    within_sla_pct NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.name as category,
        r.priority,
        COUNT(*)::BIGINT as cases_resolved,
        ROUND(AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400)::NUMERIC, 2) as avg_days_to_resolve,
        ROUND(MIN(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400)::NUMERIC, 2) as min_days,
        ROUND(MAX(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400)::NUMERIC, 2) as max_days,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400
        )::NUMERIC, 2) as median_days,
        ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400
        )::NUMERIC, 2) as p90_days,
        ROUND(100.0 * COUNT(*) FILTER (WHERE r.resolution_date <= r.target_resolution_date) / 
            NULLIF(COUNT(*), 0), 2) as within_sla_pct
    FROM reports r
    JOIN categories c ON r.category_id = c.category_id
    WHERE r.resolution_date IS NOT NULL
    AND r.reported_date BETWEEN p_start_date AND p_end_date
    GROUP BY c.name, r.priority
    ORDER BY c.name, r.priority;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_resolution_time_analysis IS 'Resolution time statistics with percentiles';

-- ============================================================================
-- Daily Activity Summary
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_daily_activity(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    activity_date DATE,
    new_reports BIGINT,
    resolved BIGINT,
    escalated BIGINT,
    actions_taken BIGINT,
    net_change BIGINT
) AS $$
BEGIN
    RETURN QUERY
    WITH dates AS (
        SELECT generate_series(p_start_date, p_end_date, INTERVAL '1 day')::DATE as d
    ),
    report_activity AS (
        SELECT 
            reported_date::DATE as dt,
            COUNT(*) as new_reports
        FROM reports
        WHERE reported_date::DATE BETWEEN p_start_date AND p_end_date
        GROUP BY reported_date::DATE
    ),
    resolution_activity AS (
        SELECT 
            resolution_date::DATE as dt,
            COUNT(*) as resolved
        FROM reports
        WHERE resolution_date::DATE BETWEEN p_start_date AND p_end_date
        GROUP BY resolution_date::DATE
    ),
    escalation_activity AS (
        SELECT 
            escalated_at::DATE as dt,
            COUNT(*) as escalated
        FROM escalations
        WHERE escalated_at::DATE BETWEEN p_start_date AND p_end_date
        GROUP BY escalated_at::DATE
    ),
    action_activity AS (
        SELECT 
            action_date::DATE as dt,
            COUNT(*) as actions
        FROM case_actions
        WHERE action_date::DATE BETWEEN p_start_date AND p_end_date
        GROUP BY action_date::DATE
    )
    SELECT 
        dates.d as activity_date,
        COALESCE(ra.new_reports, 0)::BIGINT as new_reports,
        COALESCE(res.resolved, 0)::BIGINT as resolved,
        COALESCE(esc.escalated, 0)::BIGINT as escalated,
        COALESCE(act.actions, 0)::BIGINT as actions_taken,
        (COALESCE(ra.new_reports, 0) - COALESCE(res.resolved, 0))::BIGINT as net_change
    FROM dates
    LEFT JOIN report_activity ra ON dates.d = ra.dt
    LEFT JOIN resolution_activity res ON dates.d = res.dt
    LEFT JOIN escalation_activity esc ON dates.d = esc.dt
    LEFT JOIN action_activity act ON dates.d = act.dt
    ORDER BY dates.d;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_daily_activity IS 'Daily activity summary with gap-filled date series';

-- ============================================================================
-- SLA Breach Forecast
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_sla_breach_forecast(
    p_days_ahead INTEGER DEFAULT 7
)
RETURNS TABLE (
    report_number VARCHAR,
    department VARCHAR,
    category VARCHAR,
    days_remaining INTEGER,
    current_status VARCHAR,
    priority INTEGER,
    days_open INTEGER,
    assigned_officer VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.report_number,
        d.name as department,
        c.name as category,
        (r.target_resolution_date - CURRENT_DATE)::INTEGER as days_remaining,
        s.name as current_status,
        r.priority,
        EXTRACT(EPOCH FROM AGE(CURRENT_TIMESTAMP, r.reported_date))::INTEGER / 86400 as days_open,
        COALESCE(o.first_name || ' ' || o.last_name, 'Unassigned') as assigned_officer
    FROM reports r
    JOIN departments d ON r.department_id = d.department_id
    JOIN categories c ON r.category_id = c.category_id
    JOIN statuses s ON r.status_id = s.status_id
    LEFT JOIN officers o ON r.assigned_to = o.officer_id
    WHERE s.is_terminal = FALSE
    AND r.target_resolution_date <= CURRENT_DATE + (p_days_ahead || ' days')::INTERVAL
    ORDER BY r.target_resolution_date, r.priority;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_sla_breach_forecast IS 'Forecasts cases approaching SLA breach';

-- ============================================================================
-- Comparative Period Analysis
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_period_comparison(
    p_period_type VARCHAR DEFAULT 'month', -- 'week', 'month', 'quarter', 'year'
    p_periods_back INTEGER DEFAULT 2
)
RETURNS TABLE (
    period_label VARCHAR,
    period_start DATE,
    period_end DATE,
    new_reports BIGINT,
    resolved BIGINT,
    resolution_rate NUMERIC,
    avg_resolution_days NUMERIC,
    escalation_count BIGINT,
    total_amount NUMERIC
) AS $$
DECLARE
    v_interval INTERVAL;
BEGIN
    v_interval := CASE p_period_type
        WHEN 'week' THEN INTERVAL '1 week'
        WHEN 'month' THEN INTERVAL '1 month'
        WHEN 'quarter' THEN INTERVAL '3 months'
        WHEN 'year' THEN INTERVAL '1 year'
        ELSE INTERVAL '1 month'
    END;
    
    RETURN QUERY
    WITH periods AS (
        SELECT 
            generate_series(0, p_periods_back - 1) as period_num,
            DATE_TRUNC(p_period_type, CURRENT_DATE - (generate_series(0, p_periods_back - 1) * v_interval)) as period_start
    )
    SELECT 
        TO_CHAR(p.period_start, CASE p_period_type
            WHEN 'week' THEN '"Week of" Mon DD, YYYY'
            WHEN 'month' THEN 'Mon YYYY'
            WHEN 'quarter' THEN '"Q"Q YYYY'
            WHEN 'year' THEN 'YYYY'
        END)::VARCHAR as period_label,
        p.period_start::DATE,
        (p.period_start + v_interval - INTERVAL '1 day')::DATE as period_end,
        COUNT(DISTINCT r.report_id) FILTER (
            WHERE r.reported_date >= p.period_start 
            AND r.reported_date < p.period_start + v_interval
        )::BIGINT as new_reports,
        COUNT(DISTINCT r.report_id) FILTER (
            WHERE r.resolution_date >= p.period_start 
            AND r.resolution_date < p.period_start + v_interval
        )::BIGINT as resolved,
        ROUND(
            100.0 * COUNT(DISTINCT r.report_id) FILTER (WHERE r.resolution_date IS NOT NULL) /
            NULLIF(COUNT(DISTINCT r.report_id), 0)
        , 2) as resolution_rate,
        ROUND(AVG(
            EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400
        ) FILTER (WHERE r.resolution_date IS NOT NULL)::NUMERIC, 2) as avg_resolution_days,
        COUNT(DISTINCT e.escalation_id) FILTER (
            WHERE e.escalated_at >= p.period_start 
            AND e.escalated_at < p.period_start + v_interval
        )::BIGINT as escalation_count,
        COALESCE(SUM(r.estimated_amount) FILTER (
            WHERE r.reported_date >= p.period_start 
            AND r.reported_date < p.period_start + v_interval
        ), 0) as total_amount
    FROM periods p
    LEFT JOIN reports r ON r.reported_date >= p.period_start - v_interval * p_periods_back 
        AND r.reported_date < p.period_start + v_interval
    LEFT JOIN escalations e ON e.escalated_at >= p.period_start - v_interval * p_periods_back
        AND e.escalated_at < p.period_start + v_interval
    GROUP BY p.period_num, p.period_start
    ORDER BY p.period_start DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_period_comparison IS 'Compares metrics across configurable time periods';

-- ============================================================================
-- Status Duration Analysis (How long cases spend in each status)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_status_duration_analysis()
RETURNS TABLE (
    status_name VARCHAR,
    avg_duration_days NUMERIC,
    median_duration_days NUMERIC,
    min_duration_days NUMERIC,
    max_duration_days NUMERIC,
    total_transitions BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.name::VARCHAR as status_name,
        ROUND(AVG(EXTRACT(EPOCH FROM time_in_previous_status)/86400)::NUMERIC, 2) as avg_duration_days,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY EXTRACT(EPOCH FROM time_in_previous_status)/86400
        )::NUMERIC, 2) as median_duration_days,
        ROUND(MIN(EXTRACT(EPOCH FROM time_in_previous_status)/86400)::NUMERIC, 2) as min_duration_days,
        ROUND(MAX(EXTRACT(EPOCH FROM time_in_previous_status)/86400)::NUMERIC, 2) as max_duration_days,
        COUNT(*)::BIGINT as total_transitions
    FROM status_history sh
    JOIN statuses s ON sh.old_status_id = s.status_id
    WHERE sh.time_in_previous_status IS NOT NULL
    GROUP BY s.name
    ORDER BY avg_duration_days DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_status_duration_analysis IS 'Analyzes time spent in each workflow status';
