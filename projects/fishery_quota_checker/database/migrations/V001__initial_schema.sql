-- ============================================================================
-- Fishery Quota Compliance Checker - Initial Schema
-- PostgreSQL 14+
-- ============================================================================

-- Fish species with quota limits
CREATE TABLE IF NOT EXISTS fish_species (
    species_id SERIAL PRIMARY KEY,
    species_name VARCHAR(100) NOT NULL UNIQUE,
    local_name VARCHAR(100),
    min_size_cm DECIMAL(5,1),
    max_quota_per_month_kg DECIMAL(10,2),
    conservation_status VARCHAR(30) DEFAULT 'normal'
);

-- Landing sites
CREATE TABLE IF NOT EXISTS landing_sites (
    site_id SERIAL PRIMARY KEY,
    site_name VARCHAR(100) NOT NULL UNIQUE,
    lake VARCHAR(50) DEFAULT 'Lake Victoria',
    district VARCHAR(100),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8)
);

-- Registered fishers
CREATE TABLE IF NOT EXISTS fishers (
    fisher_id SERIAL PRIMARY KEY,
    license_number VARCHAR(30) UNIQUE,
    fisher_name VARCHAR(100) NOT NULL,
    boat_name VARCHAR(100),
    boat_registration VARCHAR(30),
    landing_site_id INT REFERENCES landing_sites(site_id),
    license_issue_date DATE,
    license_expiry_date DATE,
    phone VARCHAR(20),
    status VARCHAR(20) DEFAULT 'active'
);

-- Monthly quotas (can vary by season)
CREATE TABLE IF NOT EXISTS monthly_quotas (
    quota_id SERIAL PRIMARY KEY,
    species_id INT REFERENCES fish_species(species_id),
    year_month DATE NOT NULL, -- First of month
    quota_kg DECIMAL(10,2) NOT NULL,
    reason VARCHAR(200),
    UNIQUE(species_id, year_month)
);

