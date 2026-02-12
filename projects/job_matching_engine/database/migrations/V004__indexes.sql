-- ============================================================================
-- Migration V004: Performance Indexes
-- Purpose: Optimize query performance for matching and filtering
-- Database: MySQL 8.0+
-- ============================================================================

USE job_matching;

-- ============================================================================
-- SEEKER INDEXES
-- ============================================================================

-- Availability filtering (most common filter)
CREATE INDEX idx_seekers_availability ON seekers(is_available, availability_date);

-- Experience filtering
CREATE INDEX idx_seekers_experience ON seekers(experience_years);

-- Location-based search
CREATE INDEX idx_seekers_location ON seekers(location_id);

-- Profile visibility
CREATE INDEX idx_seekers_visibility ON seekers(profile_visibility, is_available);

-- Recent activity
CREATE INDEX idx_seekers_active ON seekers(last_active_at DESC);

-- Composite for filtered matching
CREATE INDEX idx_seekers_match_filter ON seekers(is_available, experience_years, location_id);

-- ============================================================================
-- JOB INDEXES
-- ============================================================================

-- Active jobs (most common filter)
CREATE INDEX idx_jobs_active ON jobs(is_active, posted_at DESC);

-- Company lookup
CREATE INDEX idx_jobs_company ON jobs(company_id);

-- Location-based search
CREATE INDEX idx_jobs_location ON jobs(location_id);

-- Experience range filtering
CREATE INDEX idx_jobs_experience ON jobs(experience_min_years, experience_max_years);

-- Salary range filtering
CREATE INDEX idx_jobs_salary ON jobs(salary_min, salary_max);

-- Job type filtering
CREATE INDEX idx_jobs_type ON jobs(job_type, work_arrangement);

-- Featured jobs
CREATE INDEX idx_jobs_featured ON jobs(is_featured, is_active, posted_at DESC);

-- Expiring jobs
CREATE INDEX idx_jobs_expiring ON jobs(expires_at) WHERE expires_at IS NOT NULL;

-- Composite for job search
CREATE INDEX idx_jobs_search_filter ON jobs(is_active, job_type, work_arrangement, experience_min_years);

-- ============================================================================
-- APPLICATION INDEXES
-- ============================================================================

-- Seeker's applications
CREATE INDEX idx_applications_seeker ON applications(seeker_id, applied_at DESC);

-- Job's applications
CREATE INDEX idx_applications_job ON applications(job_id, status, applied_at DESC);

-- Application status
CREATE INDEX idx_applications_status ON applications(status, applied_at);

-- Match score ranking
CREATE INDEX idx_applications_score ON applications(job_id, match_score DESC);

-- ============================================================================
-- SKILL INDEXES
-- ============================================================================

-- Skill lookup by category
CREATE INDEX idx_skills_category ON skills(category_id, is_active);

-- Demand level filtering
CREATE INDEX idx_skills_demand ON skills(demand_level, is_active);

-- ============================================================================
-- COMPANY INDEXES
-- ============================================================================

-- Industry filtering
CREATE INDEX idx_companies_industry ON companies(industry_id);

-- Company size filtering
CREATE INDEX idx_companies_size ON companies(company_size);

-- Active verified companies
CREATE INDEX idx_companies_active ON companies(is_active, is_verified);

-- ============================================================================
-- SEARCH ANALYTICS INDEXES
-- ============================================================================

-- Search history by user
CREATE INDEX idx_search_history_user ON search_history(searcher_type, searcher_id, searched_at DESC);

-- Match analytics by job
CREATE INDEX idx_match_analytics_job ON match_analytics(job_id, created_at DESC);

-- Match analytics by seeker
CREATE INDEX idx_match_analytics_seeker ON match_analytics(seeker_id, created_at DESC);

-- Conversion tracking
CREATE INDEX idx_match_analytics_conversions ON match_analytics(viewed, clicked, applied, created_at);
