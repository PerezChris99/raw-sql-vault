-- ============================================================================
-- Seed Data: Reference Data
-- Education Dropout Forecaster
-- PostgreSQL 14+
-- ============================================================================

-- ============================================================================
-- STATES
-- ============================================================================

INSERT INTO states (state_code, state_name, region) VALUES
('CA', 'California', 'West'),
('TX', 'Texas', 'South'),
('NY', 'New York', 'Northeast'),
('FL', 'Florida', 'South'),
('IL', 'Illinois', 'Midwest'),
('PA', 'Pennsylvania', 'Northeast'),
('OH', 'Ohio', 'Midwest'),
('GA', 'Georgia', 'South'),
('NC', 'North Carolina', 'South'),
('MI', 'Michigan', 'Midwest');

-- ============================================================================
-- DISTRICTS
-- ============================================================================

INSERT INTO districts (district_code, district_name, state_id, superintendent, phone, email) VALUES
-- California Districts
('CA-LAUSD', 'Los Angeles Unified', 1, 'Dr. Maria Santos', '(213) 555-0100', 'superintendent@lausd.edu'),
('CA-SFUSD', 'San Francisco Unified', 1, 'Dr. James Chen', '(415) 555-0200', 'superintendent@sfusd.edu'),
('CA-SDUSD', 'San Diego Unified', 1, 'Dr. Patricia Williams', '(619) 555-0300', 'superintendent@sdusd.edu'),

-- Texas Districts
('TX-HISD', 'Houston Independent', 2, 'Dr. Robert Johnson', '(713) 555-0100', 'superintendent@hisd.edu'),
('TX-DISD', 'Dallas Independent', 2, 'Dr. Angela Davis', '(214) 555-0200', 'superintendent@disd.edu'),

-- New York Districts
('NY-NYCPS', 'NYC Public Schools', 3, 'Dr. David Martinez', '(212) 555-0100', 'chancellor@nycps.edu'),
('NY-BUFFALO', 'Buffalo Public Schools', 3, 'Dr. Lisa Thompson', '(716) 555-0200', 'superintendent@buffaloschools.edu'),

-- Florida Districts
('FL-MDCPS', 'Miami-Dade County', 4, 'Dr. Carlos Rodriguez', '(305) 555-0100', 'superintendent@mdcps.edu'),

-- Illinois Districts
('IL-CPS', 'Chicago Public Schools', 5, 'Dr. Michele Brown', '(773) 555-0100', 'ceo@cps.edu'),

-- Georgia Districts
('GA-APS', 'Atlanta Public Schools', 8, 'Dr. Kevin White', '(404) 555-0100', 'superintendent@aps.edu');

-- ============================================================================
-- SCHOOLS
-- ============================================================================

-- Los Angeles Unified Schools
INSERT INTO schools (school_code, school_name, district_id, type_id, city, principal, enrollment, grade_levels, is_title_i, established_year) VALUES
('LA-HS-001', 'Lincoln High School', 1, 3, 'Los Angeles', 'Dr. Sarah Johnson', 2400, '9-12', TRUE, 1878),
('LA-HS-002', 'Roosevelt High School', 1, 3, 'Los Angeles', 'Mr. Michael Torres', 2200, '9-12', TRUE, 1923),
('LA-MS-001', 'Emerson Middle School', 1, 2, 'Los Angeles', 'Ms. Jennifer Lee', 1100, '6-8', TRUE, 1952),
('LA-ELEM-001', 'Washington Elementary', 1, 1, 'Los Angeles', 'Mrs. Patricia Garcia', 650, 'K-5', TRUE, 1895),

-- San Francisco Unified Schools
('SF-HS-001', 'Galileo High School', 2, 3, 'San Francisco', 'Dr. Kevin Chang', 1800, '9-12', FALSE, 1921),
('SF-MS-001', 'Presidio Middle School', 2, 2, 'San Francisco', 'Ms. Amy Wong', 900, '6-8', FALSE, 1960),

-- Houston Independent Schools
('HOU-HS-001', 'Westside High School', 4, 3, 'Houston', 'Dr. James Williams', 2600, '9-12', TRUE, 1965),
('HOU-HS-002', 'Bellaire High School', 4, 3, 'Houston', 'Mrs. Linda Martinez', 2800, '9-12', FALSE, 1955),
('HOU-MS-001', 'Pershing Middle School', 4, 2, 'Houston', 'Mr. David Brown', 1200, '6-8', FALSE, 1958),

-- NYC Public Schools
('NYC-HS-001', 'Bronx High School of Science', 6, 3, 'Bronx', 'Dr. Rachel Kim', 3000, '9-12', FALSE, 1938),
('NYC-HS-002', 'Brooklyn Tech', 6, 3, 'Brooklyn', 'Mr. Anthony DeLuca', 5800, '9-12', FALSE, 1922),
('NYC-MS-001', 'IS 318 Math & Science', 6, 2, 'Brooklyn', 'Ms. Donna Miller', 1400, '6-8', TRUE, 1965),

-- Chicago Public Schools
('CHI-HS-001', 'Lane Tech High School', 9, 3, 'Chicago', 'Dr. Brian O''Connor', 4200, '9-12', FALSE, 1908),
('CHI-HS-002', 'Whitney Young High School', 9, 7, 'Chicago', 'Ms. Theresa Jackson', 2100, '9-12', FALSE, 1975),
('CHI-ALT-001', 'Phoenix Academy', 9, 6, 'Chicago', 'Mr. Carlos Hernandez', 350, '9-12', TRUE, 2005),

-- Miami-Dade Schools
('MIA-HS-001', 'Miami Beach High', 8, 3, 'Miami Beach', 'Dr. Elena Gonzalez', 1900, '9-12', FALSE, 1927),
('MIA-MS-001', 'Nautilus Middle School', 8, 2, 'Miami Beach', 'Mr. Roberto Santos', 1100, '6-8', FALSE, 1955),

-- Atlanta Public Schools
('ATL-HS-001', 'North Atlanta High', 10, 3, 'Atlanta', 'Dr. Marcus Washington', 2100, '9-12', FALSE, 2013),
('ATL-HS-002', 'Grady High School', 10, 3, 'Atlanta', 'Ms. Sharon Brooks', 1400, '9-12', TRUE, 1947),
('ATL-ALT-001', 'B.E.S.T. Academy', 10, 6, 'Atlanta', 'Mr. Terrance Jones', 400, '9-12', TRUE, 2010);

-- ============================================================================
-- ADDITIONAL SUBJECTS (Expanding on defaults)
-- ============================================================================

INSERT INTO subjects (subject_code, subject_name, is_core) VALUES
('CHEM', 'Chemistry', TRUE),
('PHYS', 'Physics', TRUE),
('BIO', 'Biology', TRUE),
('HIST', 'History', TRUE),
('GOVT', 'Government', TRUE),
('ECON', 'Economics', FALSE),
('PSYCH', 'Psychology', FALSE),
('CALC', 'Calculus', FALSE),
('STATS', 'Statistics', FALSE),
('COMP', 'Computer Science', FALSE),
('SPAN', 'Spanish', FALSE),
('FREN', 'French', FALSE),
('MAND', 'Mandarin', FALSE)
ON CONFLICT (subject_code) DO NOTHING;

-- ============================================================================
-- UPDATE DISTRICT COUNTS
-- ============================================================================

UPDATE districts SET 
    total_schools = (SELECT COUNT(*) FROM schools WHERE district_id = districts.district_id AND is_active = TRUE),
    total_students = (SELECT COALESCE(SUM(enrollment), 0) FROM schools WHERE district_id = districts.district_id AND is_active = TRUE);