-- Catch records
CREATE TABLE IF NOT EXISTS catches (
    catch_id SERIAL PRIMARY KEY,
    fisher_id INT NOT NULL REFERENCES fishers(fisher_id),
    species_id INT NOT NULL REFERENCES fish_species(species_id),
    catch_date DATE NOT NULL,
    catch_time TIME,
    catch_weight_kg DECIMAL(8,2) NOT NULL,
    fish_count INT,
    avg_size_cm DECIMAL(5,1),
    landing_site_id INT REFERENCES landing_sites(site_id),
    recorded_by VARCHAR(100),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Violations
CREATE TABLE IF NOT EXISTS violations (
    violation_id SERIAL PRIMARY KEY,
    fisher_id INT REFERENCES fishers(fisher_id),
    violation_date DATE NOT NULL,
    violation_type VARCHAR(50) NOT NULL,
    description TEXT,
    catch_id INT REFERENCES catches(catch_id),
    penalty_amount DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'open',
    resolved_date DATE
);

-- Indexes
CREATE INDEX idx_catches_fisher ON catches(fisher_id);
CREATE INDEX idx_catches_date ON catches(catch_date);
CREATE INDEX idx_catches_species ON catches(species_id);
CREATE INDEX idx_catches_fisher_date ON catches(fisher_id, catch_date);

-- ============================================================================
-- View: Rolling Quota Usage (User's Sample Query)
-- ============================================================================

CREATE OR REPLACE VIEW vw_rolling_quota AS
SELECT 
    fisher_id,
    species_id,
    catch_date,
    catch_weight_kg,
    DATE_TRUNC('month', catch_date) AS month,
    -- User's sample: SUM(catch_weight) OVER (PARTITION BY month ORDER BY date ROWS 30 PRECEDING)
    SUM(catch_weight_kg) OVER (
        PARTITION BY fisher_id, species_id, DATE_TRUNC('month', catch_date)
        ORDER BY catch_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS month_cumulative_kg,
    SUM(catch_weight_kg) OVER (
        PARTITION BY fisher_id, species_id
        ORDER BY catch_date
        ROWS 30 PRECEDING
    ) AS rolling_30day_kg
FROM catches
ORDER BY fisher_id, catch_date;

COMMENT ON VIEW vw_rolling_quota IS 'User sample: SUM() OVER (ROWS 30 PRECEDING) for rolling quota';

-- ============================================================================
-- View: Quota Compliance Status
-- ============================================================================

CREATE OR REPLACE VIEW vw_quota_compliance AS
WITH fisher_monthly AS (
    SELECT 
        c.fisher_id,
        f.fisher_name,
        f.license_number,
        c.species_id,
        s.species_name,
        DATE_TRUNC('month', c.catch_date) AS month,
        SUM(c.catch_weight_kg) AS total_catch_kg,
        COUNT(*) AS catch_count
    FROM catches c
    JOIN fishers f ON c.fisher_id = f.fisher_id
    JOIN fish_species s ON c.species_id = s.species_id
    GROUP BY c.fisher_id, f.fisher_name, f.license_number, 
             c.species_id, s.species_name, DATE_TRUNC('month', c.catch_date)
)
SELECT 
    fm.*,
    COALESCE(mq.quota_kg, fs.max_quota_per_month_kg) AS quota_kg,
    ROUND((fm.total_catch_kg / COALESCE(mq.quota_kg, fs.max_quota_per_month_kg) * 100), 1) AS quota_pct,
    CASE 
        WHEN fm.total_catch_kg > COALESCE(mq.quota_kg, fs.max_quota_per_month_kg) THEN '🔴 EXCEEDED'
        WHEN fm.total_catch_kg > COALESCE(mq.quota_kg, fs.max_quota_per_month_kg) * 0.9 THEN '🟠 WARNING'
        WHEN fm.total_catch_kg > COALESCE(mq.quota_kg, fs.max_quota_per_month_kg) * 0.7 THEN '🟡 APPROACHING'
        ELSE '🟢 OK'
    END AS compliance_status
FROM fisher_monthly fm
LEFT JOIN monthly_quotas mq ON fm.species_id = mq.species_id 
    AND fm.month = mq.year_month
LEFT JOIN fish_species fs ON fm.species_id = fs.species_id
ORDER BY quota_pct DESC;

-- ============================================================================
-- Function: Get Rolling Quota for Fisher
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_fisher_quota(
    p_fisher_id INT,
    p_species_id INT DEFAULT NULL
)
RETURNS TABLE (
    catch_date DATE,
    species_name VARCHAR,
    catch_kg DECIMAL,
    month_total_kg DECIMAL,
    rolling_30d_kg DECIMAL,
    quota_kg DECIMAL,
    quota_used_pct DECIMAL
) AS $$
SELECT 
    c.catch_date,
    s.species_name::VARCHAR,
    c.catch_weight_kg,
    SUM(c.catch_weight_kg) OVER (
        PARTITION BY c.species_id, DATE_TRUNC('month', c.catch_date)
        ORDER BY c.catch_date
    ) AS month_total_kg,
    SUM(c.catch_weight_kg) OVER (
        PARTITION BY c.species_id
        ORDER BY c.catch_date
        ROWS 30 PRECEDING
    ) AS rolling_30d_kg,
    COALESCE(mq.quota_kg, s.max_quota_per_month_kg) AS quota_kg,
    ROUND(
        SUM(c.catch_weight_kg) OVER (
            PARTITION BY c.species_id, DATE_TRUNC('month', c.catch_date)
            ORDER BY c.catch_date
        ) / COALESCE(mq.quota_kg, s.max_quota_per_month_kg) * 100, 
    1) AS quota_used_pct
FROM catches c
JOIN fish_species s ON c.species_id = s.species_id
LEFT JOIN monthly_quotas mq ON c.species_id = mq.species_id 
    AND DATE_TRUNC('month', c.catch_date) = mq.year_month
WHERE c.fisher_id = p_fisher_id
  AND (p_species_id IS NULL OR c.species_id = p_species_id)
ORDER BY c.catch_date DESC;
$$ LANGUAGE SQL;
