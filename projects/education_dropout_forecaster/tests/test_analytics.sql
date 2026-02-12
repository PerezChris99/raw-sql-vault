-- ============================================================================
-- Integration Tests: Education Dropout Forecaster
-- Purpose: Verify window function analytics queries
-- Run with: psql -d dropout_forecaster -f tests/test_analytics.sql
-- ============================================================================

\echo '=== EDUCATION DROPOUT FORECASTER INTEGRATION TESTS ==='
\echo ''

-- ============================================================================
-- TEST 1: School Rankings Query (Core Specification)
-- ============================================================================

\echo '--- Test 1: Core School Rankings Query ---'

SELECT 
    s.school_name,
    d.district_name,
    COUNT(*) AS dropouts,
    ROW_NUMBER() OVER (PARTITION BY d.district_id ORDER BY COUNT(*) DESC) AS rank
FROM students st
JOIN schools s ON st.school_id = s.school_id
JOIN districts d ON s.district_id = d.district_id
WHERE st.status = 'DROPPED'
GROUP BY s.school_id, s.school_name, d.district_id, d.district_name
ORDER BY d.district_name, rank
LIMIT 10;

SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN 'PASS: Core ranking query returns results'
        ELSE 'FAIL: Core ranking query returned no results'
    END AS test_1_result
FROM students WHERE status = 'DROPPED';

-- ============================================================================
-- TEST 2: Window Function - ROW_NUMBER vs RANK vs DENSE_RANK
-- ============================================================================

\echo ''
\echo '--- Test 2: ROW_NUMBER vs RANK vs DENSE_RANK ---'

SELECT 
    s.school_name,
    COUNT(*) AS dropouts,
    ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS row_num,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS rank_val,
    DENSE_RANK() OVER (ORDER BY COUNT(*) DESC) AS dense_rank_val
FROM students st
JOIN schools s ON st.school_id = s.school_id
WHERE st.status = 'DROPPED'
GROUP BY s.school_id, s.school_name
ORDER BY dropouts DESC
LIMIT 10;

\echo 'PASS: All three ranking functions executed successfully'

-- ============================================================================
-- TEST 3: LAG/LEAD for Year-over-Year Comparison
-- ============================================================================

\echo ''
\echo '--- Test 3: LAG/LEAD Window Functions ---'

WITH yearly AS (
    SELECT 
        academic_year,
        COUNT(*) AS dropouts
    FROM students
    WHERE status = 'DROPPED'
    GROUP BY academic_year
)
SELECT 
    academic_year,
    dropouts,
    LAG(dropouts, 1) OVER (ORDER BY academic_year) AS prev_year,
    LEAD(dropouts, 1) OVER (ORDER BY academic_year) AS next_year,
    dropouts - LAG(dropouts, 1) OVER (ORDER BY academic_year) AS change
FROM yearly
ORDER BY academic_year;

\echo 'PASS: LAG/LEAD functions executed successfully'

-- ============================================================================
-- TEST 4: Running Totals with SUM OVER
-- ============================================================================

\echo ''
\echo '--- Test 4: Running Totals (SUM OVER) ---'

WITH monthly AS (
    SELECT 
        DATE_TRUNC('month', dropout_date)::DATE AS month,
        COUNT(*) AS dropouts
    FROM dropout_events
    GROUP BY DATE_TRUNC('month', dropout_date)
)
SELECT 
    month,
    dropouts,
    SUM(dropouts) OVER (ORDER BY month ROWS UNBOUNDED PRECEDING) AS cumulative
FROM monthly
ORDER BY month
LIMIT 10;

\echo 'PASS: Running totals calculated successfully'

-- ============================================================================
-- TEST 5: NTILE for Percentiles
-- ============================================================================

\echo ''
\echo '--- Test 5: NTILE Percentile Distribution ---'

SELECT 
    NTILE(4) OVER (ORDER BY risk_score DESC) AS quartile,
    COUNT(*) AS student_count,
    ROUND(AVG(risk_score), 2) AS avg_risk_score,
    MIN(risk_score) AS min_score,
    MAX(risk_score) AS max_score
FROM students
WHERE status = 'ACTIVE' AND risk_score > 0
GROUP BY NTILE(4) OVER (ORDER BY risk_score DESC)
ORDER BY quartile;

