-- ============================================================================
-- Corruption Report Auditor - Views
-- Version: V004
-- Description: Analytics views using temporal functions and FILTER clause
-- ============================================================================

-- ============================================================================
-- Core Temporal Views
-- ============================================================================

-- Main Aging Report View (KEY VIEW for this project)
CREATE OR REPLACE VIEW vw_aging_report AS
SELECT 
    d.name as department,
    c.name as category,
    COUNT(*) as total_open,
    COUNT(*) FILTER (
        WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '30 days'
    ) as "0-30_days",
    COUNT(*) FILTER (
        WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '30 days' 
        AND AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '60 days'
    ) as "31-60_days",
    COUNT(*) FILTER (
        WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '60 days' 
        AND AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '90 days'
    ) as "61-90_days",
    COUNT(*) FILTER (
        WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '90 days' 
        AND AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '180 days'
    ) as "91-180_days",
    COUNT(*) FILTER (
        WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '180 days'
    ) as "over_180_days"
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN categories c ON r.category_id = c.category_id
JOIN statuses s ON r.status_id = s.status_id
WHERE s.is_terminal = FALSE
GROUP BY d.name, c.name
ORDER BY COUNT(*) FILTER (WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '180 days') DESC;

COMMENT ON VIEW vw_aging_report IS 'Case aging analysis using FILTER and AGE() functions';

-- ============================================================================
-- Status Distribution by Category (Sample Query Implementation)
-- ============================================================================

CREATE OR REPLACE VIEW vw_category_status_distribution AS
SELECT 
    c.name as category,
    COUNT(*) FILTER (WHERE s.name = 'unresolved' OR s.name = 'open' OR s.name = 'pending') as open_cases,
    COUNT(*) FILTER (WHERE s.name = 'resolved' OR s.name = 'closed') as closed_cases,
    COUNT(*) FILTER (WHERE s.name = 'escalated') as escalated_cases,
    COUNT(*) FILTER (WHERE s.name = 'dismissed') as dismissed_cases,
    COUNT(*) as total_cases,
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.is_terminal) / NULLIF(COUNT(*), 0), 2) as resolution_rate_pct
FROM reports r
JOIN categories c ON r.category_id = c.category_id
JOIN statuses s ON r.status_id = s.status_id
WHERE r.reported_date > CURRENT_DATE - INTERVAL '1 year'
GROUP BY c.name
ORDER BY open_cases DESC;

COMMENT ON VIEW vw_category_status_distribution IS 'Implements the sample query from requirements';

-- ============================================================================
-- Monthly Trends with Gap Filling
-- ============================================================================

CREATE OR REPLACE VIEW vw_monthly_trends AS
WITH months AS (
    SELECT generate_series(
        DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months'),
        DATE_TRUNC('month', CURRENT_DATE),
        INTERVAL '1 month'
    )::DATE as month
),
monthly_data AS (
    SELECT 
        DATE_TRUNC('month', reported_date)::DATE as month,
        COUNT(*) as new_reports,
        COUNT(*) FILTER (WHERE resolution_date IS NOT NULL) as resolved,
        COUNT(*) FILTER (WHERE priority = 1) as critical_cases,
        SUM(estimated_amount) as total_amount_reported
    FROM reports
    WHERE reported_date >= CURRENT_DATE - INTERVAL '13 months'
    GROUP BY DATE_TRUNC('month', reported_date)::DATE
)
SELECT 
    m.month,
    COALESCE(md.new_reports, 0) as new_reports,
    COALESCE(md.resolved, 0) as resolved,
    COALESCE(md.critical_cases, 0) as critical_cases,
    COALESCE(md.total_amount_reported, 0) as total_amount_reported,
    LAG(COALESCE(md.new_reports, 0)) OVER (ORDER BY m.month) as prev_month_new,
    ROUND(
        100.0 * (COALESCE(md.new_reports, 0) - LAG(COALESCE(md.new_reports, 0)) OVER (ORDER BY m.month)) / 
        NULLIF(LAG(COALESCE(md.new_reports, 0)) OVER (ORDER BY m.month), 0)
    , 2) as pct_change
FROM months m
LEFT JOIN monthly_data md ON m.month = md.month
ORDER BY m.month;

COMMENT ON VIEW vw_monthly_trends IS 'Monthly trends with gap filling using generate_series';

-- ============================================================================
-- Weekly Resolution Summary
-- ============================================================================

CREATE OR REPLACE VIEW vw_weekly_resolution_summary AS
SELECT 
    DATE_TRUNC('week', resolution_date)::DATE as week_starting,
    COUNT(*) as resolved_count,
    COUNT(DISTINCT department_id) as departments_active,
    COUNT(DISTINCT assigned_to) as officers_involved,
    ROUND(AVG(EXTRACT(EPOCH FROM (resolution_date - reported_date))/86400)::NUMERIC, 2) as avg_days_to_resolve,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (resolution_date - reported_date))/86400)::NUMERIC, 2) as median_days_to_resolve,
    SUM(actual_amount) as total_amount_confirmed,
    COUNT(*) FILTER (WHERE resolution_date <= target_resolution_date) as within_sla,
    COUNT(*) FILTER (WHERE resolution_date > target_resolution_date) as sla_breached
