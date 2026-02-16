-- ============================================================================
-- Tea Farmer Price Tracker - Sample Data
-- PostgreSQL 14+
-- ============================================================================

-- Tea grades (Uganda tea grading)
INSERT INTO tea_grades (grade_code, grade_name, description, base_price_ugx, quality_rank) VALUES
('BP1', 'Broken Pekoe 1', 'Highest quality broken leaf', 4500, 1),
('PF1', 'Pekoe Fannings 1', 'High quality fannings', 4000, 2),
('PD', 'Pekoe Dust', 'Medium quality dust', 3500, 3),
('D1', 'Dust 1', 'Standard dust grade', 3000, 4),
('BMF', 'Broken Mixed Fannings', 'Mixed grade fannings', 2500, 5)
ON CONFLICT (grade_code) DO NOTHING;

-- Districts (tea-growing regions)
INSERT INTO districts (district_name, region) VALUES
('Kabarole', 'Western'),
('Bushenyi', 'Western'),
('Kanungu', 'Western'),
('Rukungiri', 'Western'),
('Kyenjojo', 'Western'),
('Bundibugyo', 'Western')
ON CONFLICT (district_name) DO NOTHING;

-- Cooperatives
INSERT INTO cooperatives (coop_name, district_id, member_count)
SELECT 
    d.district_name || ' Tea Cooperative',
    d.district_id,
    (RANDOM() * 500 + 100)::INT
FROM districts d;

-- Farmers
INSERT INTO farmers (farmer_name, district_id, coop_id, acreage, registration_date)
SELECT 
    'Farmer ' || seq,
    (seq % 6) + 1,
    (seq % 6) + 1,
    (RANDOM() * 5 + 0.5)::DECIMAL(4,2),
    CURRENT_DATE - (RANDOM() * 1000)::INT
FROM GENERATE_SERIES(1, 50) AS seq;

-- Buyers
INSERT INTO buyers (buyer_name, buyer_type, district_id) VALUES
('Uganda Tea Factory', 'factory', 1),
('McLeod Russell', 'factory', 2),
('Rwenzori Tea Exporters', 'exporter', 1),
('Kabarole Tea Traders', 'middleman', 1),
('Bushenyi Leaf Buyers', 'middleman', 2),
('Western Coop Union', 'cooperative', 3),
('Safari Tea Agents', 'middleman', 4),
('Ankole Tea Buyers', 'middleman', 5)
ON CONFLICT DO NOTHING;

-- Sales (simulate 90 days of transactions with price variations)
INSERT INTO sales (farmer_id, buyer_id, grade_id, quantity_kg, price_per_kg, sale_date)
SELECT 
    (RANDOM() * 49 + 1)::INT AS farmer_id,
    (RANDOM() * 7 + 1)::INT AS buyer_id,
    g.grade_id,
    (RANDOM() * 100 + 10)::DECIMAL(8,2) AS quantity_kg,
    -- Price with variation (middlemen pay less)
    (g.base_price_ugx * (
        CASE WHEN (RANDOM() * 7 + 1)::INT IN (4, 5, 7, 8) -- middlemen
             THEN (RANDOM() * 0.15 + 0.80) -- 80-95% of base
             ELSE (RANDOM() * 0.15 + 0.95) -- 95-110% of base
        END
    ))::DECIMAL(10,2) AS price_per_kg,
    CURRENT_DATE - (RANDOM() * 90)::INT AS sale_date
FROM tea_grades g
CROSS JOIN GENERATE_SERIES(1, 40);

SELECT 'Sample data loaded' AS status;
SELECT 'Tea grades: ' || COUNT(*) FROM tea_grades;
SELECT 'Farmers: ' || COUNT(*) FROM farmers;
SELECT 'Sales: ' || COUNT(*) FROM sales;
