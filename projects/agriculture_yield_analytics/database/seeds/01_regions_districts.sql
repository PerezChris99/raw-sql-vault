-- ============================================================================
-- Seed Data: Regions and Districts
-- Purpose: Uganda geographic reference data
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- REGIONS (4 Main Regions of Uganda)
-- ============================================================================

INSERT INTO agri.regions (region_code, region_name, area_sq_km, arable_land_pct, climate_zone, avg_annual_rainfall_mm)
VALUES
    ('CENTRAL', 'Central', 61403, 75.5, 'Tropical wet', 1250),
    ('EASTERN', 'Eastern', 39479, 70.2, 'Tropical wet-dry', 1100),
    ('NORTHERN', 'Northern', 85392, 55.8, 'Tropical savanna', 900),
    ('WESTERN', 'Western', 55277, 68.5, 'Tropical highland', 1400)
ON CONFLICT (region_code) DO UPDATE SET
    area_sq_km = EXCLUDED.area_sq_km,
    arable_land_pct = EXCLUDED.arable_land_pct;

-- ============================================================================
-- DISTRICTS (Sample of key agricultural districts)
-- ============================================================================

INSERT INTO agri.districts (district_code, district_name, region_id, headquarters, area_sq_km, population, farming_households, latitude, longitude, elevation_m, soil_type)
VALUES
    -- Central Region
    ('KLA001', 'Kampala', 1, 'Kampala City', 189, 1680600, 25000, 0.3136, 32.5811, 1190, 'Urban'),
    ('MUK001', 'Mukono', 1, 'Mukono Town', 2986, 596804, 85000, 0.3530, 32.7550, 1150, 'Loamy'),
    ('WAK001', 'Wakiso', 1, 'Wakiso Town', 2704, 1997418, 120000, 0.4044, 32.4594, 1200, 'Clay loam'),
    ('MPG001', 'Mpigi', 1, 'Mpigi Town', 1105, 250548, 45000, 0.2250, 32.3167, 1180, 'Clay'),
    ('LUW001', 'Luwero', 1, 'Luwero Town', 2578, 473820, 75000, 0.8333, 32.4667, 1100, 'Sandy loam'),
    
    -- Eastern Region
    ('JIN001', 'Jinja', 2, 'Jinja City', 767, 471242, 55000, 0.4244, 33.2041, 1140, 'Loamy'),
    ('MBA001', 'Mbale', 2, 'Mbale City', 522, 488960, 65000, 1.0667, 34.1833, 1220, 'Volcanic'),
    ('TOR001', 'Tororo', 2, 'Tororo Town', 1208, 517082, 78000, 0.6833, 34.1833, 1170, 'Loamy clay'),
    ('SOR001', 'Soroti', 2, 'Soroti Town', 2662, 296833, 52000, 1.7167, 33.6167, 1085, 'Sandy'),
    ('BUS001', 'Busia', 2, 'Busia Town', 730, 323662, 48000, 0.4667, 34.0833, 1130, 'Clay loam'),
    
    -- Northern Region
    ('GUL001', 'Gulu', 3, 'Gulu City', 3449, 275613, 42000, 2.7747, 32.2986, 1100, 'Sandy loam'),
    ('LIR001', 'Lira', 3, 'Lira City', 1329, 410516, 62000, 2.2500, 32.5333, 1090, 'Loamy'),
    ('APA001', 'Apac', 3, 'Apac Town', 3152, 368626, 55000, 1.9833, 32.5333, 1070, 'Sandy'),
    ('KIT001', 'Kitgum', 3, 'Kitgum Town', 4042, 204012, 32000, 3.2833, 32.8833, 950, 'Sandy clay'),
    ('ARU001', 'Arua', 3, 'Arua City', 769, 820492, 95000, 3.0211, 30.9111, 1200, 'Loamy'),
    
    -- Western Region
    ('MBR001', 'Mbarara', 4, 'Mbarara City', 1788, 470996, 72000, -0.6072, 30.6545, 1420, 'Volcanic'),
    ('KBL001', 'Kabale', 4, 'Kabale Town', 1827, 533809, 85000, -1.2500, 29.9833, 1870, 'Volcanic'),
    ('FPT001', 'Fort Portal', 4, 'Fort Portal City', 194, 54275, 8000, 0.6710, 30.2750, 1540, 'Volcanic'),
    ('MAS001', 'Masindi', 4, 'Masindi Town', 2123, 294573, 45000, 1.6833, 31.7167, 1140, 'Sandy loam'),
    ('KAS001', 'Kasese', 4, 'Kasese Town', 2724, 702029, 110000, 0.1833, 30.0833, 1000, 'Alluvial')
ON CONFLICT (district_code) DO UPDATE SET
    population = EXCLUDED.population,
    farming_households = EXCLUDED.farming_households;

COMMENT ON TABLE agri.districts IS 'Key agricultural districts with farming statistics';
