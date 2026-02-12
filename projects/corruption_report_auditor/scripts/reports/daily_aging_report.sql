-- ============================================================================
-- Daily Aging Report
-- Run: psql -d corruption_auditor -f daily_aging_report.sql
-- Description: Shows all open cases grouped by age buckets
-- ============================================================================

\echo '=============================================================================='
\echo 'CORRUPTION REPORT AUDITOR - DAILY AGING REPORT'
\echo 'Generated:' :CURRENT_TIMESTAMP
\echo '=============================================================================='
\echo ''

-- Set output formatting
\pset border 2
\pset linestyle unicode
\pset null '(null)'

-- ============================================================================
-- Executive Summary
-- ============================================================================
\echo '>>> EXECUTIVE SUMMARY'
\echo ''

SELECT 
    COUNT(*) FILTER (WHERE s.is_terminal = FALSE) as "Total Open Cases",
    COUNT(*) FILTER (WHERE s.is_terminal = FALSE AND r.priority = 1) as "Critical Priority",
    COUNT(*) FILTER (WHERE s.is_terminal = FALSE AND r.target_resolution_date < CURRENT_DATE) as "Past SLA",
    COUNT(*) FILTER (WHERE s.is_terminal = FALSE AND AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '180 days') as "Over 180 Days",
    '$' || TO_CHAR(SUM(r.estimated_amount) FILTER (WHERE s.is_terminal = FALSE), 'FM999,999,999,999') as "Total Amount at Risk"
FROM reports r
JOIN statuses s ON r.status_id = s.status_id;

\echo ''

-- ============================================================================
-- Aging by Department
-- ============================================================================
\echo '>>> AGING BY DEPARTMENT'
\echo ''

SELECT 
    d.name as "Department",
    COUNT(*) as "Total",
    COUNT(*) FILTER (WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '30 days') as "0-30d",
    COUNT(*) FILTER (WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '30 days' 
                      AND AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '60 days') as "31-60d",
    COUNT(*) FILTER (WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '60 days' 
                      AND AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '90 days') as "61-90d",
    COUNT(*) FILTER (WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '90 days' 
                      AND AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '180 days') as "91-180d",
    COUNT(*) FILTER (WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '180 days') as "180d+"
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN statuses s ON r.status_id = s.status_id
WHERE s.is_terminal = FALSE
GROUP BY d.name
ORDER BY COUNT(*) FILTER (WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '180 days') DESC, COUNT(*) DESC;

\echo ''

-- ============================================================================
-- Aging by Category
-- ============================================================================
\echo '>>> AGING BY CATEGORY'
\echo ''

SELECT 
    c.name as "Category",
    COUNT(*) as "Total",
    COUNT(*) FILTER (WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '30 days') as "0-30d",
    COUNT(*) FILTER (WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '30 days' 
                      AND AGE(CURRENT_TIMESTAMP, r.reported_date) < INTERVAL '90 days') as "31-90d",
    COUNT(*) FILTER (WHERE AGE(CURRENT_TIMESTAMP, r.reported_date) >= INTERVAL '90 days') as "90d+",
    '$' || TO_CHAR(SUM(r.estimated_amount), 'FM999,999,999') as "Amount"
FROM reports r
JOIN categories c ON r.category_id = c.category_id
JOIN statuses s ON r.status_id = s.status_id
WHERE s.is_terminal = FALSE
GROUP BY c.name
ORDER BY COUNT(*) DESC;

\echo ''

-- ============================================================================
-- Critical Cases (Priority 1)
-- ============================================================================
\echo '>>> CRITICAL CASES REQUIRING IMMEDIATE ATTENTION'
\echo ''

SELECT 
    r.report_number as "Report #",
    LEFT(r.title, 40) || CASE WHEN LENGTH(r.title) > 40 THEN '...' ELSE '' END as "Title",
    d.name as "Dept",
    EXTRACT(DAY FROM AGE(CURRENT_TIMESTAMP, r.reported_date))::INTEGER || ' days' as "Age",
    r.target_resolution_date - CURRENT_DATE as "SLA Days Left",
    '$' || TO_CHAR(r.estimated_amount, 'FM999,999,999') as "Amount"
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN statuses s ON r.status_id = s.status_id
WHERE s.is_terminal = FALSE
AND r.priority = 1
ORDER BY r.reported_date
LIMIT 20;

\echo ''

-- ============================================================================
-- Cases Approaching SLA Breach (Next 7 Days)
-- ============================================================================
\echo '>>> SLA BREACH WARNING - NEXT 7 DAYS'
\echo ''

SELECT 
    r.report_number as "Report #",
    LEFT(r.title, 35) || '...' as "Title",
    s.name as "Status",
    r.target_resolution_date as "SLA Date",
    r.target_resolution_date - CURRENT_DATE as "Days Left",
    COALESCE(o.first_name || ' ' || LEFT(o.last_name, 1) || '.', 'Unassigned') as "Officer"
FROM reports r
JOIN statuses s ON r.status_id = s.status_id
LEFT JOIN officers o ON r.assigned_to = o.officer_id
WHERE s.is_terminal = FALSE
AND r.target_resolution_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
ORDER BY r.target_resolution_date;

\echo ''

-- ============================================================================
-- Stale Cases (No activity in 14+ days)
-- ============================================================================
\echo '>>> STALE CASES - NO ACTIVITY IN 14+ DAYS'
\echo ''

SELECT 
    r.report_number as "Report #",
    d.name as "Dept",
    s.name as "Status",
    EXTRACT(DAY FROM AGE(CURRENT_TIMESTAMP, r.last_activity_date))::INTEGER as "Days Inactive",
    COALESCE(o.first_name || ' ' || o.last_name, 'Unassigned') as "Assigned To"
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN statuses s ON r.status_id = s.status_id
LEFT JOIN officers o ON r.assigned_to = o.officer_id
WHERE s.is_terminal = FALSE
AND r.last_activity_date < CURRENT_TIMESTAMP - INTERVAL '14 days'
ORDER BY r.last_activity_date
LIMIT 15;

\echo ''
\echo '=============================================================================='
\echo 'END OF DAILY AGING REPORT'
\echo '=============================================================================='
