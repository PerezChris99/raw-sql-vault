-- ============================================================================
-- Seed: 05_health_facilities.sql
-- Purpose: Healthcare facility network
-- ============================================================================

SET search_path TO surveillance, public;

-- National Referral Hospitals
INSERT INTO surveillance.health_facilities 
    (district_id, facility_code, facility_name, facility_type, has_lab, bed_capacity, latitude, longitude)
SELECT d.district_id, f.code, f.name, f.ftype::surveillance.facility_type, f.lab, f.beds, f.lat, f.lng
FROM surveillance.districts d,
(VALUES
    ('KMP', 'MUL-NRH', 'Mulago National Referral Hospital', 'national_referral', TRUE, 1500, 0.3406, 32.5772),
    ('KMP', 'BUT-NRH', 'Butabika National Referral Hospital', 'national_referral', TRUE, 500, 0.3167, 32.6500),
    ('MBR', 'MBR-RRH', 'Mbarara Regional Referral Hospital', 'regional_referral', TRUE, 350, -0.6107, 30.6545),
    ('GUL', 'GUL-RRH', 'Gulu Regional Referral Hospital', 'regional_referral', TRUE, 300, 2.7775, 32.3050),
    ('MBL', 'MBL-RRH', 'Mbale Regional Referral Hospital', 'regional_referral', TRUE, 332, 1.0700, 34.1797),
    ('JNJ', 'JNJ-RRH', 'Jinja Regional Referral Hospital', 'regional_referral', TRUE, 350, 0.4167, 33.2167),
    ('FRP', 'FRP-RRH', 'Fort Portal Regional Referral Hospital', 'regional_referral', TRUE, 280, 0.6617, 30.2750),
    ('LIR', 'LIR-RRH', 'Lira Regional Referral Hospital', 'regional_referral', TRUE, 250, 2.2467, 32.5517),
    ('ARU', 'ARU-RRH', 'Arua Regional Referral Hospital', 'regional_referral', TRUE, 280, 3.0300, 30.9117),
    ('KBL', 'KBL-RRH', 'Kabale Regional Referral Hospital', 'regional_referral', TRUE, 220, -1.2497, 29.9867)
) AS f(dist_code, code, name, ftype, lab, beds, lat, lng)
WHERE d.district_code = f.dist_code
ON CONFLICT (facility_code) DO UPDATE SET
    facility_name = EXCLUDED.facility_name,
    bed_capacity = EXCLUDED.bed_capacity;

-- District Hospitals
INSERT INTO surveillance.health_facilities 
    (district_id, facility_code, facility_name, facility_type, has_lab, bed_capacity)
SELECT d.district_id, f.code, f.name, f.ftype::surveillance.facility_type, f.lab, f.beds
FROM surveillance.districts d,
(VALUES
    ('WKS', 'WKS-DH', 'Wakiso District Hospital', 'district_hospital', TRUE, 150),
    ('MKN', 'MKN-DH', 'Mukono District Hospital', 'district_hospital', TRUE, 120),
    ('LWR', 'LWR-DH', 'Luwero District Hospital', 'district_hospital', TRUE, 100),
    ('MSK', 'MSK-DH', 'Masaka Regional Referral Hospital', 'regional_referral', TRUE, 200),
    ('TRR', 'TRR-DH', 'Tororo District Hospital', 'district_hospital', TRUE, 120),
    ('SRT', 'SRT-DH', 'Soroti District Hospital', 'district_hospital', TRUE, 100),
    ('HIM', 'HIM-DH', 'Hoima Regional Referral Hospital', 'regional_referral', TRUE, 200),
    ('KSS', 'KSS-DH', 'Kasese District Hospital', 'district_hospital', TRUE, 120),
    ('KTD', 'KTD-DH', 'Kitgum District Hospital', 'district_hospital', TRUE, 100)
) AS f(dist_code, code, name, ftype, lab, beds)
WHERE d.district_code = f.dist_code
ON CONFLICT (facility_code) DO UPDATE SET
    facility_name = EXCLUDED.facility_name;

-- National Laboratories
INSERT INTO surveillance.health_facilities 
    (district_id, facility_code, facility_name, facility_type, has_lab)
SELECT d.district_id, f.code, f.name, 'laboratory'::surveillance.facility_type, TRUE
FROM surveillance.districts d,
(VALUES
    ('KMP', 'UVRI-LAB', 'Uganda Virus Research Institute'),
    ('KMP', 'CPHL-LAB', 'Central Public Health Laboratory'),
    ('KMP', 'NRLAB-LAB', 'National Reference Laboratory')
) AS f(dist_code, code, name)
WHERE d.district_code = f.dist_code
ON CONFLICT (facility_code) DO UPDATE SET
    facility_name = EXCLUDED.facility_name;
