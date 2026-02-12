-- ============================================================================
-- Quarterly Audit Report
-- Run: psql -d corruption_auditor -f quarterly_audit_report.sql
-- Description: Comprehensive quarterly audit for compliance review
-- ============================================================================

\echo '=============================================================================='
\echo 'CORRUPTION REPORT AUDITOR - QUARTERLY AUDIT REPORT'
\echo 'Quarter:' :CURRENT_DATE
\echo 'Generated:' :CURRENT_TIMESTAMP
\echo '=============================================================================='
\echo ''

\pset border 2
\pset linestyle unicode
\pset expanded off

-- ============================================================================
-- Executive Dashboard
-- ============================================================================
\echo '>>> EXECUTIVE DASHBOARD'
\echo ''

WITH quarterly_stats AS (
    SELECT 
        DATE_TRUNC('quarter', CURRENT_DATE) as current_quarter,
        DATE_TRUNC('quarter', CURRENT_DATE - INTERVAL '3 months') as prev_quarter
),
current_q AS (
    SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE s.is_terminal AND s.name = 'resolved') as resolved,
        COUNT(*) FILTER (WHERE s.is_terminal AND s.name = 'dismissed') as dismissed,
        COUNT(*) FILTER (WHERE NOT s.is_terminal) as open,
        SUM(r.estimated_amount) as amount_reported,
        SUM(r.actual_amount) as amount_confirmed,
        AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400) 
            FILTER (WHERE r.resolution_date IS NOT NULL) as avg_days
    FROM reports r
    JOIN statuses s ON r.status_id = s.status_id
    CROSS JOIN quarterly_stats qs
    WHERE r.reported_date >= qs.current_quarter
),
prev_q AS (
    SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE s.is_terminal AND s.name = 'resolved') as resolved,
        SUM(r.estimated_amount) as amount_reported,
        AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400) 
            FILTER (WHERE r.resolution_date IS NOT NULL) as avg_days
    FROM reports r
    JOIN statuses s ON r.status_id = s.status_id
    CROSS JOIN quarterly_stats qs
    WHERE r.reported_date >= qs.prev_quarter
    AND r.reported_date < qs.current_quarter
)
SELECT 
    'Total Reports' as "Metric",
    cq.total::TEXT as "Current Quarter",
    pq.total::TEXT as "Previous Quarter",
    CASE WHEN pq.total > 0 THEN ROUND(100.0 * (cq.total - pq.total) / pq.total, 1)::TEXT || '%' ELSE 'N/A' END as "Change"
FROM current_q cq, prev_q pq
UNION ALL
SELECT 
    'Resolved Cases',
    cq.resolved::TEXT,
    pq.resolved::TEXT,
    CASE WHEN pq.resolved > 0 THEN ROUND(100.0 * (cq.resolved - pq.resolved) / pq.resolved, 1)::TEXT || '%' ELSE 'N/A' END
FROM current_q cq, prev_q pq
UNION ALL
SELECT 
    'Resolution Rate',
    ROUND(100.0 * cq.resolved / NULLIF(cq.total, 0), 1)::TEXT || '%',
    ROUND(100.0 * pq.resolved / NULLIF(pq.total, 0), 1)::TEXT || '%',
    '-'
FROM current_q cq, prev_q pq
UNION ALL
SELECT 
    'Avg Resolution (Days)',
    ROUND(cq.avg_days::NUMERIC, 1)::TEXT,
    ROUND(pq.avg_days::NUMERIC, 1)::TEXT,
    ROUND((cq.avg_days - pq.avg_days)::NUMERIC, 1)::TEXT
FROM current_q cq, prev_q pq
UNION ALL
SELECT 
    'Amount Reported',
    '$' || TO_CHAR(cq.amount_reported, 'FM999,999,999,999'),
    '$' || TO_CHAR(pq.amount_reported, 'FM999,999,999,999'),
    CASE WHEN pq.amount_reported > 0 THEN ROUND(100.0 * (cq.amount_reported - pq.amount_reported) / pq.amount_reported, 1)::TEXT || '%' ELSE 'N/A' END
FROM current_q cq, prev_q pq
UNION ALL
SELECT 
    'Amount Confirmed',
    '$' || TO_CHAR(cq.amount_confirmed, 'FM999,999,999,999'),
    '-',
    '-'
FROM current_q cq, prev_q pq;

\echo ''

-- ============================================================================
-- Department Performance Scorecard
-- ============================================================================
\echo '>>> DEPARTMENT PERFORMANCE SCORECARD'
\echo ''

