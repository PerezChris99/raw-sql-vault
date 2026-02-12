-- ============================================================================
-- Seed: 02_districts.sql
-- Purpose: Administrative districts with coordinates
-- ============================================================================

SET search_path TO surveillance, public;

-- Central Region Districts
INSERT INTO surveillance.districts (region_id, district_code, district_name, population, latitude, longitude)
SELECT r.region_id, d.code, d.name, d.pop, d.lat, d.lng
FROM surveillance.regions r,
(VALUES
    ('CEN', 'KMP', 'Kampala', 1680000, 0.3476, 32.5825),
    ('CEN', 'WKS', 'Wakiso', 1997418, 0.4054, 32.4594),
    ('CEN', 'MKN', 'Mukono', 599817, 0.3533, 32.7554),
    ('CEN', 'LWR', 'Luwero', 458158, 0.8494, 32.4736),
    ('CEN', 'MPG', 'Mpigi', 250548, 0.2250, 32.3181),
    ('CEN', 'JNJ', 'Jinja', 471242, 0.4244, 33.2041),
    ('CEN', 'MSK', 'Masaka', 297004, -0.3136, 31.7350),
    ('CEN', 'MBR', 'Mubende', 684337, 0.5917, 31.3950),
    ('CEN', 'KYJ', 'Kayunga', 368063, 0.7028, 32.8889),
    ('CEN', 'NKS', 'Nakaseke', 197369, 0.9167, 32.3333)
) AS d(region, code, name, pop, lat, lng)
WHERE r.region_code = d.region
ON CONFLICT (district_code) DO UPDATE SET
    district_name = EXCLUDED.district_name,
    population = EXCLUDED.population,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude;

-- Eastern Region Districts
INSERT INTO surveillance.districts (region_id, district_code, district_name, population, latitude, longitude)
SELECT r.region_id, d.code, d.name, d.pop, d.lat, d.lng
FROM surveillance.regions r,
(VALUES
    ('EAS', 'MBL', 'Mbale', 489973, 1.0644, 34.1747),
    ('EAS', 'TRR', 'Tororo', 517082, 0.6928, 34.1808),
    ('EAS', 'BGS', 'Bugisu', 234567, 1.0833, 34.2667),
    ('EAS', 'SRT', 'Soroti', 296833, 1.7150, 33.6111),
    ('EAS', 'KMI', 'Kumi', 239268, 1.4608, 33.9361),
    ('EAS', 'BUS', 'Busia', 323662, 0.4544, 34.0922),
    ('EAS', 'IGG', 'Iganga', 504197, 0.6094, 33.4686),
    ('EAS', 'PAL', 'Pallisa', 386619, 1.1450, 33.7097),
    ('EAS', 'SRN', 'Serere', 276569, 1.5000, 33.5500),
    ('EAS', 'KPC', 'Kapchorwa', 105186, 1.3972, 34.4500)
) AS d(region, code, name, pop, lat, lng)
WHERE r.region_code = d.region
ON CONFLICT (district_code) DO UPDATE SET
    district_name = EXCLUDED.district_name,
    population = EXCLUDED.population;

-- Northern Region Districts
INSERT INTO surveillance.districts (region_id, district_code, district_name, population, latitude, longitude)
SELECT r.region_id, d.code, d.name, d.pop, d.lat, d.lng
FROM surveillance.regions r,
(VALUES
    ('NOR', 'GUL', 'Gulu', 443733, 2.7747, 32.2989),
    ('NOR', 'LIR', 'Lira', 408043, 2.2350, 32.5400),
    ('NOR', 'ARU', 'Arua', 782077, 3.0194, 30.9108),
    ('NOR', 'KTD', 'Kitgum', 204048, 3.2783, 32.8878),
    ('NOR', 'PAD', 'Pader', 178004, 2.8667, 33.0500),
    ('NOR', 'MOY', 'Moyo', 139012, 3.6564, 31.7203),
    ('NOR', 'APK', 'Apac', 368626, 1.9833, 32.5333),
    ('NOR', 'NEE', 'Nebbi', 237061, 2.4761, 31.0886),
    ('NOR', 'OYM', 'Oyam', 383644, 2.2333, 32.3833),
    ('NOR', 'KBG', 'Koboko', 206495, 3.4133, 30.9583)
) AS d(region, code, name, pop, lat, lng)
WHERE r.region_code = d.region
ON CONFLICT (district_code) DO UPDATE SET
    district_name = EXCLUDED.district_name,
    population = EXCLUDED.population;

-- Western Region Districts  
INSERT INTO surveillance.districts (region_id, district_code, district_name, population, latitude, longitude)
SELECT r.region_id, d.code, d.name, d.pop, d.lat, d.lng
FROM surveillance.regions r,
(VALUES
    ('WES', 'MBR', 'Mbarara', 472629, -0.6133, 30.6583),
    ('WES', 'FRP', 'Fort Portal', 310327, 0.6710, 30.2750),
    ('WES', 'KBL', 'Kabale', 528231, -1.2508, 29.9894),
    ('WES', 'BSH', 'Bushenyi', 234440, -0.5833, 30.1833),
    ('WES', 'HIM', 'Hoima', 572986, 1.4311, 31.3522),
    ('WES', 'KSS', 'Kasese', 694992, 0.1833, 30.0833),
    ('WES', 'KSR', 'Kisoro', 281705, -1.2833, 29.6833),
    ('WES', 'NTG', 'Ntungamo', 483841, -0.8833, 30.2667),
    ('WES', 'RKG', 'Rukungiri', 314694, -0.7833, 29.9333),
    ('WES', 'IBD', 'Ibanda', 249625, -0.1167, 30.5000)
) AS d(region, code, name, pop, lat, lng)
WHERE r.region_code = d.region
ON CONFLICT (district_code) DO UPDATE SET
    district_name = EXCLUDED.district_name,
    population = EXCLUDED.population;
