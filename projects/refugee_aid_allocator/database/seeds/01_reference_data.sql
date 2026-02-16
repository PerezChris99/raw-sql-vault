-- ============================================================================
-- Refugee Aid Allocator - Reference Data
-- PostgreSQL 14+
-- Seed: Reference tables for camps, categories, and urgency levels
-- ============================================================================

-- ============================================================================
-- Urgency Levels
-- ============================================================================

INSERT INTO urgency_levels (urgency_name, urgency_score, description, response_sla_hours) VALUES
('critical', 100, 'Life-threatening situation requiring immediate intervention', 4),
('high', 75, 'Severe hardship, urgent response needed within 24 hours', 24),
('medium', 50, 'Significant need requiring attention within 72 hours', 72),
('low', 25, 'Standard need, can be addressed in regular distribution cycle', 168)
ON CONFLICT (urgency_name) DO NOTHING;

-- ============================================================================
-- Aid Categories
-- ============================================================================

INSERT INTO aid_categories (category_name, category_code, unit_of_measure, priority_weight, description, is_recurring, recurrence_days) VALUES
('Food Rations', 'FOOD', 'kg', 1.00, 'Basic food supplies including cereals, legumes, oil', TRUE, 14),
('Clean Water', 'WATER', 'liters', 1.00, 'Potable water supply', TRUE, 1),
('Medical Supplies', 'MED', 'kit', 0.95, 'Basic medical kits and medicines', FALSE, NULL),
('Shelter Materials', 'SHLT', 'unit', 0.90, 'Tents, plastic sheeting, building materials', FALSE, NULL),
('Blankets', 'BLNK', 'piece', 0.80, 'Thermal blankets for cold protection', FALSE, NULL),
('Cooking Set', 'COOK', 'set', 0.75, 'Pots, pans, utensils', FALSE, NULL),
('Hygiene Kit', 'HYG', 'kit', 0.85, 'Soap, toothpaste, sanitary items', TRUE, 30),
('Clothing', 'CLTH', 'bundle', 0.70, 'Basic clothing items', FALSE, NULL),
('Baby Supplies', 'BABY', 'kit', 0.90, 'Diapers, formula, baby food', TRUE, 7),
('Education Materials', 'EDU', 'kit', 0.50, 'School supplies, books, stationery', FALSE, NULL),
('Mosquito Nets', 'MOSQ', 'piece', 0.80, 'Insecticide-treated bed nets', FALSE, NULL),
('Fuel/Firewood', 'FUEL', 'kg', 0.65, 'Cooking fuel or firewood', TRUE, 7)
ON CONFLICT (category_code) DO NOTHING;

-- ============================================================================
-- Refugee Camps (Uganda)
-- ============================================================================

INSERT INTO camps (camp_name, country, district, location_desc, latitude, longitude, capacity, current_population, established_date, status) VALUES
('Bidibidi', 'Uganda', 'Yumbe', 'Zone 1-5, Northern Uganda border region', 3.5547, 31.3922, 270000, 232000, '2016-08-01', 'active'),
('Palorinya', 'Uganda', 'Moyo', 'Near Adjumani district, West Nile', 3.5833, 31.7500, 120000, 95000, '2017-01-15', 'active'),
('Imvepi', 'Uganda', 'Arua', 'Ocea sub-county, Northern Uganda', 3.2167, 31.1833, 125000, 68000, '2017-02-01', 'active'),
('Rhino Camp', 'Uganda', 'Arua', 'Omugo and Tika zones', 3.0667, 31.3333, 100000, 89000, '1980-01-01', 'active'),
('Kyangwali', 'Uganda', 'Kikuube', 'Western Uganda, Lake Albert region', 1.2833, 30.8167, 80000, 72000, '1960-01-01', 'active'),
('Nakivale', 'Uganda', 'Isingiro', 'South-western Uganda, oldest settlement', -0.8583, 30.9167, 130000, 98000, '1958-01-01', 'active'),
('Oruchinga', 'Uganda', 'Isingiro', 'Near Nakivale, smaller settlement', -0.9000, 30.8500, 8000, 6800, '1961-01-01', 'active'),
('Rwamwanja', 'Uganda', 'Kamwenge', 'Western Uganda, Rift Valley', 0.1833, 30.4500, 75000, 65000, '2012-04-01', 'active'),
('Kyaka II', 'Uganda', 'Kyegegwa', 'Mid-western Uganda', 0.5000, 31.0000, 45000, 38000, '1983-01-01', 'active'),
('Lobule', 'Uganda', 'Koboko', 'Transit center, Northern border', 3.4167, 30.9500, 5000, 3200, '2017-06-01', 'temporary')
ON CONFLICT (camp_name) DO NOTHING;

-- ============================================================================
-- Aid Inventory (Initial Stock)
-- ============================================================================

INSERT INTO aid_inventory (camp_id, category_id, quantity_available, quantity_reserved, reorder_level, last_restock_date, last_restock_quantity) 
SELECT 
    c.camp_id,
    ac.category_id,
    CASE 
        WHEN ac.category_code = 'FOOD' THEN c.current_population * 0.5
        WHEN ac.category_code = 'WATER' THEN c.current_population * 20
        WHEN ac.category_code = 'MED' THEN c.current_population * 0.05
        WHEN ac.category_code = 'SHLT' THEN c.current_population * 0.01
        WHEN ac.category_code = 'BLNK' THEN c.current_population * 0.2
        WHEN ac.category_code = 'HYG' THEN c.current_population * 0.1
        ELSE c.current_population * 0.05
    END AS quantity_available,
    0 AS quantity_reserved,
    CASE 
        WHEN ac.category_code = 'FOOD' THEN c.current_population * 0.2
        WHEN ac.category_code = 'WATER' THEN c.current_population * 10
        ELSE c.current_population * 0.02
    END AS reorder_level,
    CURRENT_DATE - (RANDOM() * 30)::INT AS last_restock_date,
    CASE 
        WHEN ac.category_code = 'FOOD' THEN c.current_population * 0.3
        ELSE c.current_population * 0.05
    END AS last_restock_quantity
FROM camps c
CROSS JOIN aid_categories ac
WHERE c.status = 'active'
ON CONFLICT (camp_id, category_id) DO NOTHING;

-- ============================================================================
-- Update camp populations to match actual registered (for Bidibidi demo)
-- ============================================================================

UPDATE camps SET current_population = 232000 WHERE camp_name = 'Bidibidi';
UPDATE camps SET current_population = 95000 WHERE camp_name = 'Palorinya';
UPDATE camps SET current_population = 68000 WHERE camp_name = 'Imvepi';

SELECT 'Reference data loaded successfully' AS status;
SELECT COUNT(*) AS camp_count FROM camps;
SELECT COUNT(*) AS category_count FROM aid_categories;
SELECT COUNT(*) AS urgency_count FROM urgency_levels;
SELECT COUNT(*) AS inventory_count FROM aid_inventory;
