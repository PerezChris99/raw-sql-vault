-- ============================================================================
-- Migration V001: Database and Table Schema
-- Purpose: Core table definitions for job matching system
-- Database: MySQL 8.0+
-- ============================================================================

-- Create database with proper character set
CREATE DATABASE IF NOT EXISTS job_matching 
    CHARACTER SET utf8mb4 
    COLLATE utf8mb4_unicode_ci;

USE job_matching;

-- ============================================================================
-- REFERENCE TABLES
-- ============================================================================

-- Industries/Sectors
CREATE TABLE industries (
    industry_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    industry_code VARCHAR(10) UNIQUE NOT NULL,
    industry_name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_industry_id INT UNSIGNED NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_industry_id) REFERENCES industries(industry_id)
) ENGINE=InnoDB;

-- Locations
CREATE TABLE locations (
    location_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(100) NOT NULL,
    state_province VARCHAR(100),
    country VARCHAR(100) NOT NULL,
    country_code CHAR(2) NOT NULL,
    timezone VARCHAR(50),
    latitude DECIMAL(10,7),
    longitude DECIMAL(10,7),
    is_remote_friendly BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_city_country (city, country_code)
) ENGINE=InnoDB;

-- Skill Categories
CREATE TABLE skill_categories (
    category_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_code VARCHAR(20) UNIQUE NOT NULL,
    category_name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_category_id INT UNSIGNED NULL,
    is_active BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (parent_category_id) REFERENCES skill_categories(category_id)
) ENGINE=InnoDB;

-- Skills Master
CREATE TABLE skills (
    skill_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    skill_code VARCHAR(50) UNIQUE NOT NULL,
    skill_name VARCHAR(100) NOT NULL,
    category_id INT UNSIGNED,
    description TEXT,
    synonyms TEXT COMMENT 'Comma-separated alternative names',
    is_technical BOOLEAN DEFAULT TRUE,
    demand_level ENUM('low', 'medium', 'high', 'critical') DEFAULT 'medium',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES skill_categories(category_id)
) ENGINE=InnoDB;

-- ============================================================================
-- COMPANY TABLES
-- ============================================================================

CREATE TABLE companies (
    company_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_code VARCHAR(20) UNIQUE,
    company_name VARCHAR(200) NOT NULL,
    industry_id INT UNSIGNED,
    description TEXT,
    company_size ENUM('startup', 'small', 'medium', 'large', 'enterprise') DEFAULT 'medium',
    employee_count_range VARCHAR(20),
    website VARCHAR(255),
    logo_url VARCHAR(500),
    headquarters_location_id INT UNSIGNED,
    founded_year YEAR,
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (industry_id) REFERENCES industries(industry_id),
    FOREIGN KEY (headquarters_location_id) REFERENCES locations(location_id)
) ENGINE=InnoDB;

-- ============================================================================
-- JOB TABLES
-- ============================================================================

CREATE TABLE jobs (
    job_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    job_code VARCHAR(30) UNIQUE,
    company_id INT UNSIGNED NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    
    -- Skills fields for full-text search
    required_skills TEXT NOT NULL COMMENT 'Space-separated required skills for FT search',
    preferred_skills TEXT COMMENT 'Space-separated preferred skills for FT search',
    
    -- Experience requirements
    experience_min_years TINYINT UNSIGNED DEFAULT 0,
    experience_max_years TINYINT UNSIGNED DEFAULT 99,
    
    -- Compensation
    salary_min DECIMAL(12,2),
    salary_max DECIMAL(12,2),
    salary_currency CHAR(3) DEFAULT 'USD',
    salary_period ENUM('hourly', 'monthly', 'yearly') DEFAULT 'yearly',
    
    -- Job details
    job_type ENUM('full_time', 'part_time', 'contract', 'internship', 'freelance') DEFAULT 'full_time',
    work_arrangement ENUM('onsite', 'remote', 'hybrid') DEFAULT 'onsite',
    location_id INT UNSIGNED,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    is_featured BOOLEAN DEFAULT FALSE,
    application_deadline DATE,
    positions_available SMALLINT UNSIGNED DEFAULT 1,
    positions_filled SMALLINT UNSIGNED DEFAULT 0,
    
    -- Metadata
    posted_by INT UNSIGNED,
    posted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    FOREIGN KEY (company_id) REFERENCES companies(company_id),
    FOREIGN KEY (location_id) REFERENCES locations(location_id)
) ENGINE=InnoDB;

-- Job-Skill relationship (normalized)
CREATE TABLE job_skills (
    job_id INT UNSIGNED NOT NULL,
    skill_id INT UNSIGNED NOT NULL,
    is_required BOOLEAN DEFAULT TRUE,
    proficiency_level ENUM('beginner', 'intermediate', 'advanced', 'expert') DEFAULT 'intermediate',
    PRIMARY KEY (job_id, skill_id),
    FOREIGN KEY (job_id) REFERENCES jobs(job_id) ON DELETE CASCADE,
    FOREIGN KEY (skill_id) REFERENCES skills(skill_id)
) ENGINE=InnoDB;

-- ============================================================================
-- SEEKER TABLES
-- ============================================================================

