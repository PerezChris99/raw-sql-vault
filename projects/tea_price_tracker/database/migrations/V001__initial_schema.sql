-- ============================================================================
-- Tea Farmer Price Tracker - Initial Schema
-- PostgreSQL 14+
-- ============================================================================

-- Tea grades
CREATE TABLE IF NOT EXISTS tea_grades (
    grade_id SERIAL PRIMARY KEY,
    grade_code VARCHAR(10) NOT NULL UNIQUE,
    grade_name VARCHAR(50) NOT NULL,
    description TEXT,
    base_price_ugx DECIMAL(10,2), -- Base reference price
    quality_rank INT -- 1 = highest quality
);

-- Districts
CREATE TABLE IF NOT EXISTS districts (
    district_id SERIAL PRIMARY KEY,
    district_name VARCHAR(100) NOT NULL UNIQUE,
    region VARCHAR(50)
);

-- Cooperatives
CREATE TABLE IF NOT EXISTS cooperatives (
    coop_id SERIAL PRIMARY KEY,
    coop_name VARCHAR(100) NOT NULL,
    district_id INT REFERENCES districts(district_id),
    registration_number VARCHAR(50),
    member_count INT
);

-- Farmers
CREATE TABLE IF NOT EXISTS farmers (
    farmer_id SERIAL PRIMARY KEY,
    farmer_name VARCHAR(100) NOT NULL,
    district_id INT REFERENCES districts(district_id),
    coop_id INT REFERENCES cooperatives(coop_id),
    acreage DECIMAL(6,2),
    registration_date DATE,
    phone VARCHAR(20),
    status VARCHAR(20) DEFAULT 'active'
);

-- Buyers
CREATE TABLE IF NOT EXISTS buyers (
    buyer_id SERIAL PRIMARY KEY,
    buyer_name VARCHAR(100) NOT NULL,
    buyer_type VARCHAR(30) CHECK (buyer_type IN ('factory', 'middleman', 'exporter', 'cooperative')),
    license_number VARCHAR(50),
    district_id INT REFERENCES districts(district_id),
    status VARCHAR(20) DEFAULT 'active'
);

-- Sales records
CREATE TABLE IF NOT EXISTS sales (
    sale_id SERIAL PRIMARY KEY,
    farmer_id INT NOT NULL REFERENCES farmers(farmer_id),
    buyer_id INT NOT NULL REFERENCES buyers(buyer_id),
    grade_id INT NOT NULL REFERENCES tea_grades(grade_id),
    quantity_kg DECIMAL(10,2) NOT NULL,
    price_per_kg DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(12,2) GENERATED ALWAYS AS (quantity_kg * price_per_kg) STORED,
    sale_date DATE NOT NULL,
    payment_status VARCHAR(20) DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX idx_sales_farmer ON sales(farmer_id);
CREATE INDEX idx_sales_grade ON sales(grade_id);
CREATE INDEX idx_sales_date ON sales(sale_date);
CREATE INDEX idx_sales_buyer ON sales(buyer_id);

-- ============================================================================
-- View: Price Percentiles (User's Sample Query)
-- PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) OVER (PARTITION BY grade)
-- ============================================================================

CREATE OR REPLACE VIEW vw_price_percentiles AS
SELECT DISTINCT
    g.grade_code,
    g.grade_name,
    -- User's sample: PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) OVER (PARTITION BY grade)
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.price_per_kg) AS median_price,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY s.price_per_kg) AS p25_price,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY s.price_per_kg) AS p75_price,
    MIN(s.price_per_kg) AS min_price,
    MAX(s.price_per_kg) AS max_price,
    AVG(s.price_per_kg)::DECIMAL(10,2) AS avg_price,
    COUNT(*) AS sale_count
FROM tea_grades g
LEFT JOIN sales s ON g.grade_id = s.grade_id
  AND s.sale_date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY g.grade_id, g.grade_code, g.grade_name
ORDER BY g.quality_rank;

COMMENT ON VIEW vw_price_percentiles IS 'User sample: PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price)';

-- ============================================================================
-- View: Sale Price Analysis (with Median Comparison)
-- ============================================================================

