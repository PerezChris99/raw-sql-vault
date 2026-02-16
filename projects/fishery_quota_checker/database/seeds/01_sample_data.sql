-- ============================================================================
-- Fishery Quota Compliance Checker - Sample Data
-- PostgreSQL 14+
-- ============================================================================

-- Fish species
INSERT INTO fish_species (species_name, local_name, min_size_cm, max_quota_per_month_kg, conservation_status) VALUES
('Nile Perch', 'Mputa', 50.0, 500, 'monitored'),
('Tilapia', 'Ngege', 20.0, 300, 'normal'),
('Dagaa', 'Mukene', 3.0, 1000, 'normal'),
('Lungfish', 'Mamba', 40.0, 100, 'protected'),
('Catfish', 'Emmale', 30.0, 200, 'normal')
ON CONFLICT (species_name) DO NOTHING;

-- Landing sites (Lake Victoria, Uganda)
INSERT INTO landing_sites (site_name, district, latitude, longitude) VALUES
('Ggaba Landing Site', 'Kampala', 0.2589, 32.6267),
('Kasenyi Landing Site', 'Wakiso', 0.1156, 32.4697),
('Kiyindi Landing Site', 'Buikwe', 0.2917, 33.0250),
('Masese Landing Site', 'Jinja', 0.4333, 33.2000),
('Katosi Landing Site', 'Mukono', 0.1667, 32.9500)
ON CONFLICT (site_name) DO NOTHING;

-- Fishers
INSERT INTO fishers (license_number, fisher_name, boat_name, landing_site_id, license_issue_date, license_expiry_date)
SELECT 
    'LV-' || LPAD(seq::TEXT, 4, '0'),
    'Fisher ' || seq,
    'Boat ' || CHR(64 + (seq % 26) + 1) || (seq / 26 + 1)::TEXT,
    (seq % 5) + 1,
    CURRENT_DATE - INTERVAL '1 year',
    CURRENT_DATE + INTERVAL '1 year'
FROM GENERATE_SERIES(1, 20) AS seq
ON CONFLICT (license_number) DO NOTHING;

-- Monthly quotas (current and previous months)
INSERT INTO monthly_quotas (species_id, year_month, quota_kg, reason)
SELECT 
    s.species_id,
    DATE_TRUNC('month', CURRENT_DATE - (m || ' months')::INTERVAL),
    s.max_quota_per_month_kg * CASE WHEN m BETWEEN 3 AND 5 THEN 0.8 ELSE 1.0 END, -- Breeding season reduction
    CASE WHEN m BETWEEN 3 AND 5 THEN 'Breeding season - reduced quota' ELSE 'Standard quota' END
FROM fish_species s
CROSS JOIN GENERATE_SERIES(0, 6) AS m
ON CONFLICT (species_id, year_month) DO NOTHING;

-- Catch records (simulate catches over 3 months)
INSERT INTO catches (fisher_id, species_id, catch_date, catch_weight_kg, fish_count, avg_size_cm, landing_site_id)
SELECT 
    f.fisher_id,
    s.species_id,
    CURRENT_DATE - (RANDOM() * 90)::INT,
    (RANDOM() * s.max_quota_per_month_kg * 0.3)::DECIMAL(8,2),
    (RANDOM() * 50 + 10)::INT,
    s.min_size_cm + (RANDOM() * 20),
    f.landing_site_id
FROM fishers f
CROSS JOIN fish_species s
CROSS JOIN GENERATE_SERIES(1, 8);

-- Create some quota violations (make a few fishers exceed quota)
UPDATE catches SET catch_weight_kg = catch_weight_kg * 2.5
WHERE fisher_id IN (1, 5, 12)
  AND catch_date >= DATE_TRUNC('month', CURRENT_DATE);

SELECT 'Sample data loaded' AS status;
SELECT 'Fishers: ' || COUNT(*) FROM fishers;
SELECT 'Catches: ' || COUNT(*) FROM catches;
