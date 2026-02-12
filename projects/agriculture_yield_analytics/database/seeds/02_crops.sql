-- ============================================================================
-- Seed Data: Crops Reference
-- Purpose: Crop master data with growing conditions
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- CROP CATEGORIES
-- ============================================================================

INSERT INTO agri.crop_categories (category_code, category_name, description)
VALUES
    ('CER', 'Cereals', 'Grain crops including maize, rice, wheat, sorghum'),
    ('LEG', 'Legumes', 'Nitrogen-fixing crops including beans, groundnuts, soybeans'),
    ('ROOT', 'Root & Tubers', 'Underground crops including cassava, sweet potatoes, irish potatoes'),
    ('FRUIT', 'Fruits', 'Fruit trees and vines including bananas, mangoes, citrus'),
    ('VEG', 'Vegetables', 'Leafy and non-leafy vegetables'),
    ('CASH', 'Cash Crops', 'Commercial export crops including coffee, tea, cotton'),
    ('OIL', 'Oilseeds', 'Oil-producing crops including sunflower, sesame'),
    ('SPICE', 'Spices', 'Aromatic crops including vanilla, ginger')
ON CONFLICT (category_code) DO NOTHING;

-- ============================================================================
-- CROPS
-- ============================================================================

INSERT INTO agri.crops (crop_code, crop_name, local_name, scientific_name, category_id, crop_type, 
                        growth_days_min, growth_days_max, optimal_rainfall_mm, optimal_temp_min_c, 
                        optimal_temp_max_c, expected_yield_low, expected_yield_high, price_per_kg,
                        is_cash_crop, is_food_crop, is_export_crop)
