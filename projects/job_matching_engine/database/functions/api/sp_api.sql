-- ============================================================================
-- API Functions: Stored Procedures for Application Layer
-- Purpose: Encapsulated data access for Node.js integration
-- Database: MySQL 8.0+
-- ============================================================================

USE job_matching;

DELIMITER //

-- ============================================================================
-- JOB SEARCH API
-- ============================================================================

CREATE PROCEDURE sp_api_search_jobs(
    IN p_query VARCHAR(500),
    IN p_job_type VARCHAR(20),
    IN p_work_arrangement VARCHAR(20),
    IN p_min_salary DECIMAL(12,2),
    IN p_max_salary DECIMAL(12,2),
    IN p_experience_level VARCHAR(20),
    IN p_page INT,
    IN p_page_size INT
)
BEGIN
    DECLARE v_offset INT;
    DECLARE v_exp_min INT DEFAULT 0;
    DECLARE v_exp_max INT DEFAULT 99;
    
    SET v_offset = (COALESCE(p_page, 1) - 1) * COALESCE(p_page_size, 20);
    
    -- Map experience level to years
    IF p_experience_level = 'entry' THEN
        SET v_exp_min = 0; SET v_exp_max = 2;
    ELSEIF p_experience_level = 'mid' THEN
        SET v_exp_min = 2; SET v_exp_max = 5;
    ELSEIF p_experience_level = 'senior' THEN
        SET v_exp_min = 5; SET v_exp_max = 10;
    ELSEIF p_experience_level = 'lead' THEN
        SET v_exp_min = 8; SET v_exp_max = 99;
    END IF;
    
    -- Return results
    SELECT 
        j.job_id,
        j.job_code,
        j.title,
        c.company_name,
        c.company_size,
        j.required_skills,
        j.experience_min_years,
        j.experience_max_years,
        j.salary_min,
        j.salary_max,
        j.salary_currency,
        j.job_type,
        j.work_arrangement,
        j.posted_at,
        l.city,
        l.country,
        CASE 
            WHEN p_query IS NOT NULL AND p_query != '' THEN
                MATCH(j.title, j.description, j.required_skills, j.preferred_skills) 
                    AGAINST(p_query IN NATURAL LANGUAGE MODE)
            ELSE 1
        END AS relevance
    FROM jobs j
    JOIN companies c ON j.company_id = c.company_id
    LEFT JOIN locations l ON j.location_id = l.location_id
    WHERE j.is_active = TRUE
      AND (p_query IS NULL OR p_query = '' OR 
           MATCH(j.title, j.description, j.required_skills, j.preferred_skills) 
               AGAINST(p_query IN NATURAL LANGUAGE MODE))
      AND (p_job_type IS NULL OR j.job_type = p_job_type)
      AND (p_work_arrangement IS NULL OR j.work_arrangement = p_work_arrangement)
      AND (p_min_salary IS NULL OR j.salary_max >= p_min_salary)
      AND (p_max_salary IS NULL OR j.salary_min <= p_max_salary)
      AND j.experience_min_years <= v_exp_max
      AND j.experience_max_years >= v_exp_min
    ORDER BY relevance DESC, j.posted_at DESC
    LIMIT p_page_size OFFSET v_offset;
END//

-- ============================================================================
-- CANDIDATE SEARCH API
-- ============================================================================

CREATE PROCEDURE sp_api_search_candidates(
    IN p_skills_query VARCHAR(500),
    IN p_min_experience INT,
    IN p_max_experience INT,
    IN p_work_arrangement VARCHAR(20),
    IN p_page INT,
    IN p_page_size INT
)
BEGIN
    DECLARE v_offset INT;
    SET v_offset = (COALESCE(p_page, 1) - 1) * COALESCE(p_page_size, 20);
    
    SELECT 
        s.seeker_id,
        s.seeker_code,
        CONCAT(s.first_name, ' ', s.last_name) AS full_name,
        s.headline,
        s.skills_text,
        s.experience_years,
        s.current_job_title,
        s.desired_work_arrangement,
        s.desired_salary_min,
        l.city,
        l.country,
        MATCH(s.skills_text) AGAINST(p_skills_query IN BOOLEAN MODE) AS match_score
    FROM seekers s
    LEFT JOIN locations l ON s.location_id = l.location_id
    WHERE s.is_available = TRUE
      AND s.profile_visibility IN ('public', 'recruiters_only')
      AND (p_skills_query IS NULL OR p_skills_query = '' OR
           MATCH(s.skills_text) AGAINST(p_skills_query IN BOOLEAN MODE))
      AND s.experience_years BETWEEN COALESCE(p_min_experience, 0) AND COALESCE(p_max_experience, 99)
      AND (p_work_arrangement IS NULL OR s.desired_work_arrangement = p_work_arrangement)
    ORDER BY match_score DESC, s.experience_years DESC
    LIMIT p_page_size OFFSET v_offset;
END//

-- ============================================================================
-- JOB DETAILS API
-- ============================================================================

CREATE PROCEDURE sp_api_get_job(IN p_job_id INT UNSIGNED)
BEGIN
    SELECT 
        j.*,
        c.company_name,
        c.company_size,
        c.description AS company_description,
        c.website AS company_website,
        l.city,
        l.state_province,
        l.country,
        (SELECT COUNT(*) FROM applications WHERE job_id = j.job_id) AS application_count
    FROM jobs j
    JOIN companies c ON j.company_id = c.company_id
    LEFT JOIN locations l ON j.location_id = l.location_id
    WHERE j.job_id = p_job_id;
