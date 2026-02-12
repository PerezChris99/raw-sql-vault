-- ============================================================================
-- Views: Reporting & Analytics
-- Purpose: Pre-built views for common queries and dashboards
-- ============================================================================

USE job_matching;

-- ============================================================================
-- VIEW: Active Jobs with Company Info
-- ============================================================================

DROP VIEW IF EXISTS vw_active_jobs;

CREATE VIEW vw_active_jobs AS
SELECT 
    j.job_id,
    j.job_code,
    j.title,
    j.employment_type,
    j.experience_level,
    j.remote_type,
    j.salary_min,
    j.salary_max,
    j.salary_currency,
    j.required_skills,
    j.preferred_skills,
    j.application_deadline,
    j.posted_at,
    c.company_id,
    c.name AS company_name,
    c.industry,
    c.size_range AS company_size,
    l.city,
    l.state,
    l.country,
    i.name AS industry_name,
    (SELECT COUNT(*) FROM applications a WHERE a.job_id = j.job_id) AS application_count
FROM jobs j
JOIN companies c ON j.company_id = c.company_id
LEFT JOIN locations l ON j.location_id = l.location_id
LEFT JOIN industries i ON c.industry = i.name
WHERE j.is_active = TRUE
  AND j.status = 'open'
  AND (j.application_deadline IS NULL OR j.application_deadline >= CURDATE());

-- ============================================================================
-- VIEW: Available Candidates
-- ============================================================================

DROP VIEW IF EXISTS vw_available_candidates;

CREATE VIEW vw_available_candidates AS
SELECT 
    s.seeker_id,
    s.seeker_code,
    CONCAT(s.first_name, ' ', s.last_name) AS full_name,
    s.email,
    s.headline,
    s.skills_text,
    s.experience_years,
    s.expected_salary_min,
    s.expected_salary_max,
    s.salary_currency,
    s.preferred_employment,
    s.preferred_remote,
    l.city,
    l.state,
    l.country,
    s.available_from,
    s.created_at AS profile_created,
    (SELECT COUNT(*) FROM applications a WHERE a.seeker_id = s.seeker_id) AS applications_submitted
FROM seekers s
LEFT JOIN locations l ON s.location_id = l.location_id
WHERE s.is_available = TRUE
  AND s.is_active = TRUE;

-- ============================================================================
-- VIEW: Match Statistics by Job
-- ============================================================================

DROP VIEW IF EXISTS vw_job_match_stats;

CREATE VIEW vw_job_match_stats AS
SELECT 
    j.job_id,
    j.title,
    c.name AS company_name,
    COUNT(DISTINCT sm.seeker_id) AS saved_matches,
    AVG(sm.match_score) AS avg_match_score,
    MAX(sm.match_score) AS best_match_score,
    COUNT(DISTINCT a.seeker_id) AS total_applicants,
    SUM(CASE WHEN a.status = 'interview' THEN 1 ELSE 0 END) AS interviews,
    SUM(CASE WHEN a.status = 'offered' THEN 1 ELSE 0 END) AS offers
FROM jobs j
JOIN companies c ON j.company_id = c.company_id
LEFT JOIN saved_matches sm ON j.job_id = sm.job_id
LEFT JOIN applications a ON j.job_id = a.job_id
GROUP BY j.job_id, j.title, c.name;

-- ============================================================================
-- VIEW: Candidate Match Statistics
-- ============================================================================

DROP VIEW IF EXISTS vw_candidate_match_stats;

CREATE VIEW vw_candidate_match_stats AS
SELECT 
    s.seeker_id,
    CONCAT(s.first_name, ' ', s.last_name) AS full_name,
    s.headline,
    COUNT(DISTINCT sm.job_id) AS matched_jobs,
    AVG(sm.match_score) AS avg_match_score,
    MAX(sm.match_score) AS best_match_score,
    COUNT(DISTINCT a.job_id) AS applications_sent,
    SUM(CASE WHEN a.status = 'interview' THEN 1 ELSE 0 END) AS interview_invites,
    SUM(CASE WHEN a.status = 'offered' THEN 1 ELSE 0 END) AS offers_received
FROM seekers s
LEFT JOIN saved_matches sm ON s.seeker_id = sm.seeker_id
LEFT JOIN applications a ON s.seeker_id = a.seeker_id
GROUP BY s.seeker_id, s.first_name, s.last_name, s.headline;

-- ============================================================================
-- VIEW: Skills Demand Analysis
-- ============================================================================

DROP VIEW IF EXISTS vw_skills_demand;

CREATE VIEW vw_skills_demand AS
SELECT 
    sk.skill_id,
    sk.name AS skill_name,
    sc.name AS category,
    sk.demand_level,
    COUNT(DISTINCT js.job_id) AS jobs_requiring,
    COUNT(DISTINCT ss.seeker_id) AS candidates_with_skill,
    ROUND(COUNT(DISTINCT js.job_id) / NULLIF(COUNT(DISTINCT ss.seeker_id), 0), 2) AS demand_supply_ratio
FROM skills sk
JOIN skill_categories sc ON sk.category_id = sc.category_id
LEFT JOIN job_skills js ON sk.skill_id = js.skill_id
LEFT JOIN seeker_skills ss ON sk.skill_id = ss.skill_id
GROUP BY sk.skill_id, sk.name, sc.name, sk.demand_level
ORDER BY jobs_requiring DESC;

