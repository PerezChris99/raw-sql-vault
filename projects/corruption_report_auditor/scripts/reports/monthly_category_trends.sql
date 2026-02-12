-- ============================================================================
-- Monthly Category Trends Report
-- Run: psql -d corruption_auditor -f monthly_category_trends.sql
-- Description: Monthly analysis of corruption trends by category
-- ============================================================================

\echo '=============================================================================='
\echo 'CORRUPTION REPORT AUDITOR - MONTHLY CATEGORY TRENDS'
\echo 'Analysis Period: Last 12 Months'
\echo 'Generated:' :CURRENT_TIMESTAMP
\echo '=============================================================================='
\echo ''

\pset border 2
\pset linestyle unicode

-- ============================================================================
-- Category Distribution - Current Month vs Previous
-- ============================================================================
\echo '>>> CATEGORY DISTRIBUTION - MONTH OVER MONTH'
\echo ''

WITH current_month AS (
    SELECT 
        c.category_id,
        c.name,
        COUNT(*) as count,
        SUM(r.estimated_amount) as amount
    FROM reports r
    JOIN categories c ON r.category_id = c.category_id
    WHERE DATE_TRUNC('month', r.reported_date) = DATE_TRUNC('month', CURRENT_DATE)
    GROUP BY c.category_id, c.name
),
prev_month AS (
    SELECT 
        c.category_id,
        COUNT(*) as count,
        SUM(r.estimated_amount) as amount
    FROM reports r
    JOIN categories c ON r.category_id = c.category_id
    WHERE DATE_TRUNC('month', r.reported_date) = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
    GROUP BY c.category_id
)
SELECT 
    cm.name as "Category",
    COALESCE(cm.count, 0) as "This Month",
    COALESCE(pm.count, 0) as "Last Month",
    COALESCE(cm.count, 0) - COALESCE(pm.count, 0) as "Change",
    CASE 
        WHEN pm.count IS NULL OR pm.count = 0 THEN 'NEW'
        ELSE ROUND(100.0 * (cm.count - pm.count) / pm.count, 1)::TEXT || '%'
    END as "% Change",
    '$' || TO_CHAR(COALESCE(cm.amount, 0), 'FM999,999,999') as "Amount"
FROM current_month cm
LEFT JOIN prev_month pm ON cm.category_id = pm.category_id
ORDER BY cm.count DESC;

\echo ''

-- ============================================================================
-- 12-Month Trend by Category (Pivoted)
-- ============================================================================
\echo '>>> 12-MONTH TREND (REPORTS PER CATEGORY)'
\echo ''

WITH monthly AS (
    SELECT 
        c.name as category,
        DATE_TRUNC('month', r.reported_date) as month,
        COUNT(*) as count
    FROM reports r
    JOIN categories c ON r.category_id = c.category_id
    WHERE r.reported_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '11 months')
    GROUP BY c.name, DATE_TRUNC('month', r.reported_date)
)
SELECT 
    category as "Category",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '11 months') THEN count ELSE 0 END) as "M-11",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '10 months') THEN count ELSE 0 END) as "M-10",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '9 months') THEN count ELSE 0 END) as "M-9",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '8 months') THEN count ELSE 0 END) as "M-8",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '7 months') THEN count ELSE 0 END) as "M-7",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '6 months') THEN count ELSE 0 END) as "M-6",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '5 months') THEN count ELSE 0 END) as "M-5",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '4 months') THEN count ELSE 0 END) as "M-4",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '3 months') THEN count ELSE 0 END) as "M-3",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '2 months') THEN count ELSE 0 END) as "M-2",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month') THEN count ELSE 0 END) as "M-1",
    SUM(CASE WHEN month = DATE_TRUNC('month', CURRENT_DATE) THEN count ELSE 0 END) as "M-0"
FROM monthly
GROUP BY category
ORDER BY SUM(count) DESC
LIMIT 10;

\echo ''

-- ============================================================================
-- Top Growing Categories
-- ============================================================================
\echo '>>> FASTEST GROWING CATEGORIES (3-MONTH TREND)'
\echo ''

