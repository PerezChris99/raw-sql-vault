-- ============================================================================
-- Migration V003: Triggers and Auto-generation
-- Purpose: Automated code generation and data sync triggers
-- Database: MySQL 8.0+
-- ============================================================================

USE job_matching;

DELIMITER //

-- ============================================================================
-- CODE GENERATION TRIGGERS
-- ============================================================================

-- Generate seeker code
CREATE TRIGGER trg_seeker_code_generate
BEFORE INSERT ON seekers
FOR EACH ROW
BEGIN
    DECLARE v_seq INT;
    
    IF NEW.seeker_code IS NULL THEN
        SELECT COALESCE(MAX(CAST(SUBSTRING(seeker_code, 5) AS UNSIGNED)), 0) + 1 
        INTO v_seq
        FROM seekers 
        WHERE seeker_code LIKE 'SKR-%';
        
        SET NEW.seeker_code = CONCAT('SKR-', LPAD(v_seq, 6, '0'));
    END IF;
END//

-- Generate job code
CREATE TRIGGER trg_job_code_generate
BEFORE INSERT ON jobs
FOR EACH ROW
BEGIN
    DECLARE v_seq INT;
    DECLARE v_company_code VARCHAR(10);
    
    IF NEW.job_code IS NULL THEN
        SELECT COALESCE(company_code, CONCAT('C', company_id)) 
        INTO v_company_code 
        FROM companies 
        WHERE company_id = NEW.company_id;
        
        SELECT COALESCE(MAX(CAST(SUBSTRING_INDEX(job_code, '-', -1) AS UNSIGNED)), 0) + 1
        INTO v_seq
        FROM jobs
        WHERE company_id = NEW.company_id;
        
        SET NEW.job_code = CONCAT('JOB-', v_company_code, '-', LPAD(v_seq, 4, '0'));
    END IF;
END//

-- Generate company code
CREATE TRIGGER trg_company_code_generate
BEFORE INSERT ON companies
FOR EACH ROW
BEGIN
    DECLARE v_seq INT;
    
    IF NEW.company_code IS NULL THEN
        SELECT COALESCE(MAX(CAST(SUBSTRING(company_code, 5) AS UNSIGNED)), 0) + 1
        INTO v_seq
        FROM companies
        WHERE company_code LIKE 'CMP-%';
        
        SET NEW.company_code = CONCAT('CMP-', LPAD(v_seq, 5, '0'));
    END IF;
END//

-- ============================================================================
-- SKILLS TEXT SYNC TRIGGERS
-- ============================================================================

-- Sync seeker skills_text when seeker_skills changes
CREATE TRIGGER trg_seeker_skills_sync_insert
AFTER INSERT ON seeker_skills
FOR EACH ROW
BEGIN
    UPDATE seekers s
    SET skills_text = (
        SELECT GROUP_CONCAT(sk.skill_name SEPARATOR ' ')
        FROM seeker_skills ss
        JOIN skills sk ON ss.skill_id = sk.skill_id
        WHERE ss.seeker_id = NEW.seeker_id
    )
    WHERE s.seeker_id = NEW.seeker_id;
END//

CREATE TRIGGER trg_seeker_skills_sync_delete
AFTER DELETE ON seeker_skills
FOR EACH ROW
BEGIN
    UPDATE seekers s
    SET skills_text = COALESCE(
        (SELECT GROUP_CONCAT(sk.skill_name SEPARATOR ' ')
         FROM seeker_skills ss
         JOIN skills sk ON ss.skill_id = sk.skill_id
         WHERE ss.seeker_id = OLD.seeker_id),
        ''
    )
    WHERE s.seeker_id = OLD.seeker_id;
END//

-- Sync job skills text when job_skills changes
CREATE TRIGGER trg_job_skills_sync_insert
AFTER INSERT ON job_skills
FOR EACH ROW
BEGIN
    UPDATE jobs j
    SET 
        required_skills = COALESCE(
            (SELECT GROUP_CONCAT(sk.skill_name SEPARATOR ' ')
             FROM job_skills js
             JOIN skills sk ON js.skill_id = sk.skill_id
             WHERE js.job_id = NEW.job_id AND js.is_required = TRUE),
            j.required_skills
        ),
        preferred_skills = COALESCE(
            (SELECT GROUP_CONCAT(sk.skill_name SEPARATOR ' ')
             FROM job_skills js
             JOIN skills sk ON js.skill_id = sk.skill_id
             WHERE js.job_id = NEW.job_id AND js.is_required = FALSE),
            j.preferred_skills
        )
    WHERE j.job_id = NEW.job_id;
END//

-- ============================================================================
-- APPLICATION TRIGGERS
-- ============================================================================

-- Update positions filled when application status changes to 'hired'
CREATE TRIGGER trg_application_hired
AFTER UPDATE ON applications
FOR EACH ROW
BEGIN
    IF NEW.status = 'hired' AND OLD.status != 'hired' THEN
        UPDATE jobs 
        SET positions_filled = positions_filled + 1
        WHERE job_id = NEW.job_id;
    ELSEIF OLD.status = 'hired' AND NEW.status != 'hired' THEN
        UPDATE jobs 
        SET positions_filled = GREATEST(positions_filled - 1, 0)
        WHERE job_id = OLD.job_id;
    END IF;
END//

-- Auto-calculate match score on application insert
CREATE TRIGGER trg_application_score
BEFORE INSERT ON applications
FOR EACH ROW
BEGIN
    DECLARE v_score DECIMAL(5,2);
    
    SELECT MATCH(s.skills_text) AGAINST(
        (SELECT required_skills FROM jobs WHERE job_id = NEW.job_id) 
        IN BOOLEAN MODE
    ) INTO v_score
    FROM seekers s
    WHERE s.seeker_id = NEW.seeker_id;
    
    SET NEW.match_score = COALESCE(v_score, 0);
END//

-- ============================================================================
-- ACTIVITY TRACKING TRIGGERS
-- ============================================================================

-- Update last_active_at for seekers
CREATE TRIGGER trg_seeker_activity
BEFORE UPDATE ON seekers
FOR EACH ROW
BEGIN
    SET NEW.last_active_at = CURRENT_TIMESTAMP;
END//

DELIMITER ;
