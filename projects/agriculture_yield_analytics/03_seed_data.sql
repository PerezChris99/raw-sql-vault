-- ============================================================================
-- 🌾 AGRICULTURE YIELD ANALYTICS - SEED DATA
-- ============================================================================
-- File: 03_seed_data.sql
-- Purpose: Reference data for Uganda regions, districts, crops, and sample data
-- Database: PostgreSQL 14+
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- REGIONS OF UGANDA
-- ============================================================================

INSERT INTO agri.regions (region_code, region_name, area_sq_km, arable_land_pct, climate_zone, avg_annual_rainfall_mm)
VALUES
    ('CENTRAL', 'Central Region', 61403.00, 65.00, 'Tropical Wet', 1320.00),
    ('EASTERN', 'Eastern Region', 39478.80, 70.00, 'Tropical Wet-Dry', 1200.00),
    ('NORTHERN', 'Northern Region', 85391.70, 55.00, 'Semi-Arid', 950.00),
    ('WESTERN', 'Western Region', 55276.50, 68.00, 'Tropical Highland', 1400.00)
ON CONFLICT (region_code) DO NOTHING;

-- ============================================================================
-- DISTRICTS OF UGANDA (All 146 districts organized by region)
-- ============================================================================

-- Central Region Districts
INSERT INTO agri.districts (district_code, district_name, region_id, area_sq_km, population, farming_households, major_crops, latitude, longitude)
SELECT d.district_code, d.district_name, r.region_id, d.area_sq_km, d.population, d.farming_households, d.major_crops, d.latitude, d.longitude
FROM (VALUES
    ('KLA', 'Kampala', 189, 1507080, 25000, ARRAY['vegetables', 'fruits'], 0.3476, 32.5825),
    ('WAK', 'Wakiso', 2807, 1997418, 185000, ARRAY['coffee', 'bananas', 'vegetables'], 0.4044, 32.4594),
    ('MUK', 'Mukono', 2986, 596804, 95000, ARRAY['coffee', 'cocoa', 'bananas'], 0.3533, 32.7553),
    ('MPG', 'Mpigi', 1104, 250548, 55000, ARRAY['coffee', 'bananas', 'beans'], 0.2250, 32.3167),
    ('LUW', 'Luwero', 2577, 456958, 72000, ARRAY['coffee', 'beans', 'maize'], 0.8492, 32.4731),
    ('MBR', 'Mubende', 4680, 684337, 98000, ARRAY['coffee', 'beans', 'bananas'], 0.5556, 31.3942),
    ('MIT', 'Mityana', 1592, 328964, 58000, ARRAY['coffee', 'bananas', 'maize'], 0.4175, 32.0556),
    ('NAK', 'Nakaseke', 3472, 197369, 48000, ARRAY['coffee', 'beans', 'maize'], 0.9500, 32.1833),
    ('NAO', 'Nakasongola', 3424, 181799, 42000, ARRAY['cattle', 'maize', 'beans'], 1.3089, 32.4564),
    ('KYK', 'Kayunga', 1695, 368063, 62000, ARRAY['coffee', 'maize', 'beans'], 0.7025, 32.8886),
    ('BUK', 'Buikwe', 1244, 422771, 75000, ARRAY['coffee', 'sugarcane', 'bananas'], 0.3333, 33.0333),
    ('BVU', 'Buvuma', 291, 89890, 18000, ARRAY['cassava', 'sweet_potatoes', 'fishing'], -0.3667, 33.2500),
    ('KLG', 'Kalangala', 9066, 54293, 12000, ARRAY['fishing', 'palm_oil', 'cloves'], -0.3167, 32.2333),
    ('MSD', 'Masaka', 1175, 297004, 52000, ARRAY['coffee', 'bananas', 'beans'], -0.3333, 31.7333),
    ('RAK', 'Rakai', 4989, 516309, 85000, ARRAY['coffee', 'bananas', 'beans'], -0.7000, 31.4167),
    ('LYT', 'Lyantonde', 878, 92986, 22000, ARRAY['coffee', 'bananas', 'cattle'], -0.4000, 31.1500),
    ('LWG', 'Lwengo', 537, 274953, 48000, ARRAY['coffee', 'bananas', 'beans'], -0.4167, 31.4167),
    ('KLN', 'Kalungu', 742, 183322, 38000, ARRAY['coffee', 'bananas', 'beans'], -0.1833, 31.7500),
    ('BUK2', 'Bukomansimbi', 684, 151413, 32000, ARRAY['coffee', 'bananas', 'beans'], -0.1500, 31.6167),
    ('SEM', 'Sembabule', 2325, 252597, 48000, ARRAY['cattle', 'bananas', 'beans'], -0.0833, 31.4500),
    ('GOM', 'Gomba', 1301, 160075, 35000, ARRAY['coffee', 'bananas', 'maize'], 0.2167, 31.7000),
    ('BUT', 'Butambala', 400, 100840, 22000, ARRAY['coffee', 'bananas', 'rice'], 0.1500, 32.1000),
    ('KAS', 'Kassanda', 1199, 298417, 55000, ARRAY['coffee', 'beans', 'maize'], 0.6000, 31.8000),
    ('KYO', 'Kyotera', 1245, 283680, 52000, ARRAY['coffee', 'bananas', 'beans'], -0.6333, 31.5167)
) AS d(district_code, district_name, area_sq_km, population, farming_households, major_crops, latitude, longitude)
CROSS JOIN agri.regions r WHERE r.region_code = 'CENTRAL'
ON CONFLICT (district_code) DO NOTHING;