FROM reports
WHERE resolution_date IS NOT NULL
AND resolution_date >= CURRENT_DATE - INTERVAL '13 weeks'
GROUP BY DATE_TRUNC('week', resolution_date)::DATE
ORDER BY week_starting DESC;

-- ============================================================================
-- SLA Compliance by Department
-- ============================================================================

CREATE OR REPLACE VIEW vw_sla_compliance AS
SELECT 
    d.name as department,
    COUNT(*) as total_resolved,
    COUNT(*) FILTER (WHERE r.resolution_date <= r.target_resolution_date) as within_sla,
    COUNT(*) FILTER (WHERE r.resolution_date > r.target_resolution_date) as breached_sla,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE r.resolution_date <= r.target_resolution_date) / 
        NULLIF(COUNT(*), 0)
    , 2) as compliance_rate_pct,
    ROUND(AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400)::NUMERIC, 2) as avg_resolution_days,
    AVG(EXTRACT(EPOCH FROM (r.target_resolution_date - r.resolution_date::DATE))/86400)::INTEGER as avg_days_early_late
FROM reports r
JOIN departments d ON r.department_id = d.department_id
WHERE r.resolution_date IS NOT NULL
AND r.reported_date >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY d.name
ORDER BY compliance_rate_pct DESC;

-- ============================================================================
-- Officer Workload View
-- ============================================================================

CREATE OR REPLACE VIEW vw_officer_workload AS
SELECT 
    o.employee_number,
    o.first_name || ' ' || o.last_name as officer_name,
    d.name as department,
    o.max_caseload,
    COUNT(*) FILTER (WHERE s.is_terminal = FALSE) as active_cases,
    COUNT(*) FILTER (WHERE s.is_terminal = FALSE AND r.priority = 1) as critical_cases,
    COUNT(*) FILTER (WHERE s.is_terminal = FALSE AND r.target_resolution_date < CURRENT_DATE) as overdue_cases,
    COUNT(*) FILTER (WHERE r.resolution_date IS NOT NULL AND r.reported_date >= CURRENT_DATE - INTERVAL '30 days') as resolved_last_30_days,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE s.is_terminal = FALSE) / NULLIF(o.max_caseload, 0)
    , 2) as workload_pct
FROM officers o
JOIN departments d ON o.department_id = d.department_id
LEFT JOIN reports r ON o.officer_id = r.assigned_to
LEFT JOIN statuses s ON r.status_id = s.status_id
WHERE o.is_active = TRUE
GROUP BY o.officer_id, o.employee_number, o.first_name, o.last_name, d.name, o.max_caseload
ORDER BY workload_pct DESC;

-- ============================================================================
-- Escalation Analysis View
-- ============================================================================

CREATE OR REPLACE VIEW vw_escalation_analysis AS
SELECT 
    df.name as from_department,
    dt.name as to_department,
    DATE_TRUNC('month', e.escalated_at)::DATE as month,
    COUNT(*) as escalation_count,
    COUNT(*) FILTER (WHERE e.resolved_at IS NOT NULL) as resolved,
    COUNT(*) FILTER (WHERE e.resolved_at IS NULL) as pending,
    ROUND(AVG(EXTRACT(EPOCH FROM (e.resolved_at - e.escalated_at))/86400)::NUMERIC, 2) as avg_days_to_resolve
FROM escalations e
LEFT JOIN departments df ON e.escalated_from = df.department_id
JOIN departments dt ON e.escalated_to = dt.department_id
WHERE e.escalated_at >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY df.name, dt.name, DATE_TRUNC('month', e.escalated_at)::DATE
ORDER BY month DESC, escalation_count DESC;

-- ============================================================================
-- Year-over-Year Comparison
-- ============================================================================

CREATE OR REPLACE VIEW vw_yoy_comparison AS
WITH yearly_stats AS (
    SELECT 
        EXTRACT(YEAR FROM reported_date)::INTEGER as year,
        COUNT(*) as total_reports,
        COUNT(*) FILTER (WHERE resolution_date IS NOT NULL) as resolved,
        COUNT(*) FILTER (WHERE priority = 1) as critical,
        SUM(estimated_amount) as total_amount,
        ROUND(AVG(EXTRACT(EPOCH FROM (resolution_date - reported_date))/86400)::NUMERIC, 2) as avg_resolution_days
    FROM reports
    GROUP BY EXTRACT(YEAR FROM reported_date)
)
SELECT 
    year,
    total_reports,
    resolved,
    critical,
    total_amount,
    avg_resolution_days,
    LAG(total_reports) OVER (ORDER BY year) as prev_year_reports,
    total_reports - LAG(total_reports) OVER (ORDER BY year) as reports_change,
    ROUND(
        100.0 * (total_reports - LAG(total_reports) OVER (ORDER BY year)) / 
        NULLIF(LAG(total_reports) OVER (ORDER BY year), 0)
    , 2) as pct_change
