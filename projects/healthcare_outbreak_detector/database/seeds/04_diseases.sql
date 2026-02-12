-- ============================================================================
-- Seed: 04_diseases.sql
-- Purpose: Disease registry with epidemiological parameters
-- ============================================================================

SET search_path TO surveillance, public;

-- Vaccine-Preventable Diseases
INSERT INTO surveillance.diseases 
    (category_id, disease_code, disease_name, icd10_code, transmission_mode, 
     incubation_min_days, incubation_max_days, is_immediately_notifiable, 
     outbreak_threshold, case_fatality_rate)
SELECT c.category_id, d.code, d.name, d.icd10, d.trans::surveillance.transmission_mode,
       d.inc_min, d.inc_max, d.notifiable, d.threshold, d.cfr
FROM surveillance.disease_categories c,
(VALUES
    ('VPD', 'MEA', 'Measles', 'B05', 'airborne', 7, 21, TRUE, 1, 2.0),
    ('VPD', 'RUB', 'Rubella', 'B06', 'droplet', 14, 21, TRUE, 1, 0.1),
    ('VPD', 'POL', 'Poliomyelitis', 'A80', 'fecal_oral', 3, 35, TRUE, 1, 5.0),
    ('VPD', 'TET', 'Tetanus (Neonatal)', 'A33', 'contact', 3, 21, TRUE, 1, 50.0),
    ('VPD', 'DIP', 'Diphtheria', 'A36', 'droplet', 2, 5, TRUE, 1, 10.0),
    ('VPD', 'PER', 'Pertussis', 'A37', 'droplet', 7, 20, FALSE, 5, 1.0),
    ('VPD', 'YEL', 'Yellow Fever', 'A95', 'vector', 3, 6, TRUE, 1, 20.0)
) AS d(cat_code, code, name, icd10, trans, inc_min, inc_max, notifiable, threshold, cfr)
WHERE c.category_code = d.cat_code
ON CONFLICT (disease_code) DO UPDATE SET
    disease_name = EXCLUDED.disease_name,
    icd10_code = EXCLUDED.icd10_code;

-- Acute Watery Diarrhea
INSERT INTO surveillance.diseases 
    (category_id, disease_code, disease_name, icd10_code, transmission_mode, 
     incubation_min_days, incubation_max_days, is_immediately_notifiable, 
     outbreak_threshold, case_fatality_rate)
SELECT c.category_id, d.code, d.name, d.icd10, d.trans::surveillance.transmission_mode,
       d.inc_min, d.inc_max, d.notifiable, d.threshold, d.cfr
FROM surveillance.disease_categories c,
(VALUES
    ('AWD', 'CHO', 'Cholera', 'A00', 'fecal_oral', 1, 5, TRUE, 1, 1.5),
    ('AWD', 'TYP', 'Typhoid Fever', 'A01', 'fecal_oral', 7, 21, TRUE, 5, 1.0),
    ('AWD', 'DYS', 'Dysentery', 'A03', 'fecal_oral', 1, 4, FALSE, 10, 0.5),
    ('AWD', 'ROT', 'Rotavirus', 'A08', 'fecal_oral', 1, 3, FALSE, 20, 0.1)
) AS d(cat_code, code, name, icd10, trans, inc_min, inc_max, notifiable, threshold, cfr)
WHERE c.category_code = d.cat_code
ON CONFLICT (disease_code) DO UPDATE SET
    disease_name = EXCLUDED.disease_name,
    icd10_code = EXCLUDED.icd10_code;

-- Viral Hemorrhagic Fevers (HIGHEST PRIORITY)
INSERT INTO surveillance.diseases 
    (category_id, disease_code, disease_name, icd10_code, transmission_mode, 
     incubation_min_days, incubation_max_days, is_immediately_notifiable, 
     outbreak_threshold, case_fatality_rate)
SELECT c.category_id, d.code, d.name, d.icd10, d.trans::surveillance.transmission_mode,
       d.inc_min, d.inc_max, d.notifiable, d.threshold, d.cfr
FROM surveillance.disease_categories c,
(VALUES
    ('VHF', 'EBO', 'Ebola Virus Disease', 'A98.4', 'contact', 2, 21, TRUE, 1, 50.0),
    ('VHF', 'MAR', 'Marburg Virus Disease', 'A98.3', 'contact', 2, 21, TRUE, 1, 50.0),
    ('VHF', 'CRH', 'Crimean-Congo HF', 'A98.0', 'contact', 1, 13, TRUE, 1, 30.0),
    ('VHF', 'RVF', 'Rift Valley Fever', 'A92.4', 'vector', 2, 6, TRUE, 1, 1.0),
    ('VHF', 'LAS', 'Lassa Fever', 'A96', 'contact', 6, 21, TRUE, 1, 15.0)
) AS d(cat_code, code, name, icd10, trans, inc_min, inc_max, notifiable, threshold, cfr)
WHERE c.category_code = d.cat_code
ON CONFLICT (disease_code) DO UPDATE SET
    disease_name = EXCLUDED.disease_name,
    case_fatality_rate = EXCLUDED.case_fatality_rate;

-- Vector-Borne Diseases
INSERT INTO surveillance.diseases 
    (category_id, disease_code, disease_name, icd10_code, transmission_mode, 
     incubation_min_days, incubation_max_days, is_immediately_notifiable, 
     outbreak_threshold, case_fatality_rate, baseline_cases_per_week)