-- Eastern Region Districts
INSERT INTO agri.districts (district_code, district_name, region_id, area_sq_km, population, farming_households, major_crops, latitude, longitude)
SELECT d.district_code, d.district_name, r.region_id, d.area_sq_km, d.population, d.farming_households, d.major_crops, d.latitude, d.longitude
FROM (VALUES
    ('JIN', 'Jinja', 750, 471242, 65000, ARRAY['sugarcane', 'rice', 'maize'], 0.4244, 33.2041),
    ('IGG', 'Iganga', 1700, 504197, 92000, ARRAY['maize', 'beans', 'rice'], 0.6092, 33.4686),
    ('MBL', 'Mbale', 518, 488960, 72000, ARRAY['coffee', 'wheat', 'bananas'], 1.0647, 34.1797),
    ('TOR', 'Tororo', 1192, 517082, 88000, ARRAY['rice', 'maize', 'groundnuts'], 0.6928, 34.1808),
    ('BUS', 'Busia', 743, 323662, 55000, ARRAY['cassava', 'maize', 'groundnuts'], 0.4608, 34.0919),
    ('SOR', 'Soroti', 2663, 296833, 58000, ARRAY['millet', 'groundnuts', 'sorghum'], 1.7147, 33.6114),
    ('KUM', 'Kumi', 1076, 239268, 48000, ARRAY['millet', 'groundnuts', 'cassava'], 1.4608, 33.9361),
    ('PAL', 'Pallisa', 1567, 386890, 72000, ARRAY['rice', 'maize', 'cassava'], 1.1450, 33.7097),
    ('BUD', 'Budaka', 418, 207573, 42000, ARRAY['rice', 'maize', 'beans'], 1.0167, 33.9333),
    ('BDU', 'Bududa', 274, 210173, 38000, ARRAY['coffee', 'bananas', 'beans'], 1.0167, 34.3333),
    ('MAN', 'Manafwa', 540, 353825, 62000, ARRAY['coffee', 'bananas', 'beans'], 1.0833, 34.3500),
    ('SRN', 'Sironko', 1055, 242422, 48000, ARRAY['coffee', 'bananas', 'potatoes'], 1.2333, 34.2500),
    ('BLE', 'Bulambuli', 423, 174508, 35000, ARRAY['wheat', 'barley', 'potatoes'], 1.3333, 34.3833),
    ('KPC', 'Kapchorwa', 1738, 105186, 22000, ARRAY['wheat', 'barley', 'maize'], 1.3975, 34.4506),
    ('BKW', 'Bukwo', 554, 92327, 18000, ARRAY['wheat', 'maize', 'beans'], 1.3000, 34.7333),
    ('KWN', 'Kween', 931, 96793, 20000, ARRAY['wheat', 'barley', 'potatoes'], 1.4167, 34.5500),
    ('BTL', 'Butaleja', 633, 224957, 45000, ARRAY['rice', 'maize', 'groundnuts'], 0.9167, 33.9500),
    ('NMT', 'Namutumba', 813, 252562, 52000, ARRAY['cassava', 'maize', 'beans'], 0.8333, 33.6833),
    ('NMY', 'Namayingo', 461, 215442, 42000, ARRAY['cassava', 'sweet_potatoes', 'fishing'], -0.2167, 33.8833),
    ('BGI', 'Bugiri', 1044, 383258, 72000, ARRAY['maize', 'rice', 'cassava'], 0.5667, 33.7500),
    ('MAY', 'Mayuge', 888, 473239, 85000, ARRAY['sugarcane', 'maize', 'cassava'], 0.4667, 33.4833),
    ('LUK', 'Luuka', 654, 238020, 48000, ARRAY['maize', 'beans', 'cassava'], 0.7333, 33.3000),
    ('BYN', 'Buyende', 1262, 323067, 62000, ARRAY['maize', 'cassava', 'beans'], 1.1500, 33.1667),
    ('KML', 'Kamuli', 1557, 486319, 88000, ARRAY['maize', 'rice', 'beans'], 0.9472, 33.1197),
    ('KAL', 'Kaliro', 924, 236199, 48000, ARRAY['maize', 'rice', 'beans'], 1.0833, 33.5000),
    ('AMR', 'Amuria', 1605, 272648, 55000, ARRAY['millet', 'sorghum', 'groundnuts'], 2.0333, 33.6500),
    ('KTK', 'Katakwi', 2459, 166231, 38000, ARRAY['millet', 'sorghum', 'sunflower'], 1.8917, 33.9694),
    ('BUK3', 'Bukedea', 679, 203600, 42000, ARRAY['millet', 'groundnuts', 'sunflower'], 1.3500, 34.0500),
    ('NGR', 'Ngora', 696, 140474, 32000, ARRAY['millet', 'groundnuts', 'cassava'], 1.4500, 33.7667),
    ('SRR', 'Serere', 1421, 275163, 55000, ARRAY['millet', 'groundnuts', 'sunflower'], 1.5000, 33.5500),
    ('KAB', 'Kaberamaido', 1327, 214374, 45000, ARRAY['millet', 'sorghum', 'cassava'], 1.7333, 33.1500),
    ('NBI', 'Nabiabi', 438, 180100, 38000, ARRAY['maize', 'rice', 'beans'], 0.8500, 34.0000),
    ('KIB', 'Kibuku', 312, 202033, 42000, ARRAY['maize', 'beans', 'millet'], 1.0500, 33.8167)
) AS d(district_code, district_name, area_sq_km, population, farming_households, major_crops, latitude, longitude)
CROSS JOIN agri.regions r WHERE r.region_code = 'EASTERN'
ON CONFLICT (district_code) DO NOTHING;