-- ============================================================================
-- VIEW: Application Pipeline
-- ============================================================================

DROP VIEW IF EXISTS vw_application_pipeline;

CREATE VIEW vw_application_pipeline AS
SELECT 
    a.application_id,
    a.applied_at,
    a.status,
    a.match_score,
    j.job_id,
    j.title AS job_title,
    c.name AS company_name,
    s.seeker_id,
    CONCAT(s.first_name, ' ', s.last_name) AS candidate_name,
    s.headline AS candidate_headline,
    DATEDIFF(CURDATE(), a.applied_at) AS days_since_applied
FROM applications a
JOIN jobs j ON a.job_id = j.job_id
JOIN companies c ON j.company_id = c.company_id
JOIN seekers s ON a.seeker_id = s.seeker_id
ORDER BY a.applied_at DESC;

-- ============================================================================
-- VIEW: Company Hiring Overview
-- ============================================================================

DROP VIEW IF EXISTS vw_company_hiring;

CREATE VIEW vw_company_hiring AS
SELECT 
    c.company_id,
    c.name AS company_name,
    c.industry,
    c.size_range,
    COUNT(DISTINCT j.job_id) AS active_jobs,
    SUM(CASE WHEN j.is_active = TRUE THEN 1 ELSE 0 END) AS open_positions,
    COUNT(DISTINCT a.application_id) AS total_applications,
    AVG(a.match_score) AS avg_applicant_match_score,
    MIN(j.posted_at) AS first_post_date,
    MAX(j.posted_at) AS latest_post_date
FROM companies c
LEFT JOIN jobs j ON c.company_id = j.company_id
LEFT JOIN applications a ON j.job_id = a.job_id
GROUP BY c.company_id, c.name, c.industry, c.size_range;

-- ============================================================================
-- VIEW: Search Analytics Summary
-- ============================================================================

DROP VIEW IF EXISTS vw_search_analytics;

CREATE VIEW vw_search_analytics AS
SELECT 
    DATE(searched_at) AS search_date,
    search_type,
    COUNT(*) AS total_searches,
    AVG(results_count) AS avg_results,
    COUNT(DISTINCT seeker_id) AS unique_seekers,
    COUNT(DISTINCT company_id) AS unique_companies
FROM search_history
GROUP BY DATE(searched_at), search_type
ORDER BY search_date DESC;

-- ============================================================================
-- VIEW: Top Matching Pairs (Pre-computed)
-- ============================================================================

DROP VIEW IF EXISTS vw_top_matches;

CREATE VIEW vw_top_matches AS
SELECT 
    j.job_id,
    j.title AS job_title,
    c.name AS company_name,
    s.seeker_id,
    CONCAT(s.first_name, ' ', s.last_name) AS candidate_name,
    sm.match_score,
    sm.matched_at,
    sm.is_notified
FROM saved_matches sm
JOIN jobs j ON sm.job_id = j.job_id
JOIN companies c ON j.company_id = c.company_id
JOIN seekers s ON sm.seeker_id = s.seeker_id
WHERE sm.match_score >= 0.7
ORDER BY sm.match_score DESC;

-- ============================================================================
-- VIEW: Monthly Hiring Metrics
-- ============================================================================

DROP VIEW IF EXISTS vw_monthly_metrics;

CREATE VIEW vw_monthly_metrics AS
SELECT 
    DATE_FORMAT(period_date, '%Y-%m') AS month,
    'jobs_posted' AS metric_type,
    COUNT(*) AS value
FROM jobs
GROUP BY DATE_FORMAT(period_date, '%Y-%m')

UNION ALL

SELECT 
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    'candidates_joined' AS metric_type,
    COUNT(*) AS value
FROM seekers
GROUP BY DATE_FORMAT(created_at, '%Y-%m')

UNION ALL

SELECT 
    DATE_FORMAT(applied_at, '%Y-%m') AS month,
    'applications_submitted' AS metric_type,
    COUNT(*) AS value
FROM applications
GROUP BY DATE_FORMAT(applied_at, '%Y-%m')

ORDER BY month DESC, metric_type;

-- ============================================================================
-- VIEW: Experience Level Distribution
-- ============================================================================

DROP VIEW IF EXISTS vw_experience_distribution;

CREATE VIEW vw_experience_distribution AS
SELECT 
    'Jobs' AS entity_type,
    experience_level AS level,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM jobs), 2) AS percentage
FROM jobs
GROUP BY experience_level

UNION ALL

SELECT 
    'Candidates' AS entity_type,
    CASE 
        WHEN experience_years < 1 THEN 'entry'
        WHEN experience_years BETWEEN 1 AND 3 THEN 'junior'
        WHEN experience_years BETWEEN 4 AND 6 THEN 'mid'
        WHEN experience_years BETWEEN 7 AND 10 THEN 'senior'
        ELSE 'lead'
    END AS level,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM seekers), 2) AS percentage
FROM seekers
GROUP BY level
ORDER BY entity_type, level;

-- ============================================================================
-- Verify Views Created
-- ============================================================================

SELECT 
    TABLE_NAME AS view_name,
    TABLE_TYPE
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'job_matching'
  AND TABLE_TYPE = 'VIEW'
ORDER BY TABLE_NAME;