SELECT c.category_id, d.code, d.name, d.icd10, d.trans::surveillance.transmission_mode,
       d.inc_min, d.inc_max, d.notifiable, d.threshold, d.cfr, d.baseline
FROM surveillance.disease_categories c,
(VALUES
    ('VBD', 'MAL', 'Malaria', 'B50', 'vector', 7, 30, FALSE, 50, 0.3, 100.0),
    ('VBD', 'DEN', 'Dengue', 'A90', 'vector', 4, 14, TRUE, 3, 2.5, 5.0),
    ('VBD', 'CHK', 'Chikungunya', 'A92.0', 'vector', 3, 12, TRUE, 5, 0.1, 2.0),
    ('VBD', 'ZIK', 'Zika Virus', 'A92.5', 'vector', 3, 14, TRUE, 3, 0.01, 1.0),
    ('VBD', 'TRY', 'Trypanosomiasis', 'B56', 'vector', 7, 21, FALSE, 5, 10.0, 2.0),
    ('VBD', 'PLG', 'Plague', 'A20', 'vector', 1, 7, TRUE, 1, 30.0, 0.0)
) AS d(cat_code, code, name, icd10, trans, inc_min, inc_max, notifiable, threshold, cfr, baseline)
WHERE c.category_code = d.cat_code
ON CONFLICT (disease_code) DO UPDATE SET
    baseline_cases_per_week = EXCLUDED.baseline_cases_per_week;

-- Zoonotic Diseases
INSERT INTO surveillance.diseases 
    (category_id, disease_code, disease_name, icd10_code, transmission_mode, 
     incubation_min_days, incubation_max_days, is_immediately_notifiable, 
     outbreak_threshold, case_fatality_rate)
SELECT c.category_id, d.code, d.name, d.icd10, d.trans::surveillance.transmission_mode,
       d.inc_min, d.inc_max, d.notifiable, d.threshold, d.cfr
FROM surveillance.disease_categories c,
(VALUES
    ('ZOO', 'RAB', 'Rabies', 'A82', 'contact', 20, 90, TRUE, 1, 99.9),
    ('ZOO', 'ANT', 'Anthrax', 'A22', 'contact', 1, 7, TRUE, 1, 20.0),
    ('ZOO', 'BRU', 'Brucellosis', 'A23', 'contact', 5, 60, FALSE, 5, 2.0),
    ('ZOO', 'LEP', 'Leptospirosis', 'A27', 'contact', 2, 30, FALSE, 5, 5.0)
) AS d(cat_code, code, name, icd10, trans, inc_min, inc_max, notifiable, threshold, cfr)
WHERE c.category_code = d.cat_code
ON CONFLICT (disease_code) DO UPDATE SET
    disease_name = EXCLUDED.disease_name;

-- Acute Respiratory Infections
INSERT INTO surveillance.diseases 
    (category_id, disease_code, disease_name, icd10_code, transmission_mode, 
     incubation_min_days, incubation_max_days, is_immediately_notifiable, 
     outbreak_threshold, case_fatality_rate)
SELECT c.category_id, d.code, d.name, d.icd10, d.trans::surveillance.transmission_mode,
       d.inc_min, d.inc_max, d.notifiable, d.threshold, d.cfr
FROM surveillance.disease_categories c,
(VALUES
    ('ARI', 'ILI', 'Influenza-Like Illness', 'J11', 'droplet', 1, 4, FALSE, 20, 0.1),
    ('ARI', 'COV', 'COVID-19', 'U07.1', 'airborne', 2, 14, TRUE, 5, 1.0),
    ('ARI', 'SAR', 'SARS', 'U04', 'droplet', 2, 10, TRUE, 1, 10.0),
    ('ARI', 'MER', 'MERS', 'U04.9', 'droplet', 2, 14, TRUE, 1, 35.0),
    ('ARI', 'PNE', 'Pneumonia', 'J18', 'droplet', 1, 3, FALSE, 15, 3.0)
) AS d(cat_code, code, name, icd10, trans, inc_min, inc_max, notifiable, threshold, cfr)
WHERE c.category_code = d.cat_code
ON CONFLICT (disease_code) DO UPDATE SET
    disease_name = EXCLUDED.disease_name;

-- Meningitis (Epidemic-Prone)
INSERT INTO surveillance.diseases 
    (category_id, disease_code, disease_name, icd10_code, transmission_mode, 
     incubation_min_days, incubation_max_days, is_immediately_notifiable, 
     outbreak_threshold, case_fatality_rate)
SELECT c.category_id, d.code, d.name, d.icd10, d.trans::surveillance.transmission_mode,
       d.inc_min, d.inc_max, d.notifiable, d.threshold, d.cfr
FROM surveillance.disease_categories c,
(VALUES
    ('EPD', 'MEN', 'Meningococcal Meningitis', 'A39', 'droplet', 2, 10, TRUE, 2, 10.0),
    ('EPD', 'AFE', 'Acute Flaccid Paralysis', 'G82', 'fecal_oral', 3, 35, TRUE, 1, 5.0)
) AS d(cat_code, code, name, icd10, trans, inc_min, inc_max, notifiable, threshold, cfr)
WHERE c.category_code = d.cat_code
ON CONFLICT (disease_code) DO UPDATE SET
    disease_name = EXCLUDED.disease_name;