-- Northern Region Districts
INSERT INTO agri.districts (district_code, district_name, region_id, area_sq_km, population, farming_households, major_crops, latitude, longitude)
SELECT d.district_code, d.district_name, r.region_id, d.area_sq_km, d.population, d.farming_households, d.major_crops, d.latitude, d.longitude
FROM (VALUES
    ('GUL', 'Gulu', 3449, 275613, 55000, ARRAY['cotton', 'sunflower', 'sesame'], 2.7747, 32.2986),
    ('LIR', 'Lira', 1592, 408043, 78000, ARRAY['sunflower', 'cotton', 'maize'], 2.2347, 32.8997),
    ('KIT', 'Kitgum', 4042, 204012, 42000, ARRAY['sesame', 'sorghum', 'millet'], 3.2783, 32.8869),
    ('PAD', 'Pader', 7136, 178004, 38000, ARRAY['sesame', 'sorghum', 'beans'], 2.9500, 33.2333),
    ('ARU', 'Arua', 769, 782077, 125000, ARRAY['tobacco', 'cassava', 'groundnuts'], 3.0200, 30.9108),
    ('MOY', 'Moyo', 1788, 139012, 28000, ARRAY['tobacco', 'cassava', 'sesame'], 3.6500, 31.7167),
    ('ADJ', 'Adjumani', 3128, 225251, 45000, ARRAY['tobacco', 'cassava', 'groundnuts'], 3.3833, 31.8000),
    ('KOB', 'Koboko', 782, 206495, 38000, ARRAY['tobacco', 'maize', 'cassava'], 3.4167, 30.9500),
    ('YUM', 'Yumbe', 2406, 484822, 92000, ARRAY['tobacco', 'cassava', 'groundnuts'], 3.4667, 31.2500),
    ('NEH', 'Nebbi', 1020, 233031, 48000, ARRAY['tobacco', 'cotton', 'sesame'], 2.4667, 31.0833),
    ('ZOM', 'Zombo', 897, 240093, 48000, ARRAY['tobacco', 'cotton', 'cassava'], 2.5167, 30.9167),
    ('APA', 'Apac', 3088, 368626, 72000, ARRAY['cotton', 'rice', 'sunflower'], 1.9833, 32.5333),
    ('OYA', 'Oyam', 2034, 383644, 75000, ARRAY['sunflower', 'cotton', 'beans'], 2.2333, 32.3833),
    ('KOL', 'Kole', 881, 239327, 48000, ARRAY['sunflower', 'beans', 'maize'], 2.4000, 32.8000),
    ('DOK', 'Dokolo', 866, 183093, 38000, ARRAY['rice', 'sunflower', 'cassava'], 1.9167, 33.1667),
    ('ALG', 'Alebtong', 1549, 227541, 45000, ARRAY['sunflower', 'cotton', 'millet'], 2.2500, 33.3167),
    ('OTU', 'Otuke', 1558, 105618, 22000, ARRAY['sunflower', 'cotton', 'millet'], 2.4833, 33.5000),
    ('AGL', 'Agago', 3502, 227792, 45000, ARRAY['sesame', 'sorghum', 'beans'], 2.8333, 33.3333),
    ('LAM', 'Lamwo', 5543, 134379, 28000, ARRAY['sesame', 'beans', 'sorghum'], 3.5167, 32.8000),
    ('AMU', 'Amuru', 5099, 186696, 38000, ARRAY['sesame', 'cotton', 'sunflower'], 2.8333, 31.8333),
    ('NWO', 'Nwoya', 4736, 133506, 28000, ARRAY['cotton', 'sesame', 'maize'], 2.6333, 31.9167),
    ('OMO', 'Omoro', 1173, 185100, 38000, ARRAY['cotton', 'sunflower', 'sesame'], 2.6667, 32.4833),
    ('KWN2', 'Kwania', 1523, 194600, 42000, ARRAY['rice', 'sunflower', 'cotton'], 1.7500, 32.7500),
    ('MAR', 'Maracha', 611, 186176, 38000, ARRAY['tobacco', 'cassava', 'groundnuts'], 3.2833, 30.9000),
    ('PAK', 'Pakwach', 1019, 149702, 32000, ARRAY['tobacco', 'cassava', 'cotton'], 2.4500, 31.5000),
    ('OBN', 'Obongi', 631, 52100, 12000, ARRAY['tobacco', 'cassava', 'sesame'], 3.4833, 31.6167),
    ('MDA', 'Madi-Okollo', 1392, 168300, 35000, ARRAY['tobacco', 'cotton', 'cassava'], 2.7833, 31.1500),
    ('TER', 'Terego', 1028, 228400, 45000, ARRAY['tobacco', 'cassava', 'maize'], 3.1000, 31.0500)
) AS d(district_code, district_name, area_sq_km, population, farming_households, major_crops, latitude, longitude)
CROSS JOIN agri.regions r WHERE r.region_code = 'NORTHERN'
ON CONFLICT (district_code) DO NOTHING;