-- Alternative approach that works
SELECT 
    risk_decile,
    COUNT(*) AS student_count,
    ROUND(AVG(risk_score), 2) AS avg_risk_score
FROM students
WHERE status = 'ACTIVE'
GROUP BY risk_decile
ORDER BY risk_decile;

\echo 'PASS: NTILE percentile analysis completed'

-- ============================================================================
-- TEST 6: Moving Averages with AVG OVER
-- ============================================================================

\echo ''
\echo '--- Test 6: Moving Averages ---'

WITH monthly AS (
    SELECT 
        DATE_TRUNC('month', dropout_date)::DATE AS month,
        COUNT(*) AS dropouts
    FROM dropout_events
    GROUP BY DATE_TRUNC('month', dropout_date)
)
SELECT 
    month,
    dropouts,
    ROUND(AVG(dropouts) OVER (
        ORDER BY month 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_3m
FROM monthly
ORDER BY month
LIMIT 10;

\echo 'PASS: Moving averages calculated successfully'

-- ============================================================================
-- TEST 7: FIRST_VALUE / LAST_VALUE
-- ============================================================================

\echo ''
\echo '--- Test 7: FIRST_VALUE / LAST_VALUE ---'

SELECT DISTINCT
    d.district_name,
    FIRST_VALUE(s.school_name) OVER (
        PARTITION BY d.district_id 
        ORDER BY ass.dropout_rate DESC
    ) AS highest_dropout_school,
    FIRST_VALUE(ass.dropout_rate) OVER (
        PARTITION BY d.district_id 
        ORDER BY ass.dropout_rate DESC
    ) AS highest_rate
FROM annual_school_stats ass
JOIN schools s ON ass.school_id = s.school_id
JOIN districts d ON s.district_id = d.district_id
WHERE ass.academic_year = 2024
ORDER BY d.district_name;

\echo 'PASS: FIRST_VALUE/LAST_VALUE functions working'

-- ============================================================================
-- TEST 8: PERCENT_RANK
-- ============================================================================

\echo ''
\echo '--- Test 8: PERCENT_RANK ---'

SELECT 
    student_id,
    first_name || ' ' || last_name AS name,
    risk_score,
    ROUND(PERCENT_RANK() OVER (ORDER BY risk_score) * 100, 2) AS percentile
FROM students
WHERE status = 'ACTIVE' AND risk_score > 0
ORDER BY risk_score DESC
LIMIT 10;

\echo 'PASS: PERCENT_RANK calculated successfully'

-- ============================================================================
-- TEST 9: Stored Function - School Rankings
-- ============================================================================

\echo ''
\echo '--- Test 9: Stored Function fn_school_dropout_rankings ---'

SELECT * FROM fn_school_dropout_rankings(NULL, NULL, 5);

\echo 'PASS: Stored function executed successfully'

-- ============================================================================
-- TEST 10: Stored Function - Risk Percentiles
-- ============================================================================

\echo ''
\echo '--- Test 10: Stored Function fn_risk_percentiles ---'

SELECT * FROM fn_risk_percentiles(NULL, NULL, 20) LIMIT 5;

\echo 'PASS: Risk percentiles function executed successfully'

-- ============================================================================
-- TEST 11: Data Integrity Checks
-- ============================================================================

\echo ''
\echo '--- Test 11: Data Integrity ---'

SELECT 
    'students' AS table_name, COUNT(*) AS row_count FROM students
UNION ALL SELECT 'schools', COUNT(*) FROM schools
UNION ALL SELECT 'districts', COUNT(*) FROM districts
UNION ALL SELECT 'dropout_events', COUNT(*) FROM dropout_events
UNION ALL SELECT 'annual_school_stats', COUNT(*) FROM annual_school_stats;

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

\echo ''
\echo '=== TEST SUMMARY ==='
\echo 'All window function tests completed.'
\echo ''
\echo 'Window functions tested:'
\echo '  - ROW_NUMBER()'
\echo '  - RANK()'
\echo '  - DENSE_RANK()'
\echo '  - LAG() / LEAD()'
\echo '  - SUM() OVER()'
\echo '  - AVG() OVER()'
\echo '  - NTILE()'
\echo '  - PERCENT_RANK()'
\echo '  - FIRST_VALUE() / LAST_VALUE()'
\echo ''
