-- ============================================================================
-- 🏥 HEALTHCARE OUTBREAK DETECTOR - SEED DATA
-- ============================================================================
-- File: 03_seed_data.sql
-- Purpose: Reference data, diseases, facilities, sample cases
-- Database: PostgreSQL 14+
-- Context: Uganda's healthcare surveillance system
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- SECTION 1: REGIONS (Uganda's 4 Regions)
-- ============================================================================

INSERT INTO surveillance.regions (region_code, region_name, population, latitude, longitude) VALUES
('CEN', 'Central', 11198353, 0.3476, 32.5825),
('EAS', 'Eastern', 9885777, 1.2500, 34.0000),
('NOR', 'Northern', 8234785, 2.7500, 32.5000),
('WES', 'Western', 9870422, -0.2500, 30.5000)
ON CONFLICT (region_code) DO NOTHING;

-- ============================================================================
-- SECTION 2: DISTRICTS (Key Districts by Region)
-- ============================================================================

-- Central Region Districts
INSERT INTO surveillance.districts (region_id, district_code, district_name, population, latitude, longitude) VALUES
((SELECT region_id FROM surveillance.regions WHERE region_code = 'CEN'), 'KLA', 'Kampala', 1680600, 0.3163, 32.5822),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'CEN'), 'WAK', 'Wakiso', 2007700, 0.4044, 32.4594),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'CEN'), 'MUK', 'Mukono', 599817, 0.3533, 32.7553),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'CEN'), 'MPG', 'Mpigi', 250548, 0.2256, 32.3142),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'CEN'), 'LUW', 'Luwero', 456958, 0.8494, 32.4733),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'CEN'), 'MSK', 'Masaka', 297004, -0.3136, 31.7350),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'CEN'), 'JJA', 'Jinja', 471242, 0.4244, 33.2041),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'CEN'), 'INB', 'Iganga', 504197, 0.6092, 33.4686),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'CEN'), 'KYJ', 'Kayunga', 368063, 0.7025, 32.8886),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'CEN'), 'BUT', 'Buikwe', 422771, 0.3347, 33.0342)
ON CONFLICT (district_code) DO NOTHING;

-- Eastern Region Districts
INSERT INTO surveillance.districts (region_id, district_code, district_name, population, latitude, longitude) VALUES
((SELECT region_id FROM surveillance.regions WHERE region_code = 'EAS'), 'MBA', 'Mbale', 488960, 1.0647, 34.1797),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'EAS'), 'SRT', 'Soroti', 296833, 1.7150, 33.6108),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'EAS'), 'TRR', 'Tororo', 517082, 0.6928, 34.1811),
((SELECT region_id FROM surnames.regions WHERE region_code = 'EAS'), 'BSA', 'Busia', 323662, 0.4544, 34.0922),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'EAS'), 'KUM', 'Kumi', 239268, 1.4608, 33.9361),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'EAS'), 'PAL', 'Pallisa', 386890, 1.1450, 33.7094),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'EAS'), 'KPC', 'Kapchorwa', 105186, 1.3969, 34.4503),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'EAS'), 'BDU', 'Bududa', 210173, 1.0025, 34.3286),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'EAS'), 'BUA', 'Butaleja', 224957, 0.9333, 33.9500),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'EAS'), 'NAM', 'Namutumba', 252562, 0.8350, 33.6650)
ON CONFLICT (district_code) DO NOTHING;

-- Northern Region Districts
INSERT INTO surveillance.districts (region_id, district_code, district_name, population, latitude, longitude) VALUES
((SELECT region_id FROM surveillance.regions WHERE region_code = 'NOR'), 'GUL', 'Gulu', 275613, 2.7747, 32.2990),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'NOR'), 'LRA', 'Lira', 408043, 2.2350, 32.5000),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'NOR'), 'ARU', 'Arua', 782077, 3.0192, 30.9108),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'NOR'), 'KTD', 'Kitgum', 204048, 3.2783, 32.8872),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'NOR'), 'MRT', 'Moroto', 103432, 2.5347, 34.6661),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'NOR'), 'APT', 'Apac', 368626, 1.9833, 32.5333),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'NOR'), 'PDE', 'Pader', 178004, 2.9500, 33.0500),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'NOR'), 'ADJ', 'Adjumani', 225251, 3.3778, 31.7908),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'NOR'), 'MOY', 'Moyo', 139012, 3.6500, 31.7167),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'NOR'), 'KOT', 'Kotido', 181050, 2.9803, 34.1331)
ON CONFLICT (district_code) DO NOTHING;