-- Western Region Districts
INSERT INTO agri.districts (district_code, district_name, region_id, area_sq_km, population, farming_households, major_crops, latitude, longitude)
SELECT d.district_code, d.district_name, r.region_id, d.area_sq_km, d.population, d.farming_households, d.major_crops, d.latitude, d.longitude
FROM (VALUES
    ('MBA', 'Mbarara', 1846, 472629, 85000, ARRAY['cattle', 'bananas', 'beans'], -0.6072, 30.6545),
    ('KES', 'Kasese', 3389, 694992, 115000, ARRAY['cotton', 'maize', 'beans'], 0.1833, 30.0833),
    ('KBL', 'Kabale', 1681, 528231, 98000, ARRAY['irish_potatoes', 'sorghum', 'beans'], -1.2508, 29.9889),
    ('FPT', 'Fort Portal', 246, 493758, 78000, ARRAY['tea', 'coffee', 'bananas'], 0.6710, 30.2747),
    ('BUN', 'Bundibugyo', 868, 224387, 42000, ARRAY['cocoa', 'coffee', 'vanilla'], 0.7167, 30.0667),
    ('KSG', 'Kisoro', 729, 281705, 52000, ARRAY['irish_potatoes', 'sorghum', 'beans'], -1.2833, 29.6833),
    ('RUK', 'Rukungiri', 1562, 314694, 62000, ARRAY['tea', 'coffee', 'bananas'], -0.7833, 29.9333),
    ('KAN', 'Kanungu', 1228, 252144, 48000, ARRAY['tea', 'bananas', 'beans'], -0.9500, 29.7833),
    ('BHM', 'Bushenyi', 942, 234440, 48000, ARRAY['tea', 'coffee', 'bananas'], -0.5333, 30.1833),
    ('NTU', 'Ntungamo', 2051, 483841, 92000, ARRAY['cattle', 'bananas', 'beans'], -0.8833, 30.2667),
    ('HOI', 'Hoima', 5733, 572986, 98000, ARRAY['tobacco', 'rice', 'maize'], 1.4333, 31.3500),
    ('MAS', 'Masindi', 4296, 291113, 58000, ARRAY['tobacco', 'maize', 'rice'], 1.6833, 31.7167),
    ('KIB2', 'Kibaale', 4071, 785088, 125000, ARRAY['maize', 'beans', 'rice'], 0.8000, 31.0667),
    ('KYJ', 'Kyenjojo', 2009, 422204, 78000, ARRAY['tea', 'coffee', 'bananas'], 0.6333, 30.6167),
    ('KAM', 'Kamwenge', 2466, 414454, 75000, ARRAY['tea', 'maize', 'beans'], 0.1833, 30.4500),
    ('IBD', 'Ibanda', 967, 249625, 48000, ARRAY['cattle', 'bananas', 'beans'], -0.1333, 30.4833),
    ('KRZ', 'Kiruhura', 4552, 328077, 62000, ARRAY['cattle', 'bananas', 'maize'], -0.1833, 30.8167),
    ('ISG', 'Isingiro', 2644, 486360, 88000, ARRAY['cattle', 'bananas', 'beans'], -0.7833, 30.8000),
    ('MIZ', 'Mitooma', 545, 183432, 38000, ARRAY['tea', 'bananas', 'beans'], -0.6167, 30.0167),
    ('BHG', 'Buhweju', 775, 120720, 25000, ARRAY['bananas', 'beans', 'coffee'], -0.4833, 30.2833),
    ('RUB', 'Rubirizi', 1020, 129149, 28000, ARRAY['tea', 'coffee', 'bananas'], -0.2833, 30.0833),
    ('SHM', 'Sheema', 698, 206794, 42000, ARRAY['tea', 'coffee', 'bananas'], -0.5500, 30.4000),
    ('KBU', 'Kabarole', 1825, 469236, 85000, ARRAY['tea', 'coffee', 'bananas'], 0.6000, 30.2500),
    ('KYG', 'Kyegegwa', 2324, 281637, 52000, ARRAY['maize', 'beans', 'cassava'], 0.4833, 31.0500),
    ('NTK', 'Ntoroko', 1318, 65767, 15000, ARRAY['fishing', 'maize', 'cassava'], 1.0333, 30.4667),
    ('BUL', 'Buliisa', 1630, 113161, 25000, ARRAY['fishing', 'maize', 'cassava'], 1.8833, 31.4000),
    ('KIR', 'Kiryandongo', 3624, 266197, 52000, ARRAY['maize', 'rice', 'sunflower'], 1.8833, 32.0667),
    ('KAK', 'Kakumiro', 1571, 296504, 55000, ARRAY['maize', 'beans', 'coffee'], 0.7833, 31.3833),
    ('KAG', 'Kagadi', 1987, 353300, 65000, ARRAY['maize', 'rice', 'beans'], 0.9333, 30.8000),
    ('RUH', 'Rubanda', 627, 198100, 42000, ARRAY['irish_potatoes', 'sorghum', 'beans'], -1.1833, 29.8333),
    ('RUK2', 'Rukiga', 447, 152500, 32000, ARRAY['irish_potatoes', 'sorghum', 'beans'], -1.1500, 30.0500)
) AS d(district_code, district_name, area_sq_km, population, farming_households, major_crops, latitude, longitude)
CROSS JOIN agri.regions r WHERE r.region_code = 'WESTERN'
ON CONFLICT (district_code) DO NOTHING;

-- ============================================================================
-- CROPS GROWN IN UGANDA
-- ============================================================================

