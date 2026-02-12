-- ============================================================================
-- Weekly Resolution Summary
-- Run: psql -d corruption_auditor -f weekly_resolution_summary.sql
-- Description: Weekly summary of resolved cases and performance metrics
-- ============================================================================

\echo '=============================================================================='
\echo 'CORRUPTION REPORT AUDITOR - WEEKLY RESOLUTION SUMMARY'
\echo 'Report Period: Last 7 Days'
\echo 'Generated:' :CURRENT_TIMESTAMP
\echo '=============================================================================='
\echo ''

\pset border 2
\pset linestyle unicode

-- ============================================================================
-- Week-over-Week Summary
-- ============================================================================
\echo '>>> WEEK-OVER-WEEK COMPARISON'
\echo ''

WITH this_week AS (
    SELECT 
        COUNT(*) as new_reports,
        COUNT(*) FILTER (WHERE resolution_date IS NOT NULL) as resolved,
        SUM(estimated_amount) as amount_reported,
        SUM(actual_amount) FILTER (WHERE resolution_date IS NOT NULL) as amount_confirmed,
        AVG(EXTRACT(EPOCH FROM (resolution_date - reported_date))/86400) 
            FILTER (WHERE resolution_date IS NOT NULL) as avg_resolution_days
    FROM reports
    WHERE reported_date >= CURRENT_DATE - INTERVAL '7 days'
),
last_week AS (
    SELECT 
        COUNT(*) as new_reports,
        COUNT(*) FILTER (WHERE resolution_date IS NOT NULL) as resolved,
        SUM(estimated_amount) as amount_reported,
        AVG(EXTRACT(EPOCH FROM (resolution_date - reported_date))/86400) 
            FILTER (WHERE resolution_date IS NOT NULL) as avg_resolution_days
    FROM reports
    WHERE reported_date >= CURRENT_DATE - INTERVAL '14 days'
    AND reported_date < CURRENT_DATE - INTERVAL '7 days'
)
SELECT 
    'This Week' as "Period",
    tw.new_reports as "New Reports",
    tw.resolved as "Resolved",
    ROUND(tw.avg_resolution_days::NUMERIC, 1) as "Avg Days to Resolve",
    '$' || TO_CHAR(tw.amount_reported, 'FM999,999,999') as "Amount Reported",
    '$' || TO_CHAR(tw.amount_confirmed, 'FM999,999,999') as "Amount Confirmed"
FROM this_week tw
UNION ALL
SELECT 
    'Last Week',
    lw.new_reports,
    lw.resolved,
    ROUND(lw.avg_resolution_days::NUMERIC, 1),
    '$' || TO_CHAR(lw.amount_reported, 'FM999,999,999'),
    '-'
FROM last_week lw
UNION ALL
SELECT 
    'Change (%)',
    ROUND(100.0 * (tw.new_reports - lw.new_reports) / NULLIF(lw.new_reports, 0))::INTEGER,
    ROUND(100.0 * (tw.resolved - lw.resolved) / NULLIF(lw.resolved, 0))::INTEGER,
    ROUND((tw.avg_resolution_days - lw.avg_resolution_days)::NUMERIC, 1),
    '-',
    '-'
FROM this_week tw, last_week lw;

\echo ''

-- ============================================================================
-- Resolved Cases This Week
-- ============================================================================
\echo '>>> CASES RESOLVED THIS WEEK'
\echo ''

SELECT 
    r.report_number as "Report #",
    LEFT(r.title, 40) as "Title",
    c.name as "Category",
    r.resolution_type as "Resolution",
    EXTRACT(DAY FROM (r.resolution_date - r.reported_date))::INTEGER as "Days Open",
    CASE WHEN r.resolution_date <= r.target_resolution_date THEN 'Yes' ELSE 'NO' END as "Within SLA"
FROM reports r
JOIN categories c ON r.category_id = c.category_id
WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY r.resolution_date DESC;

\echo ''

-- ============================================================================
-- Resolution by Department
-- ============================================================================
\echo '>>> RESOLUTION BY DEPARTMENT'
\echo ''