CREATE TABLE seekers (
    seeker_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    seeker_code VARCHAR(20) UNIQUE,
    
    -- Personal info
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20),
    
    -- Profile
    headline VARCHAR(200),
    summary TEXT,
    
    -- Skills field for full-text search (denormalized for performance)
    skills_text TEXT NOT NULL COMMENT 'Space-separated skills for FT search',
    
    -- Experience
    experience_years TINYINT UNSIGNED DEFAULT 0,
    current_job_title VARCHAR(200),
    current_company VARCHAR(200),
    
    -- Preferences
    desired_job_type ENUM('full_time', 'part_time', 'contract', 'internship', 'freelance'),
    desired_work_arrangement ENUM('onsite', 'remote', 'hybrid'),
    desired_salary_min DECIMAL(12,2),
    desired_salary_currency CHAR(3) DEFAULT 'USD',
    willing_to_relocate BOOLEAN DEFAULT FALSE,
    
    -- Location
    location_id INT UNSIGNED,
    
    -- Status
    is_available BOOLEAN DEFAULT TRUE,
    availability_date DATE,
    profile_visibility ENUM('public', 'recruiters_only', 'private') DEFAULT 'public',
    
    -- Metadata
    resume_url VARCHAR(500),
    linkedin_url VARCHAR(255),
    github_url VARCHAR(255),
    portfolio_url VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    last_active_at TIMESTAMP,
    
    FOREIGN KEY (location_id) REFERENCES locations(location_id)
) ENGINE=InnoDB;

-- Seeker-Skill relationship (normalized)
CREATE TABLE seeker_skills (
    seeker_id INT UNSIGNED NOT NULL,
    skill_id INT UNSIGNED NOT NULL,
    proficiency_level ENUM('beginner', 'intermediate', 'advanced', 'expert') DEFAULT 'intermediate',
    years_experience TINYINT UNSIGNED DEFAULT 0,
    is_primary BOOLEAN DEFAULT FALSE,
    last_used_year YEAR,
    PRIMARY KEY (seeker_id, skill_id),
    FOREIGN KEY (seeker_id) REFERENCES seekers(seeker_id) ON DELETE CASCADE,
    FOREIGN KEY (skill_id) REFERENCES skills(skill_id)
) ENGINE=InnoDB;

-- Seeker work experience
CREATE TABLE seeker_experience (
    experience_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    seeker_id INT UNSIGNED NOT NULL,
    company_name VARCHAR(200) NOT NULL,
    job_title VARCHAR(200) NOT NULL,
    description TEXT,
    skills_used TEXT,
    start_date DATE NOT NULL,
    end_date DATE,
    is_current BOOLEAN DEFAULT FALSE,
    location VARCHAR(200),
    FOREIGN KEY (seeker_id) REFERENCES seekers(seeker_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- Seeker education
CREATE TABLE seeker_education (
    education_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    seeker_id INT UNSIGNED NOT NULL,
    institution_name VARCHAR(200) NOT NULL,
    degree VARCHAR(100),
    field_of_study VARCHAR(200),
    start_year YEAR,
    end_year YEAR,
    grade VARCHAR(20),
    description TEXT,
    FOREIGN KEY (seeker_id) REFERENCES seekers(seeker_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================================
-- APPLICATION & MATCHING TABLES
-- ============================================================================

CREATE TABLE applications (
    application_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    job_id INT UNSIGNED NOT NULL,
    seeker_id INT UNSIGNED NOT NULL,
    
    -- Matching scores
    match_score DECIMAL(5,2) COMMENT 'Full-text relevance score',
    compatibility_score DECIMAL(5,2) COMMENT 'Overall compatibility percentage',
    
    -- Status
    status ENUM('pending', 'reviewed', 'shortlisted', 'interviewed', 'offered', 'hired', 'rejected', 'withdrawn') DEFAULT 'pending',
    
    -- Application details
    cover_letter TEXT,
    custom_resume_url VARCHAR(500),
    source ENUM('direct', 'matched', 'referred', 'imported') DEFAULT 'direct',
    
    -- Timestamps
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reviewed_at TIMESTAMP,
    status_updated_at TIMESTAMP,
    
    -- Notes
    recruiter_notes TEXT,
    
    UNIQUE KEY uk_job_seeker (job_id, seeker_id),
    FOREIGN KEY (job_id) REFERENCES jobs(job_id),
    FOREIGN KEY (seeker_id) REFERENCES seekers(seeker_id)
) ENGINE=InnoDB;

-- Saved/bookmarked matches
CREATE TABLE saved_matches (
    saved_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    seeker_id INT UNSIGNED,
    job_id INT UNSIGNED,
    saved_by_type ENUM('seeker', 'recruiter') NOT NULL,
    saved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    FOREIGN KEY (seeker_id) REFERENCES seekers(seeker_id) ON DELETE CASCADE,
    FOREIGN KEY (job_id) REFERENCES jobs(job_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================================
-- AUDIT & ANALYTICS TABLES
-- ============================================================================

CREATE TABLE search_history (
    search_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    searcher_type ENUM('seeker', 'recruiter', 'system') NOT NULL,
    searcher_id INT UNSIGNED,
    search_query TEXT,
    filters_applied JSON,
    results_count INT UNSIGNED,
    search_duration_ms INT UNSIGNED,
    searched_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_searcher (searcher_type, searcher_id),
    INDEX idx_searched_at (searched_at)
) ENGINE=InnoDB;

CREATE TABLE match_analytics (
    analytics_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    job_id INT UNSIGNED,
    seeker_id INT UNSIGNED,
    match_type ENUM('job_to_candidate', 'candidate_to_job') NOT NULL,
    relevance_score DECIMAL(5,2),
    viewed BOOLEAN DEFAULT FALSE,
    clicked BOOLEAN DEFAULT FALSE,
    applied BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_job (job_id),
    INDEX idx_seeker (seeker_id),
    INDEX idx_created (created_at)
) ENGINE=InnoDB;