INSERT INTO agri.crops (crop_code, crop_name, scientific_name, category, growth_period_days, optimal_rainfall_mm, optimal_temp_min, optimal_temp_max, is_export_crop, is_food_crop, avg_national_yield)
VALUES
    -- Cereals
    ('MAIZE', 'Maize', 'Zea mays', 'cereals', 120, 800, 18, 27, FALSE, TRUE, 2500),
    ('RICE', 'Rice (Paddy)', 'Oryza sativa', 'cereals', 150, 1200, 20, 35, FALSE, TRUE, 3000),
    ('SORGHUM', 'Sorghum', 'Sorghum bicolor', 'cereals', 120, 500, 25, 35, FALSE, TRUE, 1500),
    ('MILLET', 'Finger Millet', 'Eleusine coracana', 'cereals', 130, 600, 20, 30, FALSE, TRUE, 1200),
    ('WHEAT', 'Wheat', 'Triticum aestivum', 'cereals', 150, 600, 15, 25, FALSE, TRUE, 2000),
    ('BARLEY', 'Barley', 'Hordeum vulgare', 'cereals', 120, 500, 12, 25, FALSE, TRUE, 1800),
    
    -- Legumes
    ('BEANS', 'Common Beans', 'Phaseolus vulgaris', 'legumes', 90, 500, 18, 24, TRUE, TRUE, 800),
    ('GRNUTS', 'Groundnuts', 'Arachis hypogaea', 'legumes', 120, 600, 25, 30, TRUE, TRUE, 900),
    ('COWPEA', 'Cowpeas', 'Vigna unguiculata', 'legumes', 80, 450, 25, 35, FALSE, TRUE, 700),
    ('SOYBEAN', 'Soybeans', 'Glycine max', 'legumes', 110, 700, 20, 30, TRUE, TRUE, 1500),
    ('PIGEON', 'Pigeon Peas', 'Cajanus cajan', 'legumes', 180, 600, 20, 35, FALSE, TRUE, 800),
    
    -- Root & Tubers
    ('CASSAVA', 'Cassava', 'Manihot esculenta', 'root_tubers', 300, 1000, 25, 35, FALSE, TRUE, 12000),
    ('SWPOT', 'Sweet Potatoes', 'Ipomoea batatas', 'root_tubers', 120, 850, 20, 30, FALSE, TRUE, 8000),
    ('POTATO', 'Irish Potatoes', 'Solanum tuberosum', 'root_tubers', 120, 900, 15, 22, FALSE, TRUE, 10000),
    ('YAM', 'Yams', 'Dioscorea spp.', 'root_tubers', 240, 1200, 25, 35, FALSE, TRUE, 9000),
    
    -- Fruits
    ('BANANA', 'Cooking Bananas (Matooke)', 'Musa spp.', 'fruits', 365, 1200, 20, 30, FALSE, TRUE, 8000),
    ('MANGO', 'Mangoes', 'Mangifera indica', 'fruits', 365, 800, 24, 35, TRUE, TRUE, 6000),
    ('AVOCADO', 'Avocados', 'Persea americana', 'fruits', 365, 1000, 20, 28, TRUE, TRUE, 4000),
    ('PAWPAW', 'Pawpaw/Papaya', 'Carica papaya', 'fruits', 300, 1000, 22, 30, FALSE, TRUE, 15000),
    ('PINEAPL', 'Pineapples', 'Ananas comosus', 'fruits', 540, 1200, 22, 32, TRUE, TRUE, 45000),
    ('PASSION', 'Passion Fruits', 'Passiflora edulis', 'fruits', 365, 1200, 20, 30, TRUE, TRUE, 8000),
    
    -- Vegetables
    ('TOMATO', 'Tomatoes', 'Solanum lycopersicum', 'vegetables', 90, 600, 18, 27, FALSE, TRUE, 20000),
    ('ONION', 'Onions', 'Allium cepa', 'vegetables', 120, 500, 15, 25, FALSE, TRUE, 15000),
    ('CABBAGE', 'Cabbage', 'Brassica oleracea', 'vegetables', 90, 600, 15, 22, FALSE, TRUE, 25000),
    ('EGGPLNT', 'Eggplant', 'Solanum melongena', 'vegetables', 100, 600, 22, 32, FALSE, TRUE, 18000),
    ('PEPPER', 'Green Peppers', 'Capsicum annuum', 'vegetables', 90, 600, 18, 30, FALSE, TRUE, 12000),
    
    -- Cash Crops
    ('COFFEE', 'Arabica Coffee', 'Coffea arabica', 'cash_crops', 365, 1200, 15, 24, TRUE, FALSE, 2200),
    ('ROBUSTA', 'Robusta Coffee', 'Coffea canephora', 'cash_crops', 365, 1500, 22, 30, TRUE, FALSE, 2500),
    ('TEA', 'Tea', 'Camellia sinensis', 'cash_crops', 365, 1500, 18, 25, TRUE, FALSE, 1800),
    ('COTTON', 'Cotton', 'Gossypium hirsutum', 'cash_crops', 180, 700, 25, 35, TRUE, FALSE, 800),
    ('TOBACCO', 'Tobacco', 'Nicotiana tabacum', 'cash_crops', 120, 600, 20, 30, TRUE, FALSE, 1500),
    ('SUGAR', 'Sugarcane', 'Saccharum officinarum', 'cash_crops', 540, 1500, 25, 35, FALSE, TRUE, 65000),
    ('COCOA', 'Cocoa', 'Theobroma cacao', 'cash_crops', 365, 1800, 21, 32, TRUE, FALSE, 400),
    ('VANILLA', 'Vanilla', 'Vanilla planifolia', 'cash_crops', 365, 2000, 21, 32, TRUE, FALSE, 500),
    
    -- Oilseeds
    ('SUNFLWR', 'Sunflower', 'Helianthus annuus', 'oilseeds', 110, 500, 20, 30, TRUE, TRUE, 1200),
    ('SESAME', 'Sesame (Simsim)', 'Sesamum indicum', 'oilseeds', 100, 500, 25, 35, TRUE, FALSE, 600),
    ('PALMOIL', 'Oil Palm', 'Elaeis guineensis', 'oilseeds', 365, 1800, 24, 32, TRUE, TRUE, 18000),
    
    -- Spices
    ('GINGER', 'Ginger', 'Zingiber officinale', 'spices', 240, 1500, 20, 30, TRUE, TRUE, 8000),
    ('CHILLI', 'Chilli Peppers', 'Capsicum frutescens', 'spices', 120, 600, 20, 30, TRUE, TRUE, 5000),
    ('CLOVES', 'Cloves', 'Syzygium aromaticum', 'spices', 365, 1500, 20, 30, TRUE, FALSE, 400)
