-- ============================================================================
-- Migration V002: Full-Text Search Indexes
-- Purpose: Configure full-text search for skill matching
-- Database: MySQL 8.0+
-- ============================================================================

USE job_matching;

-- ============================================================================
-- FULL-TEXT INDEXES FOR MATCHING
-- ============================================================================

-- Seeker skills full-text index (most critical for matching)
ALTER TABLE seekers 
ADD FULLTEXT INDEX ft_seeker_skills (skills_text);

-- Seeker profile search (headline + summary)
ALTER TABLE seekers 
ADD FULLTEXT INDEX ft_seeker_profile (headline, summary);

-- Combined seeker search
ALTER TABLE seekers 
ADD FULLTEXT INDEX ft_seeker_combined (skills_text, headline, summary);

-- Job skills full-text indexes
ALTER TABLE jobs 
ADD FULLTEXT INDEX ft_job_required_skills (required_skills);

ALTER TABLE jobs 
ADD FULLTEXT INDEX ft_job_preferred_skills (preferred_skills);

-- Combined job skills search
ALTER TABLE jobs 
ADD FULLTEXT INDEX ft_job_all_skills (required_skills, preferred_skills);

-- Job title and description search
ALTER TABLE jobs 
ADD FULLTEXT INDEX ft_job_content (title, description);

-- Combined job search (title + description + skills)
ALTER TABLE jobs 
ADD FULLTEXT INDEX ft_job_combined (title, description, required_skills, preferred_skills);

-- ============================================================================
-- AUXILIARY FULL-TEXT INDEXES
-- ============================================================================

-- Company search
ALTER TABLE companies 
ADD FULLTEXT INDEX ft_company_search (company_name, description);

-- Skills search (for autocomplete)
ALTER TABLE skills 
ADD FULLTEXT INDEX ft_skills_search (skill_name, synonyms, description);

-- ============================================================================
-- FULL-TEXT CONFIGURATION NOTES
-- ============================================================================

/*
For optimal skill matching, consider these MySQL configuration settings:

1. Minimum word length for FULLTEXT:
   SET GLOBAL ft_min_word_len = 2;
   (Allows matching short tech skills like "Go", "C#", "R")

2. For InnoDB full-text, set:
   SET GLOBAL innodb_ft_min_token_size = 2;
   
3. Custom stopwords - create table to exclude common non-skill words:
   CREATE TABLE custom_stopwords (value VARCHAR(30));
   INSERT INTO custom_stopwords VALUES ('the'), ('and'), ('with'), ('for');
   
   Then configure:
   SET GLOBAL innodb_ft_server_stopword_table = 'job_matching/custom_stopwords';

4. After configuration changes, rebuild indexes:
   OPTIMIZE TABLE seekers;
   OPTIMIZE TABLE jobs;

5. For Boolean mode operators in skill matching:
   + : Must contain (e.g., +python)
   - : Must not contain (e.g., -java)
   * : Wildcard (e.g., java*)
   "" : Exact phrase (e.g., "machine learning")
   > : Increase relevance
   < : Decrease relevance
   
Example advanced search:
   MATCH(skills_text) AGAINST('+python +django -php "machine learning"' IN BOOLEAN MODE)
*/