-- Western Region Districts
INSERT INTO surveillance.districts (region_id, district_code, district_name, population, latitude, longitude) VALUES
((SELECT region_id FROM surveillance.regions WHERE region_code = 'WES'), 'MBR', 'Mbarara', 472629, -0.6072, 30.6545),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'WES'), 'FSP', 'Fort Portal', 355800, 0.6710, 30.2750),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'WES'), 'KSE', 'Kasese', 694992, 0.1833, 30.0833),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'WES'), 'HOI', 'Hoima', 572986, 1.4331, 31.3525),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'WES'), 'MSN', 'Masindi', 291113, 1.6744, 31.7150),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'WES'), 'KBL', 'Kabale', 528231, -1.2492, 29.9917),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'WES'), 'RKG', 'Rukungiri', 314694, -0.8411, 29.9419),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'WES'), 'BSH', 'Bushenyi', 234440, -0.5278, 30.1867),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'WES'), 'NPC', 'Ntungamo', 483841, -0.8833, 30.2667),
((SELECT region_id FROM surveillance.regions WHERE region_code = 'WES'), 'KBR', 'Kibaale', 412292, 0.8167, 31.0333)
ON CONFLICT (district_code) DO NOTHING;

-- ============================================================================
-- SECTION 3: DISEASE CATEGORIES
-- ============================================================================

INSERT INTO surveillance.disease_categories (category_code, category_name, description) VALUES
('VBD', 'Vector-Borne Diseases', 'Diseases transmitted by vectors like mosquitoes, ticks'),
('WBD', 'Water-Borne Diseases', 'Diseases transmitted through contaminated water'),
('RES', 'Respiratory Diseases', 'Diseases affecting the respiratory system'),
('HEM', 'Hemorrhagic Fevers', 'Viral hemorrhagic fever diseases'),
('VPD', 'Vaccine-Preventable Diseases', 'Diseases preventable through vaccination'),
('STI', 'Sexually Transmitted Infections', 'Infections transmitted through sexual contact'),
('ZOO', 'Zoonotic Diseases', 'Diseases transmitted from animals to humans'),
('ENT', 'Enteric Diseases', 'Diseases of the intestinal tract'),
('NEU', 'Neurological Infections', 'Infections affecting the nervous system'),
('OTH', 'Other Notifiable Diseases', 'Other diseases requiring surveillance')
ON CONFLICT (category_code) DO NOTHING;

-- ============================================================================
-- SECTION 4: DISEASES
-- ============================================================================

INSERT INTO surveillance.diseases (
    category_id, disease_code, disease_name, icd10_code, transmission_mode,
    incubation_min_days, incubation_max_days, infectious_period_days, case_fatality_rate,
    is_notifiable, is_immediately_notifiable, is_outbreak_prone,
    endemic_baseline, outbreak_threshold, has_vaccine, has_treatment
) VALUES
-- Vector-Borne Diseases
((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'VBD'),
 'MAL', 'Malaria', 'B50', 'vector_borne', 7, 30, 0, 0.3,
 TRUE, FALSE, TRUE, 1000, 2000, FALSE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'VBD'),
 'DEN', 'Dengue Fever', 'A90', 'vector_borne', 4, 10, 7, 2.5,
 TRUE, TRUE, TRUE, 10, 50, TRUE, FALSE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'VBD'),
 'YEL', 'Yellow Fever', 'A95', 'vector_borne', 3, 6, 5, 20.0,
 TRUE, TRUE, TRUE, 0, 1, TRUE, FALSE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'VBD'),
 'ZIK', 'Zika Virus', 'U06.9', 'vector_borne', 3, 14, 7, 0.01,
 TRUE, TRUE, TRUE, 0, 5, FALSE, FALSE),