ON CONFLICT (crop_code) DO NOTHING;

-- ============================================================================
-- CROP VARIETIES
-- ============================================================================

INSERT INTO agri.crop_varieties (variety_code, variety_name, crop_id, is_hybrid, is_drought_resistant, is_disease_resistant, maturity_days, expected_yield, seed_source, year_released)
SELECT v.variety_code, v.variety_name, c.crop_id, v.is_hybrid, v.is_drought_resistant, v.is_disease_resistant, v.maturity_days, v.expected_yield, v.seed_source, v.year_released
FROM (VALUES
    -- Maize Varieties
    ('LONGE5', 'Longe 5', 'MAIZE', TRUE, TRUE, TRUE, 115, 4500, 'NARO', 2010),
    ('LONGE10H', 'Longe 10H', 'MAIZE', TRUE, FALSE, TRUE, 120, 5500, 'NARO', 2015),
    ('LONGE6H', 'Longe 6H', 'MAIZE', TRUE, TRUE, TRUE, 110, 5000, 'NARO', 2012),
    ('BAZOOKA', 'Bazooka', 'MAIZE', TRUE, FALSE, TRUE, 125, 6000, 'FICA Seeds', 2018),
    ('KH500-31A', 'Kenya Hybrid', 'MAIZE', TRUE, FALSE, FALSE, 130, 5500, 'Kenya Seed', 2008),
    
    -- Beans Varieties
    ('NABE15', 'NABE 15', 'BEANS', FALSE, TRUE, TRUE, 85, 1200, 'NARO', 2008),
    ('NABE16', 'NABE 16', 'BEANS', FALSE, FALSE, TRUE, 80, 1100, 'NARO', 2010),
    ('K132', 'K132 (Red)', 'BEANS', FALSE, TRUE, FALSE, 90, 1000, 'NARO', 2005),
    ('NABE4', 'NABE 4', 'BEANS', FALSE, FALSE, TRUE, 85, 1000, 'NARO', 2000),
    
    -- Rice Varieties
    ('NERICA4', 'NERICA 4', 'RICE', FALSE, TRUE, TRUE, 120, 4500, 'NARO/AfricaRice', 2008),
    ('NERICA1', 'NERICA 1', 'RICE', FALSE, TRUE, FALSE, 115, 4000, 'NARO/AfricaRice', 2008),
    ('WITA9', 'WITA 9', 'RICE', FALSE, FALSE, TRUE, 135, 5000, 'NARO', 2012),
    ('SUPERICA1', 'Superica 1', 'RICE', TRUE, TRUE, TRUE, 110, 5500, 'NARO', 2015),
    
    -- Cassava Varieties
    ('NASE14', 'NASE 14', 'CASSAVA', FALSE, TRUE, TRUE, 280, 35000, 'NARO', 2010),
    ('NASE19', 'NASE 19', 'CASSAVA', FALSE, TRUE, TRUE, 270, 40000, 'NARO', 2015),
    ('NAROCASS1', 'NAROCASS 1', 'CASSAVA', FALSE, TRUE, TRUE, 300, 38000, 'NARO', 2018),
    ('TME14', 'TME 14', 'CASSAVA', FALSE, FALSE, FALSE, 320, 28000, 'IITA', 2005),
    
    -- Coffee Varieties
    ('SL28', 'SL 28', 'COFFEE', FALSE, FALSE, FALSE, 365, 2500, 'UCDA', 1990),
    ('SL34', 'SL 34', 'COFFEE', FALSE, FALSE, FALSE, 365, 2400, 'UCDA', 1990),
    ('BUGISU', 'Bugisu AA', 'COFFEE', FALSE, FALSE, TRUE, 365, 2200, 'Local', 1980),
    ('KP423', 'KP 423', 'ROBUSTA', TRUE, TRUE, TRUE, 365, 3000, 'UCDA', 2010),
    
    -- Banana Varieties
    ('KIBUZI', 'Kibuzi', 'BANANA', FALSE, FALSE, FALSE, 365, 10000, 'Local', 1950),
    ('MBWAZIRUME', 'Mbwazirume', 'BANANA', FALSE, FALSE, TRUE, 365, 12000, 'Local', 1960),
    ('NAKITEMBE', 'Nakitembe', 'BANANA', FALSE, TRUE, FALSE, 365, 9000, 'Local', 1950),
    ('FHIA17', 'FHIA 17', 'BANANA', TRUE, TRUE, TRUE, 365, 15000, 'NARO', 2005),
    
    -- Groundnuts Varieties
    ('SERENUT5R', 'Serenut 5R', 'GRNUTS', FALSE, TRUE, TRUE, 110, 1500, 'NARO', 2010),
    ('SERENUT6T', 'Serenut 6T', 'GRNUTS', FALSE, TRUE, TRUE, 115, 1600, 'NARO', 2012),
    ('SERENUT14R', 'Serenut 14R', 'GRNUTS', FALSE, TRUE, TRUE, 105, 1800, 'NARO', 2018),
    
    -- Irish Potatoes
    ('VICTORIA', 'Victoria', 'POTATO', FALSE, FALSE, TRUE, 100, 25000, 'NARO', 2010),
    ('KINIGI', 'Kinigi', 'POTATO', FALSE, TRUE, TRUE, 110, 22000, 'NARO', 2008),
    ('RWANGUME', 'Rwangume', 'POTATO', TRUE, FALSE, TRUE, 95, 28000, 'NARO', 2015)
) AS v(variety_code, variety_name, crop_code, is_hybrid, is_drought_resistant, is_disease_resistant, maturity_days, expected_yield, seed_source, year_released)
JOIN agri.crops c ON c.crop_code = v.crop_code
ON CONFLICT (variety_code) DO NOTHING;