SELECT 
    d.name as "Department",
    COUNT(*) as "Cases Received",
    COUNT(*) FILTER (WHERE s.is_terminal) as "Cases Closed",
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.is_terminal) / NULLIF(COUNT(*), 0), 1) as "Closure Rate %",
    ROUND(AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400) 
        FILTER (WHERE r.resolution_date IS NOT NULL)::NUMERIC, 1) as "Avg Days",
    ROUND(100.0 * COUNT(*) FILTER (WHERE r.resolution_date <= r.target_resolution_date) / 
        NULLIF(COUNT(*) FILTER (WHERE r.resolution_date IS NOT NULL), 0), 1) as "SLA Compliance %",
    COUNT(*) FILTER (WHERE NOT s.is_terminal AND r.target_resolution_date < CURRENT_DATE) as "Overdue",
    -- Performance Score: 40% closure + 40% SLA + 20% speed
    ROUND(
        (COALESCE(100.0 * COUNT(*) FILTER (WHERE s.is_terminal) / NULLIF(COUNT(*), 0), 0) * 0.4) +
        (COALESCE(100.0 * COUNT(*) FILTER (WHERE r.resolution_date <= r.target_resolution_date) / 
            NULLIF(COUNT(*) FILTER (WHERE r.resolution_date IS NOT NULL), 0), 0) * 0.4) +
        (GREATEST(0, 100 - COALESCE(AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400) 
            FILTER (WHERE r.resolution_date IS NOT NULL), 100)) * 0.2)
    , 1) as "Score"
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN statuses s ON r.status_id = s.status_id
WHERE r.reported_date >= DATE_TRUNC('quarter', CURRENT_DATE)
GROUP BY d.name
ORDER BY "Score" DESC;

\echo ''

-- ============================================================================
-- SLA Compliance Analysis
-- ============================================================================
\echo '>>> SLA COMPLIANCE ANALYSIS'
\echo ''

SELECT 
    CASE 
        WHEN r.resolution_date <= r.target_resolution_date THEN 'Within SLA'
        WHEN r.resolution_date <= r.target_resolution_date + INTERVAL '7 days' THEN '1-7 Days Over'
        WHEN r.resolution_date <= r.target_resolution_date + INTERVAL '14 days' THEN '8-14 Days Over'
        WHEN r.resolution_date <= r.target_resolution_date + INTERVAL '30 days' THEN '15-30 Days Over'
        ELSE 'Over 30 Days Late'
    END as "SLA Status",
    COUNT(*) as "Cases",
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) as "Percentage",
    '$' || TO_CHAR(SUM(r.estimated_amount), 'FM999,999,999') as "Amount Involved"
FROM reports r
WHERE r.resolution_date IS NOT NULL
AND r.reported_date >= DATE_TRUNC('quarter', CURRENT_DATE)
GROUP BY 
    CASE 
        WHEN r.resolution_date <= r.target_resolution_date THEN 'Within SLA'
        WHEN r.resolution_date <= r.target_resolution_date + INTERVAL '7 days' THEN '1-7 Days Over'
        WHEN r.resolution_date <= r.target_resolution_date + INTERVAL '14 days' THEN '8-14 Days Over'
        WHEN r.resolution_date <= r.target_resolution_date + INTERVAL '30 days' THEN '15-30 Days Over'
        ELSE 'Over 30 Days Late'
    END
ORDER BY 
    CASE 
        WHEN COUNT(*) > 0 AND MIN(CASE 
            WHEN r.resolution_date <= r.target_resolution_date THEN 1
            WHEN r.resolution_date <= r.target_resolution_date + INTERVAL '7 days' THEN 2
            WHEN r.resolution_date <= r.target_resolution_date + INTERVAL '14 days' THEN 3
            WHEN r.resolution_date <= r.target_resolution_date + INTERVAL '30 days' THEN 4
            ELSE 5 END) ELSE 99 
    END;

\echo ''

-- ============================================================================
-- Escalation Summary
-- ============================================================================
\echo '>>> ESCALATION SUMMARY'
\echo ''

SELECT 
    COALESCE(df.name, 'Direct to ACC') as "From Department",
    dt.name as "To Department",
    COUNT(*) as "Escalations",
    COUNT(*) FILTER (WHERE e.resolved_at IS NOT NULL) as "Resolved",
    COUNT(*) FILTER (WHERE e.resolved_at IS NULL) as "Pending",
    ROUND(AVG(EXTRACT(EPOCH FROM (e.resolved_at - e.escalated_at))/86400) 
        FILTER (WHERE e.resolved_at IS NOT NULL)::NUMERIC, 1) as "Avg Days to Resolve"