-- Water-Borne Diseases  
((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'WBD'),
 'CHO', 'Cholera', 'A00', 'waterborne', 1, 5, 14, 1.0,
 TRUE, TRUE, TRUE, 5, 10, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'WBD'),
 'TYP', 'Typhoid Fever', 'A01.0', 'waterborne', 7, 21, 14, 1.0,
 TRUE, FALSE, TRUE, 50, 100, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'WBD'),
 'HEA', 'Hepatitis A', 'B15', 'waterborne', 15, 50, 14, 0.3,
 TRUE, FALSE, TRUE, 20, 50, TRUE, FALSE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'WBD'),
 'DYS', 'Dysentery', 'A03', 'waterborne', 1, 7, 7, 0.1,
 TRUE, FALSE, TRUE, 100, 200, FALSE, TRUE),

-- Hemorrhagic Fevers
((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'HEM'),
 'EBO', 'Ebola Virus Disease', 'A98.4', 'contact', 2, 21, 21, 50.0,
 TRUE, TRUE, TRUE, 0, 1, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'HEM'),
 'MAR', 'Marburg Virus Disease', 'A98.3', 'contact', 2, 21, 21, 50.0,
 TRUE, TRUE, TRUE, 0, 1, FALSE, FALSE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'HEM'),
 'CRF', 'Crimean-Congo Hemorrhagic Fever', 'A98.0', 'vector_borne', 1, 13, 14, 30.0,
 TRUE, TRUE, TRUE, 0, 1, FALSE, FALSE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'HEM'),
 'LAS', 'Lassa Fever', 'A96.2', 'contact', 6, 21, 21, 15.0,
 TRUE, TRUE, TRUE, 0, 1, FALSE, TRUE),

-- Respiratory Diseases
((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'RES'),
 'C19', 'COVID-19', 'U07.1', 'airborne', 1, 14, 14, 1.5,
 TRUE, TRUE, TRUE, 100, 500, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'RES'),
 'TUB', 'Tuberculosis', 'A15', 'airborne', 14, 365, 180, 15.0,
 TRUE, FALSE, FALSE, 500, 1000, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'RES'),
 'INF', 'Influenza', 'J10', 'airborne', 1, 4, 7, 0.1,
 TRUE, FALSE, TRUE, 200, 500, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'RES'),
 'MEN', 'Meningitis (Bacterial)', 'G00', 'airborne', 2, 10, 7, 10.0,
 TRUE, TRUE, TRUE, 10, 30, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'RES'),
 'PNE', 'Pneumonia', 'J18', 'airborne', 1, 3, 7, 2.0,
 TRUE, FALSE, FALSE, 300, 600, TRUE, TRUE),

-- Vaccine-Preventable Diseases
((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'VPD'),
 'MEA', 'Measles', 'B05', 'airborne', 7, 21, 8, 0.2,
 TRUE, TRUE, TRUE, 20, 50, TRUE, FALSE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'VPD'),
 'RUB', 'Rubella', 'B06', 'airborne', 14, 21, 7, 0.01,
 TRUE, FALSE, TRUE, 10, 30, TRUE, FALSE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'VPD'),
 'POL', 'Poliomyelitis', 'A80', 'waterborne', 3, 35, 14, 5.0,
 TRUE, TRUE, TRUE, 0, 1, TRUE, FALSE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'VPD'),
 'TET', 'Tetanus', 'A35', 'contact', 3, 21, 0, 10.0,
 TRUE, FALSE, FALSE, 5, 10, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'VPD'),
 'PER', 'Pertussis (Whooping Cough)', 'A37', 'airborne', 7, 21, 21, 1.0,
 TRUE, FALSE, TRUE, 30, 60, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'VPD'),
 'DIP', 'Diphtheria', 'A36', 'airborne', 2, 5, 14, 10.0,
 TRUE, TRUE, TRUE, 0, 5, TRUE, TRUE),

-- Enteric Diseases
((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'ENT'),
 'ROT', 'Rotavirus', 'A08.0', 'foodborne', 1, 3, 10, 0.5,
 TRUE, FALSE, TRUE, 100, 200, TRUE, FALSE),

-- Zoonotic Diseases
((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'ZOO'),
 'RAB', 'Rabies', 'A82', 'contact', 20, 90, 0, 99.9,
 TRUE, TRUE, FALSE, 5, 10, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'ZOO'),
 'ANT', 'Anthrax', 'A22', 'contact', 1, 7, 7, 20.0,
 TRUE, TRUE, TRUE, 0, 3, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'ZOO'),
 'PLG', 'Plague', 'A20', 'vector_borne', 1, 7, 7, 30.0,
 TRUE, TRUE, TRUE, 0, 1, FALSE, TRUE),

