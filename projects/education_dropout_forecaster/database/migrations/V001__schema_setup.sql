-- ============================================================================
-- Migration V001: Schema Setup
-- Education Dropout Forecaster - Core Tables
-- PostgreSQL 14+
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- REFERENCE TABLES
-- ============================================================================

-- States
CREATE TABLE states (
    state_id SERIAL PRIMARY KEY,
    state_code VARCHAR(2) NOT NULL UNIQUE,
    state_name VARCHAR(100) NOT NULL,
    region VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Districts
CREATE TABLE districts (
    district_id SERIAL PRIMARY KEY,
    district_code VARCHAR(20) NOT NULL UNIQUE,
    district_name VARCHAR(200) NOT NULL,
    state_id INTEGER NOT NULL REFERENCES states(state_id),
    superintendent VARCHAR(200),
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    total_schools INTEGER DEFAULT 0,
    total_students INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- School Types
CREATE TABLE school_types (
    type_id SERIAL PRIMARY KEY,
    type_code VARCHAR(20) NOT NULL UNIQUE,
    type_name VARCHAR(100) NOT NULL,
    description TEXT
);

INSERT INTO school_types (type_code, type_name, description) VALUES
('ELEM', 'Elementary School', 'Grades K-5'),
('MIDDLE', 'Middle School', 'Grades 6-8'),
('HIGH', 'High School', 'Grades 9-12'),
('K8', 'K-8 School', 'Grades K-8'),
('K12', 'K-12 School', 'Grades K-12'),
('ALT', 'Alternative School', 'Alternative education programs'),
('CHARTER', 'Charter School', 'Public charter school'),
('MAGNET', 'Magnet School', 'Specialized magnet program');

-- Schools
CREATE TABLE schools (
    school_id SERIAL PRIMARY KEY,
    school_code VARCHAR(20) NOT NULL UNIQUE,
    school_name VARCHAR(200) NOT NULL,
    district_id INTEGER NOT NULL REFERENCES districts(district_id),
    type_id INTEGER REFERENCES school_types(type_id),
    address TEXT,
    city VARCHAR(100),
    zip_code VARCHAR(10),
    phone VARCHAR(20),
    principal VARCHAR(200),
    enrollment INTEGER DEFAULT 0,
    grade_levels VARCHAR(20), -- e.g., '9-12', 'K-5'
    is_title_i BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    established_year INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- DROPOUT REASON CODES
-- ============================================================================

CREATE TABLE dropout_reasons (
    reason_id SERIAL PRIMARY KEY,
    reason_code VARCHAR(10) NOT NULL UNIQUE,
    reason_name VARCHAR(100) NOT NULL,
    description TEXT,
    risk_weight DECIMAL(3,2) DEFAULT 0.5, -- 0.00 to 1.00
    is_preventable BOOLEAN DEFAULT TRUE,
    intervention_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dropout_reasons (reason_code, reason_name, description, risk_weight, is_preventable, intervention_type) VALUES
('ACD', 'Academic Failure', 'Unable to meet academic requirements', 0.80, TRUE, 'tutoring'),
('FIN', 'Financial Issues', 'Family financial hardship', 0.70, TRUE, 'financial_aid'),
('FAM', 'Family Circumstances', 'Family issues (caregiving, divorce, etc.)', 0.60, TRUE, 'counseling'),
('HLT', 'Health Problems', 'Physical or mental health issues', 0.50, TRUE, 'health_services'),
('REL', 'Relocation', 'Family moved out of district', 0.30, FALSE, NULL),
('BHV', 'Behavioral Issues', 'Disciplinary problems', 0.70, TRUE, 'behavioral'),
('ATT', 'Attendance Problems', 'Chronic absenteeism', 0.90, TRUE, 'attendance'),
('SOC', 'Social Issues', 'Bullying, peer problems', 0.50, TRUE, 'counseling'),
('WRK', 'Employment', 'Needed to work to support family', 0.65, TRUE, 'work_study'),
('PRG', 'Pregnancy/Parenting', 'Teen pregnancy or parenting', 0.55, TRUE, 'parent_support'),
('LGL', 'Legal Issues', 'Incarceration or legal problems', 0.60, FALSE, NULL),
('UNK', 'Unknown', 'Reason not documented', 0.50, FALSE, NULL);

-- ============================================================================
-- STUDENT STATUS TYPES
-- ============================================================================

CREATE TABLE student_statuses (
    status_id SERIAL PRIMARY KEY,
    status_code VARCHAR(20) NOT NULL UNIQUE,
    status_name VARCHAR(100) NOT NULL,
    is_enrolled BOOLEAN DEFAULT TRUE,
    is_dropout BOOLEAN DEFAULT FALSE
);

INSERT INTO student_statuses (status_code, status_name, is_enrolled, is_dropout) VALUES
('ACTIVE', 'Currently Enrolled', TRUE, FALSE),
('DROPPED', 'Dropped Out', FALSE, TRUE),
('GRADUATED', 'Graduated', FALSE, FALSE),
('TRANSFERRED', 'Transferred', FALSE, FALSE),
('EXPELLED', 'Expelled', FALSE, TRUE),
('SUSPENDED', 'Suspended', TRUE, FALSE),
('LOA', 'Leave of Absence', FALSE, FALSE),
('DECEASED', 'Deceased', FALSE, FALSE);

-- ============================================================================
-- STUDENTS
-- ============================================================================

CREATE TABLE students (
    student_id SERIAL PRIMARY KEY,
    student_code VARCHAR(20) NOT NULL UNIQUE,
    school_id INTEGER NOT NULL REFERENCES schools(school_id),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    gender VARCHAR(10),
    ethnicity VARCHAR(50),
    
    -- Academic info
    grade_level INTEGER,
    academic_year INTEGER NOT NULL,
    enrolled_date DATE NOT NULL,
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'ACTIVE' REFERENCES student_statuses(status_code),
    dropout_date DATE,
    dropout_reason_id INTEGER REFERENCES dropout_reasons(reason_id),
    
    -- Risk factors (denormalized for performance)
    gpa DECIMAL(3,2),
    attendance_rate DECIMAL(5,2), -- Percentage 0-100
    disciplinary_incidents INTEGER DEFAULT 0,
    retained_grade BOOLEAN DEFAULT FALSE,
    
    -- Socioeconomic factors
    free_reduced_lunch BOOLEAN DEFAULT FALSE,
    english_learner BOOLEAN DEFAULT FALSE,
    special_education BOOLEAN DEFAULT FALSE,
    homeless BOOLEAN DEFAULT FALSE,
    foster_care BOOLEAN DEFAULT FALSE,
    single_parent_household BOOLEAN DEFAULT FALSE,
    
    -- Contact
    guardian_name VARCHAR(200),
    guardian_phone VARCHAR(20),
    guardian_email VARCHAR(255),
    address TEXT,
    
    -- Risk score (calculated)
    risk_score DECIMAL(5,2) DEFAULT 0,
    risk_decile INTEGER,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ATTENDANCE
-- ============================================================================

CREATE TABLE attendance (
    attendance_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL, -- 'present', 'absent', 'tardy', 'excused'
    excused BOOLEAN DEFAULT FALSE,
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(student_id, attendance_date)
);

-- ============================================================================
-- GRADES
-- ============================================================================

CREATE TABLE subjects (
    subject_id SERIAL PRIMARY KEY,
    subject_code VARCHAR(20) NOT NULL UNIQUE,
    subject_name VARCHAR(100) NOT NULL,
    is_core BOOLEAN DEFAULT FALSE -- Math, English, Science, Social Studies
);

INSERT INTO subjects (subject_code, subject_name, is_core) VALUES
('MATH', 'Mathematics', TRUE),
('ENG', 'English/Language Arts', TRUE),
('SCI', 'Science', TRUE),
('SOC', 'Social Studies', TRUE),
('PHYS', 'Physical Education', FALSE),
('ART', 'Art', FALSE),
('MUSIC', 'Music', FALSE),
('FRLANG', 'Foreign Language', FALSE),
('TECH', 'Technology', FALSE),
('HEALTH', 'Health', FALSE);

CREATE TABLE grades (
    grade_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    subject_id INTEGER NOT NULL REFERENCES subjects(subject_id),
    academic_year INTEGER NOT NULL,
    semester INTEGER NOT NULL, -- 1 or 2
    grade_value DECIMAL(4,2), -- 0.00 to 100.00
    letter_grade VARCHAR(2), -- A, B+, C, etc.
    credits DECIMAL(3,1) DEFAULT 1.0,
    is_passing BOOLEAN,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(student_id, subject_id, academic_year, semester)
);

-- ============================================================================
-- DISCIPLINARY RECORDS
-- ============================================================================

CREATE TABLE incident_types (
    incident_type_id SERIAL PRIMARY KEY,
    type_code VARCHAR(20) NOT NULL UNIQUE,
    type_name VARCHAR(100) NOT NULL,
    severity INTEGER DEFAULT 1, -- 1-5 scale
    risk_weight DECIMAL(3,2) DEFAULT 0.1
);

INSERT INTO incident_types (type_code, type_name, severity, risk_weight) VALUES
('TARDY', 'Tardiness', 1, 0.02),
('DRESS', 'Dress Code Violation', 1, 0.02),
('DISRUPT', 'Classroom Disruption', 2, 0.05),
('INSUBORD', 'Insubordination', 2, 0.08),
('FIGHT', 'Fighting', 4, 0.15),
('BULLY', 'Bullying', 3, 0.12),
('VANDAL', 'Vandalism', 3, 0.10),
('THEFT', 'Theft', 3, 0.10),
('DRUGS', 'Drug/Alcohol', 5, 0.20),
('WEAPON', 'Weapons', 5, 0.25),
('ASSAULT', 'Assault', 5, 0.25);

CREATE TABLE disciplinary_records (
    record_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    incident_type_id INTEGER NOT NULL REFERENCES incident_types(incident_type_id),
    incident_date DATE NOT NULL,
    description TEXT,
    action_taken VARCHAR(100), -- detention, suspension, etc.
    days_suspended INTEGER DEFAULT 0,
    is_resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- INTERVENTIONS
-- ============================================================================

CREATE TABLE intervention_types (
    intervention_type_id SERIAL PRIMARY KEY,
    type_code VARCHAR(20) NOT NULL UNIQUE,
    type_name VARCHAR(100) NOT NULL,
    description TEXT
);

INSERT INTO intervention_types (type_code, type_name, description) VALUES
('TUTOR', 'Tutoring', 'Academic tutoring support'),
('COUNSEL', 'Counseling', 'Individual or group counseling'),
('MENTOR', 'Mentoring', 'Peer or adult mentorship program'),
('FINAID', 'Financial Aid', 'Financial assistance or scholarships'),
('HEALTH', 'Health Services', 'Medical or mental health services'),
('ATTEND', 'Attendance Plan', 'Attendance improvement plan'),
('BEHAV', 'Behavior Plan', 'Behavioral intervention plan'),
('PARENT', 'Parent Outreach', 'Parent engagement activities'),
('CREDIT', 'Credit Recovery', 'Credit recovery program'),
('ALT', 'Alternative Program', 'Alternative education placement');

CREATE TABLE interventions (
    intervention_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    intervention_type_id INTEGER NOT NULL REFERENCES intervention_types(intervention_type_id),
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'active', -- active, completed, cancelled
    notes TEXT,
    effectiveness_score INTEGER, -- 1-10 rating
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ANALYTICS TABLES
-- ============================================================================

-- Annual aggregated stats per school
CREATE TABLE annual_school_stats (
    stat_id SERIAL PRIMARY KEY,
    school_id INTEGER NOT NULL REFERENCES schools(school_id),
    academic_year INTEGER NOT NULL,
    total_enrolled INTEGER DEFAULT 0,
    total_dropouts INTEGER DEFAULT 0,
    dropout_rate DECIMAL(5,2),
    avg_attendance_rate DECIMAL(5,2),
    avg_gpa DECIMAL(3,2),
    graduation_rate DECIMAL(5,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(school_id, academic_year)
);

-- Risk scores history
CREATE TABLE risk_score_history (
    history_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(student_id) ON DELETE CASCADE,
    calculated_date DATE NOT NULL,
    risk_score DECIMAL(5,2) NOT NULL,
    risk_factors JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dropout events (for detailed tracking)
CREATE TABLE dropout_events (
    event_id SERIAL PRIMARY KEY,
    student_id INTEGER NOT NULL REFERENCES students(student_id),
    school_id INTEGER NOT NULL REFERENCES schools(school_id),
    district_id INTEGER NOT NULL REFERENCES districts(district_id),
    academic_year INTEGER NOT NULL,
    dropout_date DATE NOT NULL,
    reason_id INTEGER REFERENCES dropout_reasons(reason_id),
    grade_level INTEGER,
    gpa_at_dropout DECIMAL(3,2),
    attendance_at_dropout DECIMAL(5,2),
    risk_score_at_dropout DECIMAL(5,2),
    interventions_received INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- AUDIT TABLE
-- ============================================================================

CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER NOT NULL,
    action VARCHAR(20) NOT NULL, -- INSERT, UPDATE, DELETE
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SUMMARY
-- ============================================================================
-- Tables created: 19
-- States, Districts, Schools (hierarchy)
-- Dropout Reasons, Student Statuses (reference)
-- Students (core entity)
-- Attendance, Grades, Disciplinary Records (tracking)
-- Interventions (support tracking)
-- Analytics tables (aggregations)
-- ============================================================================