-- ============================================================================
-- SEASONS (Last 10 years + Current)
-- ============================================================================

INSERT INTO agri.seasons (season_code, season_name, season_type, year, start_date, end_date, planting_window_start, planting_window_end, expected_rainfall_mm)
SELECT
    year::TEXT || '_' || CASE season WHEN 1 THEN 'A' ELSE 'B' END AS season_code,
    CASE season 
        WHEN 1 THEN 'First Rains ' || year
        ELSE 'Second Rains ' || year
    END AS season_name,
    CASE season WHEN 1 THEN 'season_a'::agri.season_type ELSE 'season_b'::agri.season_type END,
    year,
    CASE season 
        WHEN 1 THEN (year || '-03-01')::DATE
        ELSE (year || '-09-01')::DATE
    END AS start_date,
    CASE season 
        WHEN 1 THEN (year || '-06-30')::DATE
        ELSE (year || '-12-31')::DATE
    END AS end_date,
    CASE season 
        WHEN 1 THEN (year || '-02-15')::DATE
        ELSE (year || '-08-15')::DATE
    END AS planting_window_start,
    CASE season 
        WHEN 1 THEN (year || '-04-15')::DATE
        ELSE (year || '-10-15')::DATE
    END AS planting_window_end,
    CASE season WHEN 1 THEN 450 ELSE 400 END AS expected_rainfall_mm
FROM generate_series(2016, 2026) AS year
CROSS JOIN generate_series(1, 2) AS season
ON CONFLICT (season_code) DO NOTHING;

-- Set current season
UPDATE agri.seasons SET is_current = FALSE;
UPDATE agri.seasons SET is_current = TRUE WHERE season_code = '2026_A';

-- ============================================================================
-- SAMPLE FARMERS (For testing)
-- ============================================================================

INSERT INTO agri.farmers (farmer_code, first_name, last_name, gender, date_of_birth, phone_primary, district_id, village, years_farming, cooperative_member)
SELECT 
    'FRM-' || LPAD(ROW_NUMBER() OVER()::TEXT, 6, '0'),
    names.first_name,
    names.last_name,
    names.gender,
    ('1960-01-01'::DATE + (RANDOM() * 14600)::INT)::DATE,  -- Born 1960-2000
    '07' || (70 + FLOOR(RANDOM() * 9)::INT)::TEXT || LPAD(FLOOR(RANDOM() * 10000000)::TEXT, 7, '0'),
    d.district_id,
    names.village,
    (5 + FLOOR(RANDOM() * 35))::INT,  -- 5-40 years farming
    RANDOM() > 0.6  -- 40% cooperative members
FROM (VALUES
    ('Okello', 'James', 'M', 'Acholi Quarters'),
    ('Nakato', 'Sarah', 'F', 'Kibuye'),
    ('Mugisha', 'Peter', 'M', 'Kisoro Town'),
    ('Achieng', 'Grace', 'F', 'Soroti Central'),
    ('Tumusiime', 'David', 'M', 'Mbarara North'),
    ('Nansubuga', 'Florence', 'F', 'Wakiso Central'),
    ('Opio', 'Samuel', 'M', 'Lira Town'),
    ('Nabirye', 'Mary', 'F', 'Mbale City'),
    ('Ssempijja', 'Robert', 'M', 'Masaka Central'),
    ('Kyomugisha', 'Agnes', 'F', 'Fort Portal'),
    ('Odong', 'Charles', 'M', 'Gulu Municipality'),
    ('Akello', 'Rose', 'F', 'Kitgum Town'),
    ('Byaruhanga', 'Francis', 'M', 'Hoima Central'),
    ('Kemigisha', 'Patricia', 'F', 'Kabale Town'),
    ('Ocen', 'Joseph', 'M', 'Arua Hill'),
    ('Adong', 'Betty', 'F', 'Pader Town'),
    ('Kato', 'Michael', 'M', 'Jinja Central'),
    ('Namubiru', 'Jennifer', 'F', 'Iganga Town'),
    ('Otim', 'Patrick', 'M', 'Apac Town'),
    ('Achola', 'Susan', 'F', 'Nebbi Central'),
    ('Wasswa', 'Emmanuel', 'M', 'Kayunga Town'),
    ('Nantongo', 'Christine', 'F', 'Mukono Central'),
    ('Mugabi', 'Henry', 'M', 'Ntungamo Town'),
    ('Nakabugo', 'Esther', 'F', 'Bushenyi Town'),
    ('Okwera', 'George', 'M', 'Oyam Central')
) AS names(last_name, first_name, gender, village)
CROSS JOIN LATERAL (
    SELECT district_id FROM agri.districts ORDER BY RANDOM() LIMIT 1
) d
ON CONFLICT (farmer_code) DO NOTHING;

-- ============================================================================
-- SAMPLE FARMS
-- ============================================================================