-- STIs
((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'STI'),
 'HIV', 'HIV/AIDS', 'B20', 'sexual', 14, 365, 0, 0.0,
 TRUE, FALSE, FALSE, 1000, 2000, FALSE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'STI'),
 'HEB', 'Hepatitis B', 'B16', 'bloodborne', 45, 180, 180, 1.0,
 TRUE, FALSE, FALSE, 200, 400, TRUE, TRUE),

((SELECT category_id FROM surveillance.disease_categories WHERE category_code = 'STI'),
 'HEC', 'Hepatitis C', 'B17.1', 'bloodborne', 14, 180, 180, 0.5,
 TRUE, FALSE, FALSE, 100, 200, FALSE, TRUE)

ON CONFLICT (disease_code) DO UPDATE SET
    disease_name = EXCLUDED.disease_name,
    is_notifiable = EXCLUDED.is_notifiable,
    updated_at = CURRENT_TIMESTAMP;

-- ============================================================================
-- SECTION 5: HEALTH FACILITIES
-- ============================================================================

-- National Referral Hospitals
INSERT INTO surveillance.health_facilities (
    facility_code, facility_name, facility_type, district_id,
    bed_capacity, icu_beds, isolation_beds, is_reporting_facility, is_testing_facility, is_treatment_center
) VALUES
('MUL-NRH', 'Mulago National Referral Hospital', 'national_referral',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'KLA'),
 1500, 50, 100, TRUE, TRUE, TRUE),
 
('BUT-NRH', 'Butabika National Mental Referral Hospital', 'national_referral',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'KLA'),
 500, 10, 20, TRUE, TRUE, FALSE),

-- Regional Referral Hospitals
('JIN-RRH', 'Jinja Regional Referral Hospital', 'regional_referral',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'JJA'),
 400, 15, 30, TRUE, TRUE, TRUE),
 
('MBR-RRH', 'Mbarara Regional Referral Hospital', 'regional_referral',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'MBR'),
 400, 15, 30, TRUE, TRUE, TRUE),
 
('GUL-RRH', 'Gulu Regional Referral Hospital', 'regional_referral',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'GUL'),
 350, 12, 25, TRUE, TRUE, TRUE),
 
('MBA-RRH', 'Mbale Regional Referral Hospital', 'regional_referral',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'MBA'),
 350, 12, 25, TRUE, TRUE, TRUE),
 
('ARU-RRH', 'Arua Regional Referral Hospital', 'regional_referral',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'ARU'),
 300, 10, 20, TRUE, TRUE, TRUE),
 
('FSP-RRH', 'Fort Portal Regional Referral Hospital', 'regional_referral',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'FSP'),
 300, 10, 20, TRUE, TRUE, TRUE),
 
('HOI-RRH', 'Hoima Regional Referral Hospital', 'regional_referral',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'HOI'),
 300, 10, 20, TRUE, TRUE, TRUE),
 
('LRA-RRH', 'Lira Regional Referral Hospital', 'regional_referral',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'LRA'),
 300, 10, 20, TRUE, TRUE, TRUE),

-- District Hospitals (sample)
('WAK-DH', 'Entebbe Hospital', 'district_hospital',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'WAK'),
 200, 5, 15, TRUE, TRUE, FALSE),
 
('MUK-DH', 'Mukono General Hospital', 'district_hospital',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'MUK'),
 150, 4, 10, TRUE, FALSE, FALSE),
 
('MSK-DH', 'Masaka Regional Referral Hospital', 'district_hospital',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'MSK'),
 200, 5, 15, TRUE, TRUE, FALSE),
 
('KBL-DH', 'Kabale Hospital', 'district_hospital',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'KBL'),
 150, 4, 10, TRUE, FALSE, FALSE),
 
('KSE-DH', 'Kasese General Hospital', 'district_hospital',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'KSE'),
 150, 4, 10, TRUE, FALSE, FALSE),

-- Special Testing Laboratories
('UVRI-LAB', 'Uganda Virus Research Institute', 'laboratory',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'WAK'),
 0, 0, 0, TRUE, TRUE, FALSE),
 
