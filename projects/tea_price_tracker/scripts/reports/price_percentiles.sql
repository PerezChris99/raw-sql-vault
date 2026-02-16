-- ============================================================================
-- Tea Farmer Price Tracker - Price Percentiles Report
-- PostgreSQL 14+
-- Report: User's sample query - PERCENTILE_CONT median prices
-- ============================================================================

\echo '=============================================='
\echo 'TEA PRICE TRACKER - PRICE PERCENTILES'
\echo '=============================================='
\echo ''

-- ============================================================================
-- User's Sample Query
-- ============================================================================

\echo '>> USER SAMPLE QUERY'
\echo '   PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) OVER (PARTITION BY grade)'
\echo ''

SELECT 
    grade_id,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_per_kg) AS median_price
FROM sales
GROUP BY grade_id
ORDER BY grade_id;

\echo ''

-- ============================================================================
-- Full Price Percentiles
-- ============================================================================

\echo '>> PRICE PERCENTILES BY GRADE (Last 90 Days)'
\echo ''

SELECT 
    grade_code AS "Grade",
    grade_name AS "Name",
    TO_CHAR(median_price, 'FM9,999') AS "Median",
    TO_CHAR(p25_price, 'FM9,999') AS "P25",
    TO_CHAR(p75_price, 'FM9,999') AS "P75",
    TO_CHAR(min_price, 'FM9,999') AS "Min",
    TO_CHAR(max_price, 'FM9,999') AS "Max",
    sale_count AS "Sales"
FROM vw_price_percentiles;

\echo ''

-- ============================================================================
-- Potential Exploitation Cases
-- ============================================================================

\echo '>> POTENTIAL EXPLOITATION (>15% Below Median)'
\echo ''

SELECT 
    farmer_name AS "Farmer",
    buyer_name AS "Buyer",
    grade_code AS "Grade",
    TO_CHAR(price_per_kg, 'FM9,999') AS "Paid",
    TO_CHAR(median_price, 'FM9,999') AS "Median",
    pct_vs_median || '%' AS "Diff",
    price_assessment AS "Assessment"
FROM vw_sale_analysis
WHERE price_assessment LIKE '%Exploitation%'
ORDER BY pct_vs_median
LIMIT 10;

\echo ''

-- ============================================================================
-- Buyer Rating
-- ============================================================================

\echo '>> BUYER PRICE ANALYSIS'
\echo ''

SELECT 
    buyer_name AS "Buyer",
    buyer_type AS "Type",
    grade_code AS "Grade",
    TO_CHAR(avg_price_ugx, 'FM9,999') AS "Avg Price",
    pct_vs_market || '%' AS "vs Market",
    buyer_rating AS "Rating"
FROM vw_buyer_analysis
ORDER BY pct_vs_market
LIMIT 15;

\echo ''
\echo '=============================================='
\echo 'END OF REPORT'
\echo '=============================================='
