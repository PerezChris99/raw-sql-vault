-- ============================================================================
-- Fishery Quota Compliance Checker - Quota Usage Report
-- PostgreSQL 14+
-- Report: User's sample query - rolling window sums
-- ============================================================================

\echo '=============================================='
\echo 'FISHERY QUOTA CHECKER - ROLLING QUOTAS'
\echo '=============================================='
\echo ''

-- ============================================================================
-- User's Sample Query
-- ============================================================================

\echo '>> USER SAMPLE QUERY'
\echo '   SUM(catch_weight) OVER (PARTITION BY month ORDER BY date ROWS 30 PRECEDING)'
\echo ''

SELECT 
    fisher_id,
    species_id,
    catch_date,
    catch_weight_kg AS "Catch (kg)",
    SUM(catch_weight_kg) OVER (
        PARTITION BY fisher_id, DATE_TRUNC('month', catch_date)
        ORDER BY catch_date
        ROWS 30 PRECEDING
    ) AS "Quota Used (30d)"
FROM catches
WHERE catch_date >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY fisher_id, catch_date
LIMIT 15;

\echo ''

-- ============================================================================
-- Quota Compliance Status
-- ============================================================================

\echo '>> QUOTA COMPLIANCE STATUS (Current Month)'
\echo ''

SELECT 
    fisher_name AS "Fisher",
    species_name AS "Species",
    TO_CHAR(total_catch_kg, 'FM999,999.0') AS "Caught (kg)",
    TO_CHAR(quota_kg, 'FM999,999.0') AS "Quota (kg)",
    quota_pct || '%' AS "Used",
    compliance_status AS "Status"
FROM vw_quota_compliance
WHERE month = DATE_TRUNC('month', CURRENT_DATE)
ORDER BY quota_pct DESC
LIMIT 15;

\echo ''

-- ============================================================================
-- Violators (Quota Exceeded)
-- ============================================================================

\echo '>> QUOTA VIOLATIONS - EXCEEDED'
\echo ''

SELECT 
    fisher_name AS "Fisher",
    species_name AS "Species",
    TO_CHAR(month, 'YYYY-MM') AS "Month",
    ROUND(total_catch_kg - quota_kg, 1) || ' kg' AS "Over Limit"
FROM vw_quota_compliance
WHERE compliance_status = '🔴 EXCEEDED'
ORDER BY (total_catch_kg - quota_kg) DESC;

\echo ''
\echo '=============================================='
\echo 'END OF REPORT'
\echo '=============================================='