('CPHL-LAB', 'Central Public Health Laboratories', 'laboratory',
 (SELECT district_id FROM surveillance.districts WHERE district_code = 'KLA'),
 0, 0, 0, TRUE, TRUE, FALSE)

ON CONFLICT (facility_code) DO UPDATE SET
    facility_name = EXCLUDED.facility_name,
    updated_at = CURRENT_TIMESTAMP;

-- ============================================================================
-- SECTION 6: SAMPLE PATIENTS
-- ============================================================================

-- Generate sample patients
INSERT INTO surveillance.patients (
    patient_code, first_name, last_name, date_of_birth, gender,
    phone, district_id, village, is_healthcare_worker
)
SELECT 
    'PAT-SEED-' || LPAD(s.n::TEXT, 6, '0'),
    (ARRAY['John', 'Mary', 'Peter', 'Sarah', 'James', 'Grace', 'David', 'Ruth', 'Joseph', 'Esther',
           'Moses', 'Rebecca', 'Samuel', 'Deborah', 'Daniel', 'Naomi', 'Joshua', 'Miriam', 'Isaac', 'Hannah'])[1 + (s.n % 20)],
    (ARRAY['Okello', 'Namugga', 'Kato', 'Nakato', 'Wasswa', 'Babirye', 'Mukasa', 'Nabukeera', 'Ssebunya', 'Nankya',
           'Ochieng', 'Apio', 'Odongo', 'Acen', 'Owor', 'Atim', 'Adong', 'Lakot', 'Ochan', 'Aber'])[1 + (s.n % 20)],
    CURRENT_DATE - ((15 + s.n * 7) || ' years')::INTERVAL - ((s.n % 365) || ' days')::INTERVAL,
    (ARRAY['male', 'female', 'male', 'female', 'male', 'female', 'male', 'female', 'male', 'female']::surveillance.gender_type[])[1 + (s.n % 10)],
    '+256' || (700000000 + s.n * 1234)::TEXT,
    (SELECT district_id FROM surveillance.districts ORDER BY RANDOM() LIMIT 1),
    (ARRAY['Kawempe', 'Naguru', 'Bugolobi', 'Ntinda', 'Kyebando', 'Bukoto', 'Kololo', 'Kamwokya', 'Kisaasi', 'Muyenga'])[1 + (s.n % 10)],
    (s.n % 50 = 0)  -- 2% are healthcare workers
FROM generate_series(1, 500) s(n)
ON CONFLICT (patient_code) DO NOTHING;

-- ============================================================================
-- SECTION 7: SEASONS (For pattern generation)
-- ============================================================================

-- Uganda's disease patterns are influenced by:
-- - Rainy seasons (March-May, October-December): Higher malaria, cholera
-- - Dry seasons (June-August, January-February): Different patterns

-- ============================================================================
-- SECTION 8: SAMPLE CASES (Recent data for testing)
-- ============================================================================

-- Generate malaria cases (endemic, higher baseline)
INSERT INTO surveillance.cases (
    case_number, patient_id, disease_id, district_id,
    reporting_facility_id, onset_date, report_date,
    case_status, severity, hospitalized
)
SELECT 
    'CASE-MAL-' || TO_CHAR(CURRENT_DATE - (s.n || ' days')::INTERVAL, 'YYYYMMDD') || '-' || LPAD(s.n::TEXT, 4, '0'),
    (SELECT patient_id FROM surveillance.patients ORDER BY RANDOM() LIMIT 1),
    (SELECT disease_id FROM surveillance.diseases WHERE disease_code = 'MAL'),
    (SELECT district_id FROM surveillance.districts ORDER BY RANDOM() LIMIT 1),
    (SELECT facility_id FROM surveillance.health_facilities WHERE is_reporting_facility = TRUE ORDER BY RANDOM() LIMIT 1),
    CURRENT_DATE - (s.n + (s.n % 3) || ' days')::INTERVAL,
    CURRENT_DATE - (s.n || ' days')::INTERVAL,
    (ARRAY['confirmed', 'suspected', 'confirmed', 'probable', 'confirmed']::surveillance.case_status[])[1 + (s.n % 5)],
    (ARRAY['mild', 'mild', 'moderate', 'mild', 'severe']::surveillance.severity_level[])[1 + (s.n % 5)],
    (s.n % 10 < 2)  -- 20% hospitalized
