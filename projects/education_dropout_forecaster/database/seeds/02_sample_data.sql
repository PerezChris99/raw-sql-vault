-- ============================================================================
-- Seed Data: Sample Students and Events
-- Education Dropout Forecaster
-- PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- SAMPLE STUDENTS - Active
-- ============================================================================

INSERT INTO students (school_id, first_name, last_name, date_of_birth, gender, ethnicity, grade_level, academic_year, enrolled_date, status, gpa, attendance_rate, disciplinary_incidents, retained_grade, free_reduced_lunch, english_learner, special_education, homeless, foster_care, single_parent_household, guardian_name, guardian_phone) VALUES

-- Lincoln High School (LA) - Active Students
(1, 'Maria', 'Garcia', '2008-03-15', 'Female', 'Hispanic', 10, 2025, '2023-08-15', 'ACTIVE', 3.2, 94.5, 0, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Rosa Garcia', '(213) 555-1001'),
(1, 'James', 'Wilson', '2007-11-22', 'Male', 'White', 11, 2025, '2022-08-15', 'ACTIVE', 2.8, 88.2, 2, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Robert Wilson', '(213) 555-1002'),
(1, 'Aisha', 'Johnson', '2008-07-08', 'Female', 'Black', 10, 2025, '2023-08-15', 'ACTIVE', 3.6, 97.1, 0, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Denise Johnson', '(213) 555-1003'),
(1, 'Kevin', 'Nguyen', '2006-01-30', 'Male', 'Asian', 12, 2025, '2021-08-15', 'ACTIVE', 3.9, 99.2, 0, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Minh Nguyen', '(213) 555-1004'),
(1, 'Carlos', 'Martinez', '2008-09-12', 'Male', 'Hispanic', 10, 2025, '2023-08-15', 'ACTIVE', 1.8, 72.5, 5, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, 'Elena Martinez', '(213) 555-1005'),

-- Roosevelt High School (LA) - Active Students  
(2, 'Jennifer', 'Lee', '2007-04-18', 'Female', 'Asian', 11, 2025, '2022-08-15', 'ACTIVE', 3.7, 96.8, 0, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'David Lee', '(213) 555-2001'),
(2, 'Brandon', 'Davis', '2008-12-05', 'Male', 'Black', 10, 2025, '2023-08-15', 'ACTIVE', 2.1, 78.3, 4, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, TRUE, 'State Custody', '(213) 555-2002'),
(2, 'Sofia', 'Rodriguez', '2007-06-21', 'Female', 'Hispanic', 11, 2025, '2022-08-15', 'ACTIVE', 2.9, 91.4, 1, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, 'Juan Rodriguez', '(213) 555-2003'),

-- Westside High School (Houston) - Active Students
(7, 'Tyler', 'Anderson', '2006-08-14', 'Male', 'White', 12, 2025, '2021-08-20', 'ACTIVE', 2.4, 82.1, 3, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Mark Anderson', '(713) 555-1001'),
(7, 'Destiny', 'Brown', '2008-02-28', 'Female', 'Black', 10, 2025, '2023-08-20', 'ACTIVE', 3.1, 93.7, 0, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Sharon Brown', '(713) 555-1002'),
(7, 'Miguel', 'Hernandez', '2007-10-09', 'Male', 'Hispanic', 11, 2025, '2022-08-20', 'ACTIVE', 1.6, 68.9, 6, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, 'Maria Hernandez', '(713) 555-1003'),
(7, 'Ashley', 'Taylor', '2007-05-17', 'Female', 'White', 11, 2025, '2022-08-20', 'ACTIVE', 3.4, 95.2, 0, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Steven Taylor', '(713) 555-1004'),

-- Chicago Public Schools - Active Students
(13, 'Jaylen', 'Jackson', '2006-11-03', 'Male', 'Black', 12, 2025, '2021-08-25', 'ACTIVE', 2.7, 85.6, 2, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Patricia Jackson', '(773) 555-1001'),
(13, 'Emma', 'Miller', '2008-04-22', 'Female', 'White', 10, 2025, '2023-08-25', 'ACTIVE', 3.8, 98.1, 0, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Thomas Miller', '(773) 555-1002'),
(14, 'Daniel', 'Kim', '2007-09-16', 'Male', 'Asian', 11, 2025, '2022-08-25', 'ACTIVE', 3.5, 94.8, 0, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Jin Kim', '(773) 555-1003'),

-- NYC Schools - Active Students
(10, 'Isabella', 'Chen', '2006-03-08', 'Female', 'Asian', 12, 2025, '2021-09-05', 'ACTIVE', 4.0, 99.8, 0, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Wei Chen', '(212) 555-1001'),
(11, 'Marcus', 'Williams', '2007-07-14', 'Male', 'Black', 11, 2025, '2022-09-05', 'ACTIVE', 2.3, 76.4, 5, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, 'Angela Williams', '(718) 555-1001'),
(11, 'Sophia', 'Patel', '2008-01-25', 'Female', 'Asian', 10, 2025, '2023-09-05', 'ACTIVE', 3.3, 92.6, 1, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Raj Patel', '(718) 555-1002');

-- ============================================================================
-- SAMPLE STUDENTS - Dropped Out
-- ============================================================================

INSERT INTO students (school_id, first_name, last_name, date_of_birth, gender, ethnicity, grade_level, academic_year, enrolled_date, status, dropout_date, dropout_reason_id, gpa, attendance_rate, disciplinary_incidents, retained_grade, free_reduced_lunch, english_learner, special_education, homeless, foster_care, single_parent_household, guardian_name) VALUES

-- Dropped students - Various schools
(1, 'Anthony', 'Reyes', '2007-08-19', 'Male', 'Hispanic', 11, 2025, '2022-08-15', 'DROPPED', '2024-12-15', 1, 1.2, 62.3, 8, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, 'Carmen Reyes'),
(1, 'Diamond', 'Smith', '2008-05-27', 'Female', 'Black', 10, 2025, '2023-08-15', 'DROPPED', '2024-10-22', 10, 2.1, 71.8, 2, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, 'State Custody'),
(2, 'Jose', 'Lopez', '2006-12-11', 'Male', 'Hispanic', 12, 2025, '2021-08-15', 'DROPPED', '2024-11-30', 9, 1.8, 58.4, 4, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, 'Maria Lopez'),
(7, 'DeShawn', 'Harris', '2007-03-24', 'Male', 'Black', 11, 2025, '2022-08-20', 'DROPPED', '2024-09-18', 7, 1.5, 54.2, 12, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, TRUE, 'Linda Harris'),
(7, 'Crystal', 'Jones', '2008-06-30', 'Female', 'Black', 10, 2025, '2023-08-20', 'DROPPED', '2025-01-08', 2, 2.4, 78.9, 1, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Tonya Jones'),
(13, 'Roberto', 'Sanchez', '2007-01-15', 'Male', 'Hispanic', 11, 2025, '2022-08-25', 'DROPPED', '2024-11-12', 1, 1.3, 65.7, 6, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, 'Rosa Sanchez'),
(11, 'Jasmine', 'Thompson', '2007-09-02', 'Female', 'Black', 11, 2025, '2022-09-05', 'DROPPED', '2024-10-05', 3, 2.0, 70.2, 3, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Carol Thompson'),
(15, 'Diego', 'Morales', '2006-04-18', 'Male', 'Hispanic', 12, 2025, '2021-08-25', 'DROPPED', '2024-08-30', 9, 1.9, 59.8, 5, TRUE, TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, 'State Custody'),

-- Previous year dropouts (2024)
(1, 'Tyrone', 'Washington', '2006-07-21', 'Male', 'Black', 12, 2024, '2020-08-15', 'DROPPED', '2024-02-14', 7, 1.4, 52.1, 15, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, 'Barbara Washington'),
(2, 'Monica', 'Rivera', '2007-11-08', 'Female', 'Hispanic', 11, 2024, '2021-08-15', 'DROPPED', '2024-03-22', 10, 2.2, 75.6, 1, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Luis Rivera'),
(7, 'Dwayne', 'Mitchell', '2006-02-14', 'Male', 'Black', 12, 2024, '2020-08-20', 'DROPPED', '2024-01-18', 6, 1.1, 48.3, 20, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, 'State Custody'),
(13, 'Stephanie', 'Clark', '2007-08-05', 'Female', 'White', 11, 2024, '2021-08-25', 'DROPPED', '2024-04-10', 4, 2.6, 82.4, 0, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, 'Michael Clark');

-- ============================================================================
-- ATTENDANCE RECORDS
-- ============================================================================

-- Generate attendance for high-risk student (Carlos Martinez - ID 5)
INSERT INTO attendance (student_id, attendance_date, status, excused) 
SELECT 
    5,
    generate_series('2025-01-06'::date, '2025-02-07'::date, '1 day')::date,
    CASE 
        WHEN random() < 0.25 THEN 'absent'
        WHEN random() < 0.35 THEN 'tardy'
        ELSE 'present'
    END,
    random() < 0.3
WHERE EXTRACT(DOW FROM generate_series('2025-01-06'::date, '2025-02-07'::date, '1 day')) NOT IN (0, 6);

-- Generate attendance for low-risk student (Kevin Nguyen - ID 4)
INSERT INTO attendance (student_id, attendance_date, status, excused)
SELECT 
    4,
    generate_series('2025-01-06'::date, '2025-02-07'::date, '1 day')::date,
    CASE 
        WHEN random() < 0.02 THEN 'absent'
        ELSE 'present'
    END,
    TRUE
WHERE EXTRACT(DOW FROM generate_series('2025-01-06'::date, '2025-02-07'::date, '1 day')) NOT IN (0, 6);

-- ============================================================================
-- GRADE RECORDS
-- ============================================================================

-- Grades for high-risk student (Carlos Martinez)
INSERT INTO grades (student_id, subject_id, academic_year, semester, grade_value, letter_grade, is_passing) VALUES
(5, 1, 2025, 1, 55.0, 'F', FALSE),  -- Math
(5, 2, 2025, 1, 62.0, 'D', TRUE),   -- English
(5, 3, 2025, 1, 58.0, 'F', FALSE),  -- Science
(5, 4, 2025, 1, 65.0, 'D', TRUE);   -- Social Studies

-- Grades for high performer (Kevin Nguyen)
INSERT INTO grades (student_id, subject_id, academic_year, semester, grade_value, letter_grade, is_passing) VALUES
(4, 1, 2025, 1, 98.0, 'A+', TRUE),
(4, 2, 2025, 1, 95.0, 'A', TRUE),
(4, 3, 2025, 1, 97.0, 'A', TRUE),
(4, 4, 2025, 1, 94.0, 'A', TRUE);

-- Mixed grades for other students
INSERT INTO grades (student_id, subject_id, academic_year, semester, grade_value, letter_grade, is_passing) VALUES
(1, 1, 2025, 1, 85.0, 'B', TRUE),
(1, 2, 2025, 1, 88.0, 'B+', TRUE),
(2, 1, 2025, 1, 78.0, 'C+', TRUE),
(2, 2, 2025, 1, 75.0, 'C', TRUE),
(3, 1, 2025, 1, 92.0, 'A-', TRUE),
(3, 2, 2025, 1, 94.0, 'A', TRUE);

-- ============================================================================
-- DISCIPLINARY RECORDS
-- ============================================================================

INSERT INTO disciplinary_records (student_id, incident_type_id, incident_date, description, action_taken, days_suspended) VALUES
-- Carlos Martinez (high-risk)
(5, 3, '2024-09-15', 'Disrupting class multiple times', 'Detention', 0),
(5, 4, '2024-10-02', 'Refused to follow teacher instructions', 'Parent conference', 0),
(5, 3, '2024-10-22', 'Disrupting class', 'Detention', 0),
(5, 5, '2024-11-08', 'Fighting in cafeteria', 'Suspension', 3),
(5, 3, '2024-12-12', 'Classroom disruption', 'Detention', 0),

-- Brandon Davis (foster care)
(7, 4, '2024-09-20', 'Insubordination', 'Warning', 0),
(7, 3, '2024-10-15', 'Classroom disruption', 'Detention', 0),
(7, 6, '2024-11-05', 'Bullying incident', 'Counseling referral', 0),
(7, 4, '2024-12-01', 'Refused hall pass policy', 'Detention', 0),

-- James Wilson (moderate risk)
(2, 1, '2024-10-10', 'Late to class', 'Warning', 0),
(2, 3, '2024-11-18', 'Talking during test', 'Detention', 0);

-- ============================================================================
-- INTERVENTIONS
-- ============================================================================

INSERT INTO interventions (student_id, intervention_type_id, start_date, end_date, status, notes, effectiveness_score) VALUES
-- Carlos Martinez - multiple interventions tried
(5, 1, '2024-09-01', '2024-12-20', 'completed', 'Math tutoring twice weekly', 3),
(5, 6, '2024-10-15', NULL, 'active', 'Attendance monitoring plan', NULL),
(5, 7, '2024-11-01', NULL, 'active', 'Behavioral intervention plan', NULL),
(5, 8, '2024-10-01', '2024-11-30', 'completed', 'Weekly parent phone calls', 4),

-- Brandon Davis
(7, 2, '2024-09-15', NULL, 'active', 'Weekly counseling sessions', NULL),
(7, 3, '2024-10-01', NULL, 'active', 'Peer mentor assigned', NULL),

-- Previous dropouts - interventions that didn't work
(19, 1, '2023-09-01', '2024-01-15', 'cancelled', 'Student stopped attending tutoring', 2),
(19, 6, '2023-10-01', '2024-02-14', 'cancelled', 'Chronic truancy continued', 1),
(21, 2, '2023-09-15', '2024-01-18', 'cancelled', 'Student disengaged from counseling', 2);

-- ============================================================================
-- ANNUAL SCHOOL STATS (Historical)
-- ============================================================================

INSERT INTO annual_school_stats (school_id, academic_year, total_enrolled, total_dropouts, dropout_rate, avg_attendance_rate, avg_gpa, graduation_rate) VALUES
-- Lincoln High School
(1, 2022, 2350, 45, 1.91, 91.2, 2.7, 88.5),
(1, 2023, 2380, 52, 2.18, 90.8, 2.65, 87.2),
(1, 2024, 2400, 58, 2.42, 89.5, 2.6, 86.0),

-- Roosevelt High School
(2, 2022, 2150, 38, 1.77, 92.1, 2.8, 89.2),
(2, 2023, 2180, 42, 1.93, 91.5, 2.75, 88.5),
(2, 2024, 2200, 48, 2.18, 90.2, 2.7, 87.0),

-- Westside High School (Houston)
(7, 2022, 2550, 62, 2.43, 88.5, 2.5, 84.2),
(7, 2023, 2580, 71, 2.75, 87.2, 2.45, 82.8),
(7, 2024, 2600, 78, 3.00, 85.8, 2.4, 81.5),

-- Lane Tech (Chicago)
(13, 2022, 4150, 28, 0.67, 95.8, 3.2, 96.5),
(13, 2023, 4180, 32, 0.77, 95.2, 3.15, 95.8),
(13, 2024, 4200, 35, 0.83, 94.8, 3.1, 95.2),

-- Phoenix Academy (Alternative)
(15, 2022, 340, 85, 25.0, 72.5, 1.8, 45.2),
(15, 2023, 345, 92, 26.7, 70.2, 1.75, 42.8),
(15, 2024, 350, 98, 28.0, 68.5, 1.7, 40.5);

-- ============================================================================
-- UPDATE CALCULATED FIELDS (Trigger-based would handle in production)
-- ============================================================================

-- Recalculate risk scores for all students
UPDATE students SET 
    risk_score = 0,  -- This triggers the risk calculation trigger
    updated_at = CURRENT_TIMESTAMP
WHERE student_id > 0;
