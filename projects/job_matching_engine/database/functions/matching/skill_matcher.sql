-- ============================================================================
-- Matching Functions: Skill-Based Job Matching
-- Purpose: Core matching algorithms using full-text search
-- Database: MySQL 8.0+
-- ============================================================================

USE job_matching;

DELIMITER //

-- ============================================================================
-- CORE MATCHING: JOBS TO CANDIDATES
-- Find best matching candidates for a job posting
-- ============================================================================

CREATE PROCEDURE sp_match_job_to_candidates(
    IN p_job_id INT UNSIGNED,
    IN p_limit INT,
    IN p_min_experience INT,
    IN p_max_experience INT
)
BEGIN
    DECLARE v_required_skills TEXT;
    DECLARE v_preferred_skills TEXT;
    
    -- Get job skills
    SELECT required_skills, COALESCE(preferred_skills, '')
    INTO v_required_skills, v_preferred_skills
    FROM jobs WHERE job_id = p_job_id;
    
    -- Match candidates
    SELECT 
        s.seeker_id,
        s.seeker_code,
        CONCAT(s.first_name, ' ', s.last_name) AS candidate_name,
        s.headline,
        s.skills_text,
        s.experience_years,
        s.current_job_title,
        s.desired_salary_min,
        
        -- Required skills match score (weighted higher)
        MATCH(s.skills_text) AGAINST(v_required_skills IN BOOLEAN MODE) AS required_score,
        
        -- Preferred skills bonus
        MATCH(s.skills_text) AGAINST(v_preferred_skills IN BOOLEAN MODE) AS preferred_score,
        
        -- Combined weighted score
        (MATCH(s.skills_text) AGAINST(v_required_skills IN BOOLEAN MODE) * 0.7 +
         MATCH(s.skills_text) AGAINST(v_preferred_skills IN BOOLEAN MODE) * 0.3) AS total_score
        
    FROM seekers s
    WHERE 
        -- Must have some match on required skills
        MATCH(s.skills_text) AGAINST(v_required_skills IN BOOLEAN MODE)
        AND s.is_available = TRUE
        AND s.experience_years BETWEEN COALESCE(p_min_experience, 0) AND COALESCE(p_max_experience, 99)
    ORDER BY total_score DESC
    LIMIT COALESCE(p_limit, 50);
END//

-- ============================================================================
-- CORE MATCHING: CANDIDATES TO JOBS
-- Find best matching jobs for a candidate
-- ============================================================================

CREATE PROCEDURE sp_match_candidate_to_jobs(
    IN p_seeker_id INT UNSIGNED,
    IN p_limit INT,
    IN p_work_arrangement VARCHAR(20),
    IN p_min_salary DECIMAL(12,2)
)
BEGIN
    DECLARE v_seeker_skills TEXT;
    DECLARE v_experience INT;
    
    -- Get seeker skills and experience
    SELECT skills_text, experience_years
    INTO v_seeker_skills, v_experience
    FROM seekers WHERE seeker_id = p_seeker_id;
    
    -- Match jobs
    SELECT 
        j.job_id,
        j.job_code,
        j.title,
        c.company_name,
        j.required_skills,
        j.experience_min_years,
        j.experience_max_years,
        j.salary_min,
        j.salary_max,
        j.job_type,
        j.work_arrangement,
        
        -- Relevance score
        MATCH(j.required_skills, j.preferred_skills) 
            AGAINST(v_seeker_skills IN NATURAL LANGUAGE MODE) AS relevance_score,
        
        -- Experience fit (1.0 = perfect fit)
        CASE 
            WHEN v_experience BETWEEN j.experience_min_years AND j.experience_max_years THEN 1.0
            WHEN v_experience < j.experience_min_years THEN 0.5
            ELSE 0.8
        END AS experience_fit
        
    FROM jobs j
    JOIN companies c ON j.company_id = c.company_id
    WHERE 
        j.is_active = TRUE
        AND MATCH(j.required_skills, j.preferred_skills) 
            AGAINST(v_seeker_skills IN NATURAL LANGUAGE MODE)
        AND (p_work_arrangement IS NULL OR j.work_arrangement = p_work_arrangement)
        AND (p_min_salary IS NULL OR j.salary_max >= p_min_salary)
    ORDER BY relevance_score DESC
    LIMIT COALESCE(p_limit, 20);
END//

-- ============================================================================
-- ADVANCED MATCHING: Boolean Mode Search
-- Supports operators: + (must have), - (must not have), "" (exact phrase)
-- ============================================================================