FROM generate_series(1, 200) s(n)
ON CONFLICT (case_number) DO NOTHING;

-- Generate cholera cases (outbreak simulation in specific district)
INSERT INTO surveillance.cases (
    case_number, patient_id, disease_id, district_id,
    reporting_facility_id, onset_date, report_date,
    case_status, severity, hospitalized
)
SELECT 
    'CASE-CHO-' || TO_CHAR(CURRENT_DATE - (s.n || ' days')::INTERVAL, 'YYYYMMDD') || '-' || LPAD(s.n::TEXT, 4, '0'),
    (SELECT patient_id FROM surveillance.patients ORDER BY RANDOM() LIMIT 1),
    (SELECT disease_id FROM surveillance.diseases WHERE disease_code = 'CHO'),
    (SELECT district_id FROM surveillance.districts WHERE district_code = 'KLA'),  -- Simulated outbreak in Kampala
    (SELECT facility_id FROM surveillance.health_facilities WHERE facility_code = 'MUL-NRH'),
    CURRENT_DATE - (s.n + 1 || ' days')::INTERVAL,
    CURRENT_DATE - (s.n || ' days')::INTERVAL,
    'confirmed'::surveillance.case_status,
    (ARRAY['moderate', 'severe', 'moderate', 'severe', 'critical']::surveillance.severity_level[])[1 + (s.n % 5)],
    TRUE
FROM generate_series(1, 25) s(n)
ON CONFLICT (case_number) DO NOTHING;

-- Generate COVID-19 cases
INSERT INTO surveillance.cases (
    case_number, patient_id, disease_id, district_id,
    reporting_facility_id, onset_date, report_date,
    case_status, severity, hospitalized, icu_admission
)
SELECT 
    'CASE-C19-' || TO_CHAR(CURRENT_DATE - (s.n || ' days')::INTERVAL, 'YYYYMMDD') || '-' || LPAD(s.n::TEXT, 4, '0'),
    (SELECT patient_id FROM surveillance.patients ORDER BY RANDOM() LIMIT 1),
    (SELECT disease_id FROM surveillance.diseases WHERE disease_code = 'C19'),
    (SELECT district_id FROM surveillance.districts ORDER BY RANDOM() LIMIT 1),
    (SELECT facility_id FROM surveillance.health_facilities WHERE is_testing_facility = TRUE ORDER BY RANDOM() LIMIT 1),
    CURRENT_DATE - (s.n + 2 || ' days')::INTERVAL,
    CURRENT_DATE - (s.n || ' days')::INTERVAL,
    (ARRAY['confirmed', 'confirmed', 'confirmed', 'suspected', 'confirmed']::surveillance.case_status[])[1 + (s.n % 5)],
    (ARRAY['mild', 'mild', 'moderate', 'mild', 'severe']::surveillance.severity_level[])[1 + (s.n % 5)],
    (s.n % 5 = 0),  -- 20% hospitalized
    (s.n % 20 = 0)  -- 5% ICU
FROM generate_series(1, 80) s(n)
ON CONFLICT (case_number) DO NOTHING;

-- Generate measles cases (outbreak simulation in Western region)
INSERT INTO surveillance.cases (
    case_number, patient_id, disease_id, district_id,
    reporting_facility_id, onset_date, report_date,
    case_status, severity, hospitalized
)
SELECT 
    'CASE-MEA-' || TO_CHAR(CURRENT_DATE - (s.n || ' days')::INTERVAL, 'YYYYMMDD') || '-' || LPAD(s.n::TEXT, 4, '0'),
    (SELECT patient_id FROM surveillance.patients ORDER BY RANDOM() LIMIT 1),
    (SELECT disease_id FROM surveillance.diseases WHERE disease_code = 'MEA'),
    (SELECT d.district_id FROM surveillance.districts d 
     JOIN surveillance.regions r ON d.region_id = r.region_id 
     WHERE r.region_code = 'WES' ORDER BY RANDOM() LIMIT 1),
    (SELECT facility_id FROM surveillance.health_facilities WHERE is_reporting_facility = TRUE ORDER BY RANDOM() LIMIT 1),
    CURRENT_DATE - (s.n + 3 || ' days')::INTERVAL,
    CURRENT_DATE - (s.n || ' days')::INTERVAL,
    'confirmed'::surveillance.case_status,
    (ARRAY['mild', 'moderate', 'mild', 'moderate', 'severe']::surveillance.severity_level[])[1 + (s.n % 5)],
    (s.n % 8 < 2)