VALUES
    -- Cereals
    ('MAIZE', 'Maize', 'Kasooli', 'Zea mays', 1, 'cereals', 90, 150, 600, 18, 32, 1500, 8000, 800, FALSE, TRUE, FALSE),
    ('RICE', 'Rice', 'Muchele', 'Oryza sativa', 1, 'cereals', 120, 180, 1200, 21, 35, 2000, 7000, 2500, FALSE, TRUE, TRUE),
    ('SORGHUM', 'Sorghum', 'Omuwemba', 'Sorghum bicolor', 1, 'cereals', 90, 140, 500, 20, 35, 800, 4000, 600, FALSE, TRUE, FALSE),
    ('MILLET', 'Finger Millet', 'Obulo', 'Eleusine coracana', 1, 'cereals', 90, 130, 500, 18, 30, 600, 2500, 1200, FALSE, TRUE, FALSE),
    
    -- Legumes
    ('BEANS', 'Common Beans', 'Ebijanjaalo', 'Phaseolus vulgaris', 2, 'legumes', 60, 90, 500, 15, 25, 500, 2500, 2000, FALSE, TRUE, FALSE),
    ('GNUTS', 'Groundnuts', 'Ebinyeebwa', 'Arachis hypogaea', 2, 'legumes', 90, 150, 600, 20, 30, 800, 3000, 3500, FALSE, TRUE, TRUE),
    ('SOYB', 'Soybeans', 'Soya', 'Glycine max', 2, 'legumes', 100, 140, 600, 20, 30, 1000, 3500, 2800, TRUE, TRUE, TRUE),
    ('COWPEA', 'Cowpeas', 'Eboo', 'Vigna unguiculata', 2, 'legumes', 70, 100, 400, 20, 35, 400, 2000, 1800, FALSE, TRUE, FALSE),
    
    -- Root & Tubers
    ('CASS', 'Cassava', 'Muwogo', 'Manihot esculenta', 3, 'root_tubers', 270, 365, 1000, 20, 30, 8000, 40000, 300, FALSE, TRUE, FALSE),
    ('SWPOT', 'Sweet Potato', 'Lumonde', 'Ipomoea batatas', 3, 'root_tubers', 90, 150, 800, 20, 30, 6000, 25000, 400, FALSE, TRUE, FALSE),
    ('IRISH', 'Irish Potato', 'Lumonde za Bazungu', 'Solanum tuberosum', 3, 'root_tubers', 90, 120, 1200, 15, 25, 10000, 35000, 800, FALSE, TRUE, FALSE),
    ('YAM', 'Yam', 'Balungu', 'Dioscorea spp.', 3, 'root_tubers', 180, 365, 1200, 20, 30, 5000, 20000, 600, FALSE, TRUE, FALSE),
    
    -- Fruits
    ('MATOOKE', 'Cooking Banana', 'Matooke', 'Musa acuminata', 4, 'fruits', 365, 540, 1200, 20, 30, 15000, 60000, 500, FALSE, TRUE, FALSE),
    ('MANGO', 'Mango', 'Emiyembe', 'Mangifera indica', 4, 'fruits', 365, 730, 800, 20, 35, 5000, 25000, 800, FALSE, TRUE, TRUE),
    ('PINEAP', 'Pineapple', 'Enanaasi', 'Ananas comosus', 4, 'fruits', 540, 730, 1200, 20, 30, 30000, 80000, 600, TRUE, TRUE, TRUE),
    ('ORANGE', 'Orange', 'Emuchungwa', 'Citrus sinensis', 4, 'fruits', 365, 730, 1000, 18, 30, 8000, 30000, 700, FALSE, TRUE, FALSE),
    
    -- Vegetables
    ('TOMATO', 'Tomato', 'Enyaanya', 'Solanum lycopersicum', 5, 'vegetables', 60, 90, 700, 18, 28, 15000, 60000, 1200, FALSE, TRUE, FALSE),
    ('ONION', 'Onion', 'Obutungulu', 'Allium cepa', 5, 'vegetables', 90, 150, 600, 15, 25, 12000, 40000, 1500, FALSE, TRUE, FALSE),
    ('CABBAGE', 'Cabbage', 'Imboga', 'Brassica oleracea', 5, 'vegetables', 60, 100, 700, 15, 22, 20000, 70000, 600, FALSE, TRUE, FALSE),
    
    -- Cash Crops
    ('COFFEE', 'Coffee (Arabica)', 'Emwanyi', 'Coffea arabica', 6, 'cash_crops', 730, 1095, 1500, 15, 24, 500, 2500, 8000, TRUE, FALSE, TRUE),
    ('ROBUST', 'Coffee (Robusta)', 'Emwanyi', 'Coffea canephora', 6, 'cash_crops', 730, 1095, 1200, 18, 30, 800, 3000, 6000, TRUE, FALSE, TRUE),
    ('TEA', 'Tea', 'Echai', 'Camellia sinensis', 6, 'cash_crops', 1095, 1825, 2000, 15, 25, 2000, 8000, 2000, TRUE, FALSE, TRUE),
    ('COTTON', 'Cotton', 'Epamba', 'Gossypium hirsutum', 6, 'cash_crops', 150, 200, 700, 20, 30, 500, 2000, 1800, TRUE, FALSE, TRUE),
    ('TOBACCO', 'Tobacco', 'Etaaba', 'Nicotiana tabacum', 6, 'cash_crops', 90, 150, 900, 20, 30, 1500, 4000, 5000, TRUE, FALSE, TRUE),
    ('SUGAR', 'Sugarcane', 'Ekikajjo', 'Saccharum officinarum', 6, 'cash_crops', 365, 540, 1500, 20, 35, 50000, 120000, 150, TRUE, FALSE, FALSE),
    
    -- Oilseeds
    ('SUNFL', 'Sunflower', 'Enganda', 'Helianthus annuus', 7, 'oilseeds', 90, 120, 500, 18, 30, 800, 2500, 2200, TRUE, FALSE, FALSE),
    ('SESAME', 'Sesame', 'Esimsim', 'Sesamum indicum', 7, 'oilseeds', 90, 120, 500, 20, 35, 400, 1500, 4500, TRUE, FALSE, TRUE),
    
    -- Spices
    ('VANILLA', 'Vanilla', 'Vanilla', 'Vanilla planifolia', 8, 'spices', 730, 1095, 2000, 20, 30, 50, 500, 150000, TRUE, FALSE, TRUE),
    ('GINGER', 'Ginger', 'Entangawuzi', 'Zingiber officinale', 8, 'spices', 240, 300, 1500, 20, 30, 15000, 40000, 3000, TRUE, TRUE, TRUE)
ON CONFLICT (crop_code) DO UPDATE SET
    expected_yield_low = EXCLUDED.expected_yield_low,
    expected_yield_high = EXCLUDED.expected_yield_high,
    price_per_kg = EXCLUDED.price_per_kg;

COMMENT ON TABLE agri.crops IS 'Comprehensive crop reference with 30 major Uganda crops';