WITH recent AS (
    SELECT 
        c.name,
        COUNT(*) as recent_count
    FROM reports r
    JOIN categories c ON r.category_id = c.category_id
    WHERE r.reported_date >= CURRENT_DATE - INTERVAL '3 months'
    GROUP BY c.name
),
previous AS (
    SELECT 
        c.name,
        COUNT(*) as prev_count
    FROM reports r
    JOIN categories c ON r.category_id = c.category_id
    WHERE r.reported_date >= CURRENT_DATE - INTERVAL '6 months'
    AND r.reported_date < CURRENT_DATE - INTERVAL '3 months'
    GROUP BY c.name
)
SELECT 
    r.name as "Category",
    COALESCE(p.prev_count, 0) as "Prev 3 Months",
    r.recent_count as "Recent 3 Months",
    r.recent_count - COALESCE(p.prev_count, 0) as "Growth",
    CASE 
        WHEN p.prev_count IS NULL OR p.prev_count = 0 THEN '∞'
        ELSE ROUND(100.0 * (r.recent_count - p.prev_count) / p.prev_count, 1)::TEXT || '%'
    END as "Growth %",
    CASE 
        WHEN r.recent_count > COALESCE(p.prev_count, 0) * 1.2 THEN '⬆ INCREASING'
        WHEN r.recent_count < COALESCE(p.prev_count, 0) * 0.8 THEN '⬇ DECREASING'
        ELSE '➡ STABLE'
    END as "Trend"
FROM recent r
LEFT JOIN previous p ON r.name = p.name
ORDER BY (r.recent_count - COALESCE(p.prev_count, 0)) DESC
LIMIT 10;

\echo ''

-- ============================================================================
-- Resolution Rates by Category
-- ============================================================================
\echo '>>> RESOLUTION RATES BY CATEGORY (LAST 6 MONTHS)'
\echo ''

SELECT 
    c.name as "Category",
    COUNT(*) as "Total Filed",
    COUNT(*) FILTER (WHERE s.is_terminal AND s.name = 'resolved') as "Resolved",
    COUNT(*) FILTER (WHERE s.is_terminal AND s.name = 'dismissed') as "Dismissed",
    COUNT(*) FILTER (WHERE NOT s.is_terminal) as "Still Open",
    ROUND(100.0 * COUNT(*) FILTER (WHERE s.is_terminal AND s.name = 'resolved') / 
        NULLIF(COUNT(*), 0), 1) || '%' as "Resolution Rate",
    ROUND(AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400) 
        FILTER (WHERE r.resolution_date IS NOT NULL)::NUMERIC, 1) as "Avg Days"
FROM reports r
JOIN categories c ON r.category_id = c.category_id
JOIN statuses s ON r.status_id = s.status_id
WHERE r.reported_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY c.name
HAVING COUNT(*) >= 1
ORDER BY COUNT(*) DESC;

\echo ''

-- ============================================================================
-- Amount Analysis by Category
-- ============================================================================
\echo '>>> FINANCIAL IMPACT BY CATEGORY (LAST 12 MONTHS)'
\echo ''

SELECT 
    c.name as "Category",
    COUNT(*) as "Cases",
    '$' || TO_CHAR(SUM(r.estimated_amount), 'FM999,999,999,999') as "Total Reported",
    '$' || TO_CHAR(AVG(r.estimated_amount), 'FM999,999,999') as "Avg per Case",
    '$' || TO_CHAR(MAX(r.estimated_amount), 'FM999,999,999') as "Largest Case",
    '$' || TO_CHAR(SUM(r.actual_amount), 'FM999,999,999,999') as "Confirmed Amount"
FROM reports r
JOIN categories c ON r.category_id = c.category_id
WHERE r.reported_date >= CURRENT_DATE - INTERVAL '12 months'
AND r.estimated_amount IS NOT NULL
GROUP BY c.name
ORDER BY SUM(r.estimated_amount) DESC;

\echo ''

-- ============================================================================
-- Category by Department Heatmap
-- ============================================================================
\echo '>>> CATEGORY BY DEPARTMENT (LAST 6 MONTHS)'
\echo ''

SELECT 
    d.name as "Department",
    COUNT(*) FILTER (WHERE c.name LIKE '%Bribery%') as "Bribery",
    COUNT(*) FILTER (WHERE c.name LIKE '%Embezzlement%') as "Embezzle",
    COUNT(*) FILTER (WHERE c.name LIKE '%Fraud%') as "Fraud",
    COUNT(*) FILTER (WHERE c.name LIKE '%Procurement%') as "Procure",
    COUNT(*) FILTER (WHERE c.name LIKE '%Ghost%') as "Ghost",
    COUNT(*) FILTER (WHERE c.name LIKE '%Kickback%') as "Kickback",
    COUNT(*) as "Total"
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN categories c ON r.category_id = c.category_id
WHERE r.reported_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY d.name
ORDER BY COUNT(*) DESC;

\echo ''
\echo '=============================================================================='
\echo 'END OF MONTHLY CATEGORY TRENDS'
\echo '=============================================================================='