FROM generate_series(1, 40) s(n)
ON CONFLICT (case_number) DO NOTHING;

-- Generate TB cases (chronic, different pattern)
INSERT INTO surveillance.cases (
    case_number, patient_id, disease_id, district_id,
    reporting_facility_id, onset_date, report_date,
    case_status, severity, hospitalized
)
SELECT 
    'CASE-TUB-' || TO_CHAR(CURRENT_DATE - (s.n * 3 || ' days')::INTERVAL, 'YYYYMMDD') || '-' || LPAD(s.n::TEXT, 4, '0'),
    (SELECT patient_id FROM surveillance.patients ORDER BY RANDOM() LIMIT 1),
    (SELECT disease_id FROM surveillance.diseases WHERE disease_code = 'TUB'),
    (SELECT district_id FROM surveillance.districts ORDER BY RANDOM() LIMIT 1),
    (SELECT facility_id FROM surveillance.health_facilities WHERE is_reporting_facility = TRUE ORDER BY RANDOM() LIMIT 1),
    CURRENT_DATE - ((s.n * 3) + 14 || ' days')::INTERVAL,
    CURRENT_DATE - (s.n * 3 || ' days')::INTERVAL,
    'confirmed'::surveillance.case_status,
    (ARRAY['moderate', 'moderate', 'severe', 'moderate', 'severe']::surveillance.severity_level[])[1 + (s.n % 5)],
    (s.n % 4 < 2)
FROM generate_series(1, 60) s(n)
ON CONFLICT (case_number) DO NOTHING;

-- ============================================================================
-- SECTION 9: POPULATE DAILY CASE COUNTS
-- ============================================================================

-- Aggregate existing cases into daily counts
INSERT INTO surveillance.daily_case_counts (
    count_date, disease_id, district_id, new_cases, confirmed_cases, suspected_cases
)
SELECT 
    c.report_date,
    c.disease_id,
    c.district_id,
    COUNT(*),
    COUNT(*) FILTER (WHERE c.case_status = 'confirmed'),
    COUNT(*) FILTER (WHERE c.case_status = 'suspected')
FROM surveillance.cases c
GROUP BY c.report_date, c.disease_id, c.district_id
ON CONFLICT (count_date, disease_id, district_id) DO UPDATE SET
    new_cases = EXCLUDED.new_cases,
    confirmed_cases = EXCLUDED.confirmed_cases,
    suspected_cases = EXCLUDED.suspected_cases,
    updated_at = CURRENT_TIMESTAMP;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_region_count INTEGER;
    v_district_count INTEGER;
    v_disease_count INTEGER;
    v_facility_count INTEGER;
    v_patient_count INTEGER;
    v_case_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_region_count FROM surveillance.regions;
    SELECT COUNT(*) INTO v_district_count FROM surveillance.districts;
    SELECT COUNT(*) INTO v_disease_count FROM surveillance.diseases;
    SELECT COUNT(*) INTO v_facility_count FROM surveillance.health_facilities;
    SELECT COUNT(*) INTO v_patient_count FROM surveillance.patients;
    SELECT COUNT(*) INTO v_case_count FROM surveillance.cases;
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'SEED DATA LOADED SUCCESSFULLY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Regions: %', v_region_count;
    RAISE NOTICE 'Districts: %', v_district_count;
    RAISE NOTICE 'Diseases: %', v_disease_count;
    RAISE NOTICE 'Health Facilities: %', v_facility_count;
    RAISE NOTICE 'Patients: %', v_patient_count;
    RAISE NOTICE 'Cases: %', v_case_count;
    RAISE NOTICE '==========================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Sample outbreak simulations:';
    RAISE NOTICE '  - Cholera outbreak in Kampala';
    RAISE NOTICE '  - Measles outbreak in Western Region';
    RAISE NOTICE '  - Endemic malaria across all districts';
    RAISE NOTICE '==========================================';
END $$;