CREATE PROCEDURE sp_advanced_skill_search(
    IN p_search_query VARCHAR(500),
    IN p_search_type ENUM('seekers', 'jobs'),
    IN p_limit INT
)
BEGIN
    IF p_search_type = 'seekers' THEN
        SELECT 
            s.seeker_id,
            CONCAT(s.first_name, ' ', s.last_name) AS name,
            s.headline,
            s.skills_text,
            s.experience_years,
            MATCH(s.skills_text) AGAINST(p_search_query IN BOOLEAN MODE) AS score
        FROM seekers s
        WHERE MATCH(s.skills_text) AGAINST(p_search_query IN BOOLEAN MODE)
          AND s.is_available = TRUE
        ORDER BY score DESC
        LIMIT COALESCE(p_limit, 50);
    ELSE
        SELECT 
            j.job_id,
            j.title,
            c.company_name,
            j.required_skills,
            j.salary_min,
            j.salary_max,
            MATCH(j.required_skills, j.preferred_skills) 
                AGAINST(p_search_query IN BOOLEAN MODE) AS score
        FROM jobs j
        JOIN companies c ON j.company_id = c.company_id
        WHERE MATCH(j.required_skills, j.preferred_skills) 
                AGAINST(p_search_query IN BOOLEAN MODE)
          AND j.is_active = TRUE
        ORDER BY score DESC
        LIMIT COALESCE(p_limit, 50);
    END IF;
END//

-- ============================================================================
-- BIDIRECTIONAL MATCHING
-- Match all active jobs with all available candidates
-- ============================================================================

CREATE PROCEDURE sp_bulk_matching(
    IN p_min_score DECIMAL(5,2),
    IN p_limit INT
)
BEGIN
    SELECT 
        j.job_id,
        j.title AS job_title,
        c.company_name,
        s.seeker_id,
        CONCAT(s.first_name, ' ', s.last_name) AS candidate_name,
        s.experience_years,
        
        -- Full-text relevance score
        MATCH(s.skills_text) AGAINST(j.required_skills IN BOOLEAN MODE) AS match_score
        
    FROM jobs j
    CROSS JOIN seekers s
    JOIN companies c ON j.company_id = c.company_id
    WHERE 
        j.is_active = TRUE
        AND s.is_available = TRUE
        AND s.experience_years >= j.experience_min_years
        AND s.experience_years <= j.experience_max_years
        AND MATCH(s.skills_text) AGAINST(j.required_skills IN BOOLEAN MODE) >= COALESCE(p_min_score, 1.0)
    ORDER BY match_score DESC
    LIMIT COALESCE(p_limit, 1000);
END//

-- ============================================================================
-- SKILL GAP ANALYSIS
-- Identify missing skills for a candidate relative to a job
-- ============================================================================

CREATE PROCEDURE sp_skill_gap_analysis(
    IN p_seeker_id INT UNSIGNED,
    IN p_job_id INT UNSIGNED
)
BEGIN
    -- Get skills the job requires but seeker doesn't have
    SELECT 
        sk.skill_name,
        sk.demand_level,
        js.is_required,
        js.proficiency_level AS required_level
    FROM job_skills js
    JOIN skills sk ON js.skill_id = sk.skill_id
    WHERE js.job_id = p_job_id
      AND js.skill_id NOT IN (
          SELECT skill_id FROM seeker_skills WHERE seeker_id = p_seeker_id
      )
    ORDER BY js.is_required DESC, sk.demand_level DESC;
END//

-- ============================================================================
-- SIMILAR CANDIDATES
-- Find candidates similar to a given candidate
-- ============================================================================

CREATE PROCEDURE sp_find_similar_candidates(
    IN p_seeker_id INT UNSIGNED,
    IN p_limit INT
)
BEGIN
    DECLARE v_skills TEXT;
    
    SELECT skills_text INTO v_skills FROM seekers WHERE seeker_id = p_seeker_id;
    
    SELECT 
        s.seeker_id,
        CONCAT(s.first_name, ' ', s.last_name) AS name,
        s.headline,
        s.skills_text,
        s.experience_years,
        MATCH(s.skills_text) AGAINST(v_skills IN NATURAL LANGUAGE MODE) AS similarity_score
    FROM seekers s
    WHERE s.seeker_id != p_seeker_id
      AND s.is_available = TRUE
      AND MATCH(s.skills_text) AGAINST(v_skills IN NATURAL LANGUAGE MODE)
    ORDER BY similarity_score DESC
    LIMIT COALESCE(p_limit, 10);
END//

-- ============================================================================
-- SIMILAR JOBS  
-- Find jobs similar to a given job
-- ============================================================================

CREATE PROCEDURE sp_find_similar_jobs(
    IN p_job_id INT UNSIGNED,
    IN p_limit INT
)
BEGIN
    DECLARE v_skills TEXT;
    
    SELECT CONCAT(required_skills, ' ', COALESCE(preferred_skills, ''))
    INTO v_skills 
    FROM jobs WHERE job_id = p_job_id;
    
    SELECT 
        j.job_id,
        j.title,
        c.company_name,
        j.required_skills,
        j.salary_min,
        j.salary_max,
        MATCH(j.required_skills, j.preferred_skills) 
            AGAINST(v_skills IN NATURAL LANGUAGE MODE) AS similarity_score
    FROM jobs j
    JOIN companies c ON j.company_id = c.company_id
    WHERE j.job_id != p_job_id
      AND j.is_active = TRUE
      AND MATCH(j.required_skills, j.preferred_skills) 
          AGAINST(v_skills IN NATURAL LANGUAGE MODE)
    ORDER BY similarity_score DESC
    LIMIT COALESCE(p_limit, 10);
END//

DELIMITER ;
