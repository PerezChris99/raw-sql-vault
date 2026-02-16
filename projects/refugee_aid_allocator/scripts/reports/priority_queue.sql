-- ============================================================================
-- Refugee Aid Allocator - Priority Queue Report
-- PostgreSQL 14+
-- Report: User's sample query - RANK() OVER (ORDER BY need_score DESC)
-- ============================================================================

\echo '=============================================='
\echo 'REFUGEE AID ALLOCATOR - PRIORITY QUEUE'
\echo 'Generated: ' :NOW
\echo '=============================================='
\echo ''

-- ============================================================================
-- User's Sample Query Pattern
-- ============================================================================

\echo '>> USER SAMPLE QUERY (Bidibidi Camp)'
\echo '   SELECT refugee_id, RANK() OVER (ORDER BY need_score DESC) as priority'
\echo '   FROM needs WHERE camp = ''Bidibidi'''
\echo ''

SELECT 
    refugee_id,
    RANK() OVER (ORDER BY need_score DESC) AS priority
FROM needs n
JOIN refugees r USING (refugee_id)
JOIN households h USING (household_id)
JOIN camps c USING (camp_id)
WHERE c.camp_name = 'Bidibidi'
  AND n.status = 'pending'
LIMIT 15;

\echo ''

-- ============================================================================
-- Full Priority Queue (All Camps)
-- ============================================================================

\echo '>> FULL PRIORITY QUEUE (Top 25)'
\echo ''

SELECT 
    RANK() OVER (ORDER BY n.need_score DESC) AS "#",
    r.first_name || ' ' || r.last_name AS "Refugee",
    c.camp_name AS "Camp",
    ac.category_name AS "Aid Type",
    ul.urgency_name AS "Urgency",
    n.need_score AS "Score",
    EXTRACT(DAY FROM NOW() - n.assessed_date)::INT || 'd' AS "Waiting"
FROM needs n
JOIN refugees r ON n.refugee_id = r.refugee_id
JOIN households h ON r.household_id = h.household_id
JOIN camps c ON h.camp_id = c.camp_id
JOIN aid_categories ac ON n.category_id = ac.category_id
JOIN urgency_levels ul ON n.urgency_id = ul.urgency_id
WHERE n.status = 'pending'
ORDER BY n.need_score DESC
LIMIT 25;

\echo ''

-- ============================================================================
-- Priority by Camp (Partitioned RANK)
-- ============================================================================

\echo '>> PRIORITY BY CAMP (Top 5 per camp)'
\echo ''

WITH ranked AS (
    SELECT 
        c.camp_name,
        r.first_name || ' ' || r.last_name AS refugee_name,
        n.need_score,
        RANK() OVER (PARTITION BY c.camp_id ORDER BY n.need_score DESC) AS camp_rank
    FROM needs n
    JOIN refugees r ON n.refugee_id = r.refugee_id
    JOIN households h ON r.household_id = h.household_id
    JOIN camps c ON h.camp_id = c.camp_id
    WHERE n.status = 'pending'
)
SELECT 
    camp_name AS "Camp",
    refugee_name AS "Refugee",
    need_score AS "Score",
    camp_rank AS "Camp Rank"
FROM ranked
WHERE camp_rank <= 5
ORDER BY camp_name, camp_rank;

\echo ''

-- ============================================================================
-- Priority Tiers (NTILE)
-- ============================================================================

\echo '>> PRIORITY TIERS (Quintiles)'
\echo ''

SELECT 
    NTILE(5) OVER (ORDER BY n.need_score DESC) AS "Tier",
    COUNT(*) AS "Count",
    ROUND(AVG(n.need_score), 1) AS "Avg Score",
    MIN(n.need_score) AS "Min Score",
    MAX(n.need_score) AS "Max Score"
FROM needs n
WHERE n.status = 'pending'
GROUP BY NTILE(5) OVER (ORDER BY n.need_score DESC)
ORDER BY 1;

\echo ''

-- ============================================================================
-- Urgency Breakdown
-- ============================================================================

\echo '>> URGENCY BREAKDOWN'
\echo ''

SELECT 
    ul.urgency_name AS "Urgency",
    COUNT(*) AS "Pending Needs",
    ROUND(AVG(n.need_score), 1) AS "Avg Score",
    COUNT(*) FILTER (WHERE EXTRACT(DAY FROM NOW() - n.assessed_date) > 7) AS ">7 Days"
FROM needs n
JOIN urgency_levels ul ON n.urgency_id = ul.urgency_id
WHERE n.status = 'pending'
GROUP BY ul.urgency_id, ul.urgency_name
ORDER BY ul.urgency_score DESC;

\echo ''
\echo '=============================================='
\echo 'END OF PRIORITY QUEUE REPORT'
\echo '=============================================='