END//

-- ============================================================================
-- CANDIDATE DETAILS API
-- ============================================================================

CREATE PROCEDURE sp_api_get_candidate(IN p_seeker_id INT UNSIGNED)
BEGIN
    -- Basic info
    SELECT 
        s.*,
        l.city,
        l.state_province,
        l.country
    FROM seekers s
    LEFT JOIN locations l ON s.location_id = l.location_id
    WHERE s.seeker_id = p_seeker_id;
    
    -- Skills with details
    SELECT 
        sk.skill_name,
        sk.demand_level,
        ss.proficiency_level,
        ss.years_experience,
        ss.is_primary
    FROM seeker_skills ss
    JOIN skills sk ON ss.skill_id = sk.skill_id
    WHERE ss.seeker_id = p_seeker_id
    ORDER BY ss.is_primary DESC, ss.years_experience DESC;
    
    -- Work experience
    SELECT * FROM seeker_experience 
    WHERE seeker_id = p_seeker_id 
    ORDER BY is_current DESC, end_date DESC;
    
    -- Education
    SELECT * FROM seeker_education 
    WHERE seeker_id = p_seeker_id 
    ORDER BY end_year DESC;
END//

-- ============================================================================
-- DASHBOARD STATISTICS
-- ============================================================================

CREATE PROCEDURE sp_api_dashboard_stats()
BEGIN
    SELECT 
        (SELECT COUNT(*) FROM jobs WHERE is_active = TRUE) AS active_jobs,
        (SELECT COUNT(*) FROM seekers WHERE is_available = TRUE) AS available_candidates,
        (SELECT COUNT(*) FROM applications WHERE applied_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)) AS weekly_applications,
        (SELECT COUNT(*) FROM applications WHERE status = 'hired' AND applied_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)) AS monthly_hires,
        (SELECT COUNT(*) FROM companies WHERE is_active = TRUE) AS active_companies;
    
    -- Top skills in demand
    SELECT 
        sk.skill_name,
        COUNT(js.job_id) AS job_count
    FROM job_skills js
    JOIN skills sk ON js.skill_id = sk.skill_id
    JOIN jobs j ON js.job_id = j.job_id
    WHERE j.is_active = TRUE AND js.is_required = TRUE
    GROUP BY sk.skill_id, sk.skill_name
    ORDER BY job_count DESC
    LIMIT 10;
    
    -- Recent jobs
    SELECT 
        j.job_id,
        j.title,
        c.company_name,
        j.posted_at
    FROM jobs j
    JOIN companies c ON j.company_id = c.company_id
    WHERE j.is_active = TRUE
    ORDER BY j.posted_at DESC
    LIMIT 5;
END//

-- ============================================================================
-- APPLICATION MANAGEMENT
-- ============================================================================

CREATE PROCEDURE sp_api_apply_to_job(
    IN p_seeker_id INT UNSIGNED,
    IN p_job_id INT UNSIGNED,
    IN p_cover_letter TEXT
)
BEGIN
    DECLARE v_match_score DECIMAL(5,2);
    DECLARE v_job_skills TEXT;
    DECLARE v_seeker_skills TEXT;
    
    -- Get skills for scoring
    SELECT required_skills INTO v_job_skills FROM jobs WHERE job_id = p_job_id;
    SELECT skills_text INTO v_seeker_skills FROM seekers WHERE seeker_id = p_seeker_id;
    
    -- Calculate match score
    SELECT MATCH(v_seeker_skills) AGAINST(v_job_skills IN BOOLEAN MODE) INTO v_match_score;
    
    -- Insert application
    INSERT INTO applications (job_id, seeker_id, cover_letter, match_score, source)
    VALUES (p_job_id, p_seeker_id, p_cover_letter, COALESCE(v_match_score, 0), 'direct')
    ON DUPLICATE KEY UPDATE 
        cover_letter = VALUES(cover_letter),
        applied_at = CURRENT_TIMESTAMP;
    
    SELECT LAST_INSERT_ID() AS application_id, v_match_score AS match_score;
END//

-- ============================================================================
-- RECOMMENDATIONS
-- ============================================================================

CREATE PROCEDURE sp_api_get_recommended_jobs(
    IN p_seeker_id INT UNSIGNED,
    IN p_limit INT
)
BEGIN
    DECLARE v_skills TEXT;
    
    SELECT skills_text INTO v_skills FROM seekers WHERE seeker_id = p_seeker_id;
    
    SELECT 
        j.job_id,
        j.title,
        c.company_name,
        j.salary_min,
        j.salary_max,
        j.work_arrangement,
        MATCH(j.required_skills, j.preferred_skills) 
            AGAINST(v_skills IN NATURAL LANGUAGE MODE) AS match_score,
        'skill_match' AS recommendation_reason
    FROM jobs j
    JOIN companies c ON j.company_id = c.company_id
    WHERE j.is_active = TRUE
      AND j.job_id NOT IN (SELECT job_id FROM applications WHERE seeker_id = p_seeker_id)
      AND MATCH(j.required_skills, j.preferred_skills) AGAINST(v_skills IN NATURAL LANGUAGE MODE)
    ORDER BY match_score DESC
    LIMIT COALESCE(p_limit, 10);
END//

DELIMITER ;
