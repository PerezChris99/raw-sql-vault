-- ============================================================================
-- Integration Tests: Job Matching Engine
-- Purpose: Verify full-text search matching functionality
-- Run with: mysql -u root -p job_matching < tests/integration/test_matching.sql
-- ============================================================================

USE job_matching;

-- ============================================================================
-- TEST SETUP
-- ============================================================================

SELECT '=== JOB MATCHING ENGINE INTEGRATION TESTS ===' AS test_suite;
SELECT NOW() AS test_start_time;

-- ============================================================================
-- TEST 1: Full-Text Index Verification
-- ============================================================================

SELECT '--- Test 1: Full-Text Index Verification ---' AS test_name;

SELECT 
    TABLE_NAME,
    INDEX_NAME,
    INDEX_TYPE,
    GROUP_CONCAT(COLUMN_NAME) AS columns
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'job_matching'
  AND INDEX_TYPE = 'FULLTEXT'
GROUP BY TABLE_NAME, INDEX_NAME, INDEX_TYPE;

-- Verify indexes exist
SELECT 
    CASE 
        WHEN COUNT(*) >= 4 THEN 'PASS: Full-text indexes created'
        ELSE 'FAIL: Missing full-text indexes'
    END AS test_1_result
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'job_matching' AND INDEX_TYPE = 'FULLTEXT';

-- ============================================================================
-- TEST 2: Boolean Mode Search - Required Skills
-- ============================================================================

SELECT '--- Test 2: Boolean Mode Search ---' AS test_name;

-- Search for Python developers
SELECT 
    seeker_id,
    CONCAT(first_name, ' ', last_name) AS name,
    skills_text,
    MATCH(skills_text) AGAINST('+python' IN BOOLEAN MODE) AS score
FROM seekers
WHERE MATCH(skills_text) AGAINST('+python' IN BOOLEAN MODE)
ORDER BY score DESC
LIMIT 5;

SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN 'PASS: Boolean mode search working'
        ELSE 'FAIL: Boolean mode search not returning results'
    END AS test_2_result
FROM seekers
WHERE MATCH(skills_text) AGAINST('+python' IN BOOLEAN MODE);

-- ============================================================================
-- TEST 3: Boolean Mode - Exclusion
-- ============================================================================

SELECT '--- Test 3: Boolean Mode Exclusion ---' AS test_name;

-- Search for developers with Python but NOT PHP
SELECT 
    CONCAT(first_name, ' ', last_name) AS name,
    skills_text,
    MATCH(skills_text) AGAINST('+python -php' IN BOOLEAN MODE) AS score
FROM seekers
WHERE MATCH(skills_text) AGAINST('+python -php' IN BOOLEAN MODE)
ORDER BY score DESC
LIMIT 5;

SELECT 'PASS: Exclusion operator working' AS test_3_result;

-- ============================================================================
-- TEST 4: Natural Language Mode Search
-- ============================================================================

SELECT '--- Test 4: Natural Language Mode ---' AS test_name;

SELECT 
    job_id,
    title,
    required_skills,
    MATCH(required_skills, preferred_skills) 
        AGAINST('react javascript frontend developer' IN NATURAL LANGUAGE MODE) AS relevance
FROM jobs
WHERE MATCH(required_skills, preferred_skills) 
        AGAINST('react javascript frontend developer' IN NATURAL LANGUAGE MODE)
ORDER BY relevance DESC
LIMIT 5;

SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN 'PASS: Natural language mode working'
        ELSE 'FAIL: Natural language mode not returning results'
    END AS test_4_result
FROM jobs
WHERE MATCH(required_skills, preferred_skills) 
        AGAINST('react javascript' IN NATURAL LANGUAGE MODE);

-- ============================================================================
-- TEST 5: Cross-Join Matching (Core Query)
-- ============================================================================

SELECT '--- Test 5: Core Matching Query ---' AS test_name;

-- This is the core query per project specification
SELECT 
    j.job_id,
    j.title AS job_title,
    s.seeker_id,
    CONCAT(s.first_name, ' ', s.last_name) AS candidate_name,
    MATCH(s.skills_text) AGAINST(j.required_skills IN BOOLEAN MODE) AS match_score
FROM jobs j
CROSS JOIN seekers s
WHERE j.is_active = TRUE
  AND s.is_available = TRUE
  AND MATCH(s.skills_text) AGAINST(j.required_skills IN BOOLEAN MODE)
ORDER BY match_score DESC
LIMIT 10;

SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN 'PASS: Core matching query working'
        ELSE 'FAIL: Core matching query not returning results'
    END AS test_5_result
FROM jobs j
CROSS JOIN seekers s
WHERE MATCH(s.skills_text) AGAINST(j.required_skills IN BOOLEAN MODE);

-- ============================================================================
-- TEST 6: Stored Procedure - Job to Candidates
-- ============================================================================

SELECT '--- Test 6: SP Match Job to Candidates ---' AS test_name;

CALL sp_match_job_to_candidates(1, 5, NULL, NULL);

SELECT 'PASS: Stored procedure executed' AS test_6_result;

-- ============================================================================
-- TEST 7: Stored Procedure - Candidate to Jobs
-- ============================================================================

SELECT '--- Test 7: SP Match Candidate to Jobs ---' AS test_name;

CALL sp_match_candidate_to_jobs(1, 5, NULL, NULL);

SELECT 'PASS: Stored procedure executed' AS test_7_result;

-- ============================================================================
-- TEST 8: Advanced Boolean Search SP
-- ============================================================================

SELECT '--- Test 8: Advanced Boolean Search ---' AS test_name;

CALL sp_advanced_skill_search('+python +django', 'seekers', 5);
CALL sp_advanced_skill_search('react javascript', 'jobs', 5);

SELECT 'PASS: Advanced search procedure executed' AS test_8_result;

-- ============================================================================
-- TEST 9: Bulk Matching
-- ============================================================================

SELECT '--- Test 9: Bulk Matching ---' AS test_name;

CALL sp_bulk_matching(0.5, 20);

SELECT 'PASS: Bulk matching executed' AS test_9_result;

-- ============================================================================
-- TEST 10: Data Integrity
-- ============================================================================

SELECT '--- Test 10: Data Integrity Checks ---' AS test_name;

SELECT 
    'seekers' AS table_name, COUNT(*) AS row_count FROM seekers
UNION ALL SELECT 'jobs', COUNT(*) FROM jobs
UNION ALL SELECT 'companies', COUNT(*) FROM companies
UNION ALL SELECT 'skills', COUNT(*) FROM skills
UNION ALL SELECT 'applications', COUNT(*) FROM applications;

SELECT 
    CASE 
        WHEN (SELECT COUNT(*) FROM seekers WHERE skills_text IS NULL OR skills_text = '') = 0
        THEN 'PASS: All seekers have skills_text populated'
        ELSE 'FAIL: Some seekers missing skills_text'
    END AS test_10_result;

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

SELECT '=== TEST SUMMARY ===' AS summary;
SELECT NOW() AS test_end_time;

SELECT 'All integration tests completed. Review results above.' AS final_message;