FROM yearly_stats
ORDER BY year DESC;

-- ============================================================================
-- Stale Cases View (No activity in X days)
-- ============================================================================

CREATE OR REPLACE VIEW vw_stale_cases AS
SELECT 
    r.report_number,
    r.title,
    d.name as department,
    c.name as category,
    s.name as status,
    o.first_name || ' ' || o.last_name as assigned_officer,
    r.reported_date,
    r.last_activity_date,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - r.last_activity_date))/86400 as days_since_activity,
    r.target_resolution_date,
    r.target_resolution_date - CURRENT_DATE as days_until_sla_breach
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN categories c ON r.category_id = c.category_id
JOIN statuses s ON r.status_id = s.status_id
LEFT JOIN officers o ON r.assigned_to = o.officer_id
WHERE s.is_terminal = FALSE
AND r.last_activity_date < CURRENT_TIMESTAMP - INTERVAL '7 days'
ORDER BY days_since_activity DESC;

-- ============================================================================
-- Priority Distribution Over Time
-- ============================================================================

CREATE OR REPLACE VIEW vw_priority_distribution AS
SELECT 
    DATE_TRUNC('month', reported_date)::DATE as month,
    COUNT(*) FILTER (WHERE priority = 1) as priority_1_critical,
    COUNT(*) FILTER (WHERE priority = 2) as priority_2_high,
    COUNT(*) FILTER (WHERE priority = 3) as priority_3_medium,
    COUNT(*) FILTER (WHERE priority = 4) as priority_4_low,
    COUNT(*) FILTER (WHERE priority = 5) as priority_5_minimal,
    COUNT(*) as total,
    ROUND(100.0 * COUNT(*) FILTER (WHERE priority <= 2) / NULLIF(COUNT(*), 0), 2) as critical_high_pct
FROM reports
WHERE reported_date >= CURRENT_DATE - INTERVAL '24 months'
GROUP BY DATE_TRUNC('month', reported_date)::DATE
ORDER BY month DESC;

-- ============================================================================
-- Materialized Views for Performance
-- ============================================================================

-- Department Performance Summary (Refresh nightly)
CREATE MATERIALIZED VIEW mv_department_performance AS
SELECT 
    d.department_id,
    d.name as department_name,
    DATE_TRUNC('month', r.reported_date)::DATE as month,
    COUNT(*) as total_reports,
    COUNT(*) FILTER (WHERE s.is_terminal) as resolved,
    COUNT(*) FILTER (WHERE NOT s.is_terminal) as open,
    COUNT(*) FILTER (WHERE r.priority <= 2) as high_priority,
    ROUND(AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400)::NUMERIC 
        FILTER (WHERE r.resolution_date IS NOT NULL), 2) as avg_resolution_days,
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.resolution_date <= r.target_resolution_date) / 
        NULLIF(COUNT(*) FILTER (WHERE r.resolution_date IS NOT NULL), 0), 2) as sla_compliance_pct,
    SUM(r.estimated_amount) as total_amount_reported,
    SUM(r.actual_amount) FILTER (WHERE r.resolution_date IS NOT NULL) as total_amount_confirmed
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN statuses s ON r.status_id = s.status_id
WHERE r.reported_date >= CURRENT_DATE - INTERVAL '24 months'
GROUP BY d.department_id, d.name, DATE_TRUNC('month', r.reported_date)::DATE
WITH DATA;

CREATE UNIQUE INDEX idx_mv_dept_perf ON mv_department_performance(department_id, month);

-- Time to Resolution Analysis (Refresh weekly)
CREATE MATERIALIZED VIEW mv_resolution_time_analysis AS
SELECT 
    c.category_id,
    c.name as category_name,
    r.priority,
    DATE_TRUNC('quarter', r.reported_date)::DATE as quarter,
    COUNT(*) as cases_resolved,
    ROUND(AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400)::NUMERIC, 2) as avg_days,
    ROUND(MIN(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400)::NUMERIC, 2) as min_days,
    ROUND(MAX(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400)::NUMERIC, 2) as max_days,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400
    )::NUMERIC, 2) as median_days,
    ROUND(PERCENTILE_CONT(0.9) WITHIN GROUP (
        ORDER BY EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400
    )::NUMERIC, 2) as p90_days
FROM reports r
JOIN categories c ON r.category_id = c.category_id
WHERE r.resolution_date IS NOT NULL
GROUP BY c.category_id, c.name, r.priority, DATE_TRUNC('quarter', r.reported_date)::DATE
WITH DATA;

CREATE UNIQUE INDEX idx_mv_resolution_time ON mv_resolution_time_analysis(category_id, priority, quarter);

-- ============================================================================
-- Refresh Materialized Views Function
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_refresh_materialized_views()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_department_performance;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resolution_time_analysis;
    RAISE NOTICE 'Materialized views refreshed at %', CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;