INSERT INTO agri.farms (farm_code, farm_name, farmer_id, district_id, village, total_area_hectares, cultivated_area_hectares, latitude, longitude, soil_type, irrigation_available)
SELECT 
    'FRM-' || LPAD(ROW_NUMBER() OVER()::TEXT, 6, '0') || '-F1',
    f.first_name || '''s Farm',
    f.farmer_id,
    f.district_id,
    f.village,
    (0.5 + RANDOM() * 9.5)::DECIMAL(10,2),  -- 0.5 to 10 hectares
    (0.4 + RANDOM() * 8)::DECIMAL(10,2),
    d.latitude + (RANDOM() - 0.5) * 0.1,
    d.longitude + (RANDOM() - 0.5) * 0.1,
    (ARRAY['clay', 'loam', 'sandy', 'silt', 'clay-loam', 'sandy-loam'])[FLOOR(1 + RANDOM() * 6)::INT],
    RANDOM() > 0.8  -- 20% have irrigation
FROM agri.farmers f
JOIN agri.districts d ON f.district_id = d.district_id
ON CONFLICT (farm_code) DO NOTHING;

-- ============================================================================
-- SAMPLE HARVESTS (Last 3 seasons)
-- ============================================================================

WITH season_data AS (
    SELECT season_id, year, season_type FROM agri.seasons 
    WHERE year >= 2024 ORDER BY year, season_type
),
farm_crop_combos AS (
    SELECT 
        f.farm_id,
        f.farmer_id,
        f.district_id,
        c.crop_id,
        f.cultivated_area_hectares,
        d.latitude,
        d.longitude
    FROM agri.farms f
    JOIN agri.districts d ON f.district_id = d.district_id
    CROSS JOIN LATERAL (
        SELECT crop_id FROM agri.crops WHERE is_active = TRUE ORDER BY RANDOM() LIMIT 2
    ) c
)
INSERT INTO agri.harvests (
    harvest_code, farmer_id, farm_id, crop_id, season_id, district_id,
    planting_date, harvest_date, area_harvested_hectares, total_yield_kg,
    quality_grade, seed_cost, fertilizer_cost, labor_cost, 
    quantity_sold_kg, sale_price_per_kg, total_revenue
)
SELECT
    NULL,  -- Will be auto-generated
    fc.farmer_id,
    fc.farm_id,
    fc.crop_id,
    s.season_id,
    fc.district_id,
    CASE s.season_type 
        WHEN 'season_a' THEN (s.year || '-03-' || (1 + FLOOR(RANDOM() * 28)::INT))::DATE
        ELSE (s.year || '-09-' || (1 + FLOOR(RANDOM() * 28)::INT))::DATE
    END AS planting_date,
    CASE s.season_type 
        WHEN 'season_a' THEN (s.year || '-06-' || (1 + FLOOR(RANDOM() * 28)::INT))::DATE
        ELSE (s.year || '-12-' || (1 + FLOOR(RANDOM() * 28)::INT))::DATE
    END AS harvest_date,
    (fc.cultivated_area_hectares * (0.3 + RANDOM() * 0.7))::DECIMAL(10,2) AS area,
    (c.avg_national_yield * (0.6 + RANDOM() * 0.8) * fc.cultivated_area_hectares * (0.3 + RANDOM() * 0.7))::DECIMAL(14,2) AS yield,
    (ARRAY['grade_a', 'grade_b', 'grade_c']::agri.quality_grade[])[FLOOR(1 + RANDOM() * 2.5)::INT],
    (50000 + RANDOM() * 150000)::DECIMAL(12,2),  -- Seed cost UGX
    (100000 + RANDOM() * 300000)::DECIMAL(12,2), -- Fertilizer cost UGX
    (200000 + RANDOM() * 500000)::DECIMAL(12,2), -- Labor cost UGX
    NULL, -- Will be calculated
    NULL, -- Will be set
    NULL  -- Will be calculated
FROM farm_crop_combos fc
CROSS JOIN season_data s
JOIN agri.crops c ON fc.crop_id = c.crop_id
WHERE RANDOM() > 0.3  -- 70% of combinations have harvests
ON CONFLICT (harvest_code) DO NOTHING;

-- Update sold quantities and revenue
UPDATE agri.harvests
SET 
    quantity_sold_kg = total_yield_kg * (0.5 + RANDOM() * 0.4),  -- 50-90% sold
    sale_price_per_kg = 
        CASE 
            WHEN quality_grade = 'grade_a' THEN (800 + RANDOM() * 400)::DECIMAL(10,2)
            WHEN quality_grade = 'grade_b' THEN (600 + RANDOM() * 300)::DECIMAL(10,2)
            ELSE (400 + RANDOM() * 200)::DECIMAL(10,2)
        END
WHERE quantity_sold_kg IS NULL;

UPDATE agri.harvests
SET total_revenue = quantity_sold_kg * sale_price_per_kg
WHERE total_revenue IS NULL;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    r_count INT; d_count INT; c_count INT; f_count INT; h_count INT;
BEGIN
    SELECT COUNT(*) INTO r_count FROM agri.regions;
    SELECT COUNT(*) INTO d_count FROM agri.districts;
    SELECT COUNT(*) INTO c_count FROM agri.crops;
    SELECT COUNT(*) INTO f_count FROM agri.farmers;
    SELECT COUNT(*) INTO h_count FROM agri.harvests;
    
    RAISE NOTICE '';
    RAISE NOTICE '=====================================';
    RAISE NOTICE 'SEED DATA LOADED SUCCESSFULLY';
    RAISE NOTICE '=====================================';
    RAISE NOTICE 'Regions:    %', r_count;
    RAISE NOTICE 'Districts:  %', d_count;
    RAISE NOTICE 'Crops:      %', c_count;
    RAISE NOTICE 'Farmers:    %', f_count;
    RAISE NOTICE 'Harvests:   %', h_count;
    RAISE NOTICE '=====================================';
END $$;