SELECT 
    d.name as "Department",
    COUNT(*) FILTER (WHERE r.reported_date >= CURRENT_DATE - INTERVAL '7 days') as "New This Week",
    COUNT(*) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days') as "Resolved This Week",
    COUNT(*) FILTER (WHERE s.is_terminal = FALSE) as "Still Open",
    ROUND(AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400) 
        FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days')::NUMERIC, 1) as "Avg Days",
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.resolution_date <= r.target_resolution_date 
        AND r.resolution_date >= CURRENT_DATE - INTERVAL '7 days') /
        NULLIF(COUNT(*) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days'), 0), 1) as "SLA %"
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN statuses s ON r.status_id = s.status_id
GROUP BY d.name
HAVING COUNT(*) FILTER (WHERE r.reported_date >= CURRENT_DATE - INTERVAL '7 days') > 0
    OR COUNT(*) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days') > 0
ORDER BY COUNT(*) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days') DESC;

\echo ''

-- ============================================================================
-- Officer Performance
-- ============================================================================
\echo '>>> OFFICER PERFORMANCE THIS WEEK'
\echo ''

SELECT 
    o.first_name || ' ' || o.last_name as "Officer",
    d.name as "Dept",
    COUNT(*) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days') as "Resolved",
    COUNT(*) FILTER (WHERE s.is_terminal = FALSE) as "Active Cases",
    ROUND(AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400) 
        FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days')::NUMERIC, 1) as "Avg Days",
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.is_terminal = FALSE) / 
        NULLIF(o.max_caseload, 0), 1) || '%' as "Workload"
FROM officers o
JOIN departments d ON o.department_id = d.department_id
LEFT JOIN reports r ON o.officer_id = r.assigned_to
LEFT JOIN statuses s ON r.status_id = s.status_id
WHERE o.is_active = TRUE
GROUP BY o.officer_id, o.first_name, o.last_name, d.name, o.max_caseload
HAVING COUNT(*) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days') > 0
ORDER BY COUNT(*) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days') DESC;

\echo ''

-- ============================================================================
-- SLA Compliance Summary
-- ============================================================================
\echo '>>> SLA COMPLIANCE (LAST 30 DAYS)'
\echo ''

SELECT 
    TO_CHAR(DATE_TRUNC('week', r.resolution_date), 'Mon DD') as "Week Of",
    COUNT(*) as "Total Resolved",
    COUNT(*) FILTER (WHERE r.resolution_date <= r.target_resolution_date) as "Within SLA",
    COUNT(*) FILTER (WHERE r.resolution_date > r.target_resolution_date) as "Breached SLA",
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.resolution_date <= r.target_resolution_date) / 
        NULLIF(COUNT(*), 0), 1) || '%' as "Compliance Rate"
FROM reports r
WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE_TRUNC('week', r.resolution_date)
ORDER BY DATE_TRUNC('week', r.resolution_date) DESC;

\echo ''

-- ============================================================================
-- Amount Recovery Summary
-- ============================================================================
\echo '>>> AMOUNT RECOVERY THIS WEEK'
\echo ''

SELECT 
    c.name as "Category",
    COUNT(*) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days' 
        AND r.actual_amount IS NOT NULL) as "Cases",
    '$' || TO_CHAR(SUM(r.estimated_amount) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days'), 
        'FM999,999,999') as "Estimated",
    '$' || TO_CHAR(SUM(r.actual_amount) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days'), 
        'FM999,999,999') as "Confirmed",
    ROUND(100.0 * SUM(r.actual_amount) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days') /
        NULLIF(SUM(r.estimated_amount) FILTER (WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days'), 0), 1) || '%' as "Recovery %"
FROM reports r
JOIN categories c ON r.category_id = c.category_id
WHERE r.resolution_date >= CURRENT_DATE - INTERVAL '7 days'
AND r.actual_amount IS NOT NULL
GROUP BY c.name
ORDER BY SUM(r.actual_amount) DESC;

\echo ''
\echo '=============================================================================='
\echo 'END OF WEEKLY RESOLUTION SUMMARY'
\echo '=============================================================================='