CREATE OR REPLACE VIEW vw_sale_analysis AS
WITH grade_medians AS (
    SELECT 
        grade_id,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_per_kg) AS median_price
    FROM sales
    WHERE sale_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY grade_id
)
SELECT 
    s.sale_id,
    f.farmer_name,
    b.buyer_name,
    b.buyer_type,
    g.grade_code,
    s.quantity_kg,
    s.price_per_kg,
    gm.median_price,
    ROUND((s.price_per_kg - gm.median_price), 2) AS price_vs_median,
    ROUND((s.price_per_kg / gm.median_price - 1) * 100, 1) AS pct_vs_median,
    CASE 
        WHEN s.price_per_kg < gm.median_price * 0.85 THEN '🔴 Potential Exploitation'
        WHEN s.price_per_kg < gm.median_price * 0.95 THEN '🟠 Below Average'
        WHEN s.price_per_kg > gm.median_price * 1.05 THEN '🟢 Above Average'
        ELSE '🟡 Fair Price'
    END AS price_assessment,
    s.sale_date
FROM sales s
JOIN farmers f ON s.farmer_id = f.farmer_id
JOIN buyers b ON s.buyer_id = b.buyer_id
JOIN tea_grades g ON s.grade_id = g.grade_id
LEFT JOIN grade_medians gm ON s.grade_id = gm.grade_id
ORDER BY s.sale_date DESC;

-- ============================================================================
-- View: Buyer Price Analysis
-- ============================================================================

CREATE OR REPLACE VIEW vw_buyer_analysis AS
WITH buyer_stats AS (
    SELECT 
        b.buyer_id,
        b.buyer_name,
        b.buyer_type,
        s.grade_id,
        COUNT(*) AS purchase_count,
        AVG(s.price_per_kg) AS avg_price,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.price_per_kg) AS median_price,
        SUM(s.quantity_kg) AS total_kg
    FROM buyers b
    JOIN sales s ON b.buyer_id = s.buyer_id
    WHERE s.sale_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY b.buyer_id, b.buyer_name, b.buyer_type, s.grade_id
),
market_medians AS (
    SELECT 
        grade_id,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_per_kg) AS market_median
    FROM sales
    WHERE sale_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY grade_id
)
SELECT 
    bs.buyer_name,
    bs.buyer_type,
    g.grade_code,
    bs.purchase_count,
    ROUND(bs.avg_price, 0) AS avg_price_ugx,
    ROUND(mm.market_median, 0) AS market_median_ugx,
    ROUND((bs.avg_price / mm.market_median - 1) * 100, 1) AS pct_vs_market,
    CASE 
        WHEN bs.avg_price < mm.market_median * 0.90 THEN '🔴 Low Payer'
        WHEN bs.avg_price < mm.market_median * 0.98 THEN '🟠 Below Average'
        ELSE '🟢 Fair Payer'
    END AS buyer_rating
FROM buyer_stats bs
JOIN tea_grades g ON bs.grade_id = g.grade_id
LEFT JOIN market_medians mm ON bs.grade_id = mm.grade_id
ORDER BY pct_vs_market;

-- ============================================================================
-- Function: Get Price Trend
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_price_trend(p_grade_id INT, p_days INT DEFAULT 30)
RETURNS TABLE (
    sale_date DATE,
    daily_median DECIMAL,
    prev_day_median DECIMAL,
    pct_change DECIMAL
) AS $$
WITH daily_prices AS (
    SELECT 
        sale_date,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_per_kg) AS daily_median
    FROM sales
    WHERE grade_id = p_grade_id
      AND sale_date >= CURRENT_DATE - (p_days || ' days')::INTERVAL
    GROUP BY sale_date
)
SELECT 
    sale_date,
    ROUND(daily_median, 0)::DECIMAL,
    ROUND(LAG(daily_median) OVER (ORDER BY sale_date), 0)::DECIMAL,
    ROUND((daily_median / LAG(daily_median) OVER (ORDER BY sale_date) - 1) * 100, 1)::DECIMAL
FROM daily_prices
ORDER BY sale_date;
$$ LANGUAGE SQL;