FROM escalations e
LEFT JOIN departments df ON e.escalated_from = df.department_id
JOIN departments dt ON e.escalated_to = dt.department_id
WHERE e.escalated_at >= DATE_TRUNC('quarter', CURRENT_DATE)
GROUP BY df.name, dt.name
ORDER BY COUNT(*) DESC;

\echo ''

-- ============================================================================
-- High-Value Cases Review
-- ============================================================================
\echo '>>> HIGH-VALUE CASES (> $10,000,000)'
\echo ''

SELECT 
    r.report_number as "Report #",
    c.name as "Category",
    d.name as "Department",
    s.name as "Status",
    '$' || TO_CHAR(r.estimated_amount, 'FM999,999,999,999') as "Estimated",
    '$' || TO_CHAR(r.actual_amount, 'FM999,999,999,999') as "Confirmed",
    r.reported_date::DATE as "Filed",
    CASE WHEN r.resolution_date IS NOT NULL 
         THEN r.resolution_date::DATE::TEXT 
         ELSE 'Open' END as "Resolved"
FROM reports r
JOIN categories c ON r.category_id = c.category_id
JOIN departments d ON r.department_id = d.department_id
JOIN statuses s ON r.status_id = s.status_id
WHERE r.estimated_amount >= 10000000
AND r.reported_date >= DATE_TRUNC('quarter', CURRENT_DATE) - INTERVAL '1 quarter'
ORDER BY r.estimated_amount DESC
LIMIT 15;

\echo ''

-- ============================================================================
-- Complainant Source Analysis
-- ============================================================================
\echo '>>> COMPLAINANT SOURCE ANALYSIS'
\echo ''

SELECT 
    ct.name as "Complainant Type",
    COUNT(*) as "Reports",
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) as "% of Total",
    COUNT(*) FILTER (WHERE s.is_terminal AND s.name = 'resolved') as "Led to Resolution",
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.is_terminal AND s.name = 'resolved') / 
        NULLIF(COUNT(*), 0), 1) as "Resolution Rate %"
FROM reports r
LEFT JOIN complainant_types ct ON r.complainant_type_id = ct.complainant_type_id
JOIN statuses s ON r.status_id = s.status_id
WHERE r.reported_date >= DATE_TRUNC('quarter', CURRENT_DATE)
GROUP BY ct.name
ORDER BY COUNT(*) DESC;

\echo ''

-- ============================================================================
-- Audit Trail Summary
-- ============================================================================
\echo '>>> AUDIT TRAIL SUMMARY (CHANGES THIS QUARTER)'
\echo ''

SELECT 
    operation as "Operation",
    COUNT(*) as "Count",
    COUNT(DISTINCT record_id) as "Unique Records",
    MIN(performed_at)::DATE as "First",
    MAX(performed_at)::DATE as "Last"
FROM audit_log
WHERE performed_at >= DATE_TRUNC('quarter', CURRENT_DATE)
AND table_name = 'reports'
GROUP BY operation
ORDER BY COUNT(*) DESC;

\echo ''

-- ============================================================================
-- Open Cases Older Than 180 Days (Compliance Alert)
-- ============================================================================
\echo '>>> COMPLIANCE ALERT: CASES OPEN > 180 DAYS'
\echo ''

SELECT 
    r.report_number as "Report #",
    LEFT(r.title, 35) || '...' as "Title",
    d.name as "Dept",
    c.name as "Category",
    EXTRACT(DAY FROM AGE(CURRENT_TIMESTAMP, r.reported_date))::INTEGER as "Days Open",
    s.name as "Status",
    COALESCE(o.first_name || ' ' || o.last_name, 'UNASSIGNED') as "Assigned"
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN categories c ON r.category_id = c.category_id
JOIN statuses s ON r.status_id = s.status_id
LEFT JOIN officers o ON r.assigned_to = o.officer_id
WHERE NOT s.is_terminal
AND AGE(CURRENT_TIMESTAMP, r.reported_date) > INTERVAL '180 days'
ORDER BY r.reported_date;

\echo ''
\echo '=============================================================================='
\echo 'END OF QUARTERLY AUDIT REPORT'
\echo '=============================================================================='
