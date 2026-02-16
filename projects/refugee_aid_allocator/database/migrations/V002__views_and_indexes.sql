-- ============================================================================
-- Refugee Aid Allocator - Views and Additional Indexes
-- PostgreSQL 14+
-- Migration: V002 - Analysis views using window functions
-- ============================================================================

-- ============================================================================
-- View: Refugee Priority Queue (User's Sample Query)
-- Uses RANK() OVER to prioritize by need score
-- ============================================================================

CREATE OR REPLACE VIEW vw_priority_queue AS
SELECT 
    n.need_id,
    r.refugee_id,
    r.unhcr_id,
    r.first_name || ' ' || r.last_name AS refugee_name,
    c.camp_name,
    ac.category_name AS aid_type,
    n.quantity_needed,
    ac.unit_of_measure,
    ul.urgency_name,
    n.need_score,
    r.vulnerability_score,
    h.size AS household_size,
    
    -- User's sample query pattern: RANK() OVER (ORDER BY need_score DESC)
    RANK() OVER (ORDER BY n.need_score DESC) AS overall_priority,
    
    -- Priority within camp
    RANK() OVER (PARTITION BY c.camp_id ORDER BY n.need_score DESC) AS camp_priority,
    
    -- Priority within category
    RANK() OVER (PARTITION BY ac.category_id ORDER BY n.need_score DESC) AS category_priority,
    
    -- Dense rank (no gaps)
    DENSE_RANK() OVER (ORDER BY n.need_score DESC) AS priority_tier,
    
    -- Days waiting
    EXTRACT(DAY FROM NOW() - n.assessed_date)::INT AS days_waiting,
    
    n.assessed_date,
    n.status
FROM needs n
JOIN refugees r ON n.refugee_id = r.refugee_id
JOIN households h ON r.household_id = h.household_id
JOIN camps c ON h.camp_id = c.camp_id
JOIN aid_categories ac ON n.category_id = ac.category_id
JOIN urgency_levels ul ON n.urgency_id = ul.urgency_id
WHERE n.status = 'pending'
ORDER BY n.need_score DESC;

COMMENT ON VIEW vw_priority_queue IS 'Primary view for generating aid distribution priority queue';

-- ============================================================================
-- View: Camp-Level Priority Queue
-- Extends user query with PARTITION BY camp
-- ============================================================================

CREATE OR REPLACE VIEW vw_camp_priority AS
SELECT 
    refugee_id,
    camp_name,
    need_score,
    RANK() OVER (PARTITION BY camp_name ORDER BY need_score DESC) AS priority
FROM vw_priority_queue
WHERE status = 'pending';

COMMENT ON VIEW vw_camp_priority IS 'User sample: RANK() OVER (ORDER BY need_score DESC) partitioned by camp';

-- ============================================================================
-- View: Camp Summary Statistics
-- ============================================================================

CREATE OR REPLACE VIEW vw_camp_summary AS
SELECT 
    c.camp_id,
    c.camp_name,
    c.district,
    c.capacity,
    c.current_population,
    ROUND((c.current_population::DECIMAL / NULLIF(c.capacity, 0) * 100), 1) AS occupancy_pct,
    COUNT(DISTINCT h.household_id) AS total_households,
    COUNT(DISTINCT r.refugee_id) AS total_refugees,
    
    -- Vulnerability breakdown
    COUNT(r.refugee_id) FILTER (WHERE r.is_unaccompanied_minor) AS unaccompanied_minors,
    COUNT(r.refugee_id) FILTER (WHERE r.is_elderly) AS elderly,
    COUNT(r.refugee_id) FILTER (WHERE r.is_disabled) AS disabled,
    COUNT(r.refugee_id) FILTER (WHERE r.is_pregnant_nursing) AS pregnant_nursing,
    
    -- Needs statistics
    COUNT(n.need_id) FILTER (WHERE n.status = 'pending') AS pending_needs,
    COALESCE(AVG(n.need_score) FILTER (WHERE n.status = 'pending'), 0) AS avg_need_score,
    MAX(n.need_score) FILTER (WHERE n.status = 'pending') AS max_need_score,
    
    c.established_date,
    c.status
FROM camps c
LEFT JOIN households h ON c.camp_id = h.camp_id AND h.status = 'active'
LEFT JOIN refugees r ON h.household_id = r.household_id AND r.status = 'active'
LEFT JOIN needs n ON r.refugee_id = n.refugee_id
GROUP BY c.camp_id, c.camp_name, c.district, c.capacity, c.current_population,
         c.established_date, c.status
ORDER BY pending_needs DESC;

-- ============================================================================
-- View: Allocation Gaps Analysis
-- ============================================================================

CREATE OR REPLACE VIEW vw_allocation_gaps AS
WITH category_demand AS (
    SELECT 
        c.camp_id,
        c.camp_name,
        ac.category_id,
        ac.category_name,
        ac.unit_of_measure,
        COUNT(n.need_id) AS pending_requests,
        SUM(n.quantity_needed) AS total_quantity_needed
    FROM camps c
    CROSS JOIN aid_categories ac
    LEFT JOIN households h ON c.camp_id = h.camp_id AND h.status = 'active'
    LEFT JOIN refugees r ON h.household_id = r.household_id AND r.status = 'active'
    LEFT JOIN needs n ON r.refugee_id = n.refugee_id 
                     AND n.category_id = ac.category_id
                     AND n.status = 'pending'
    GROUP BY c.camp_id, c.camp_name, ac.category_id, ac.category_name, ac.unit_of_measure
),
category_supply AS (
    SELECT 
        camp_id,
        category_id,
        quantity_available,
        quantity_reserved,
        quantity_available - quantity_reserved AS quantity_free
    FROM aid_inventory
)
SELECT 
    cd.camp_name,
    cd.category_name,
    cd.unit_of_measure,
    cd.pending_requests,
    COALESCE(cd.total_quantity_needed, 0) AS demand,
    COALESCE(cs.quantity_available, 0) AS supply,
    COALESCE(cs.quantity_free, 0) AS available,
    COALESCE(cd.total_quantity_needed, 0) - COALESCE(cs.quantity_free, 0) AS gap,
    CASE 
        WHEN COALESCE(cs.quantity_free, 0) >= COALESCE(cd.total_quantity_needed, 0) THEN 'Sufficient'
        WHEN COALESCE(cs.quantity_free, 0) > 0 THEN 'Partial'
        ELSE 'Critical'
    END AS status,
    
    -- Rank gaps by severity
    RANK() OVER (ORDER BY 
        COALESCE(cd.total_quantity_needed, 0) - COALESCE(cs.quantity_free, 0) DESC
    ) AS gap_priority
FROM category_demand cd
LEFT JOIN category_supply cs ON cd.camp_id = cs.camp_id 
                             AND cd.category_id = cs.category_id
WHERE cd.pending_requests > 0 OR COALESCE(cs.quantity_available, 0) > 0
ORDER BY gap DESC;

-- ============================================================================
-- View: Distribution History with Running Totals
-- ============================================================================

CREATE OR REPLACE VIEW vw_distribution_history AS
SELECT 
    d.distribution_id,
    r.refugee_id,
    r.first_name || ' ' || r.last_name AS refugee_name,
    c.camp_name,
    ac.category_name,
    d.quantity_distributed,
    ac.unit_of_measure,
    d.distribution_date,
    d.distributed_by,
    
    -- Running total per refugee per category
    SUM(d.quantity_distributed) OVER (
        PARTITION BY r.refugee_id, ac.category_id
        ORDER BY d.distribution_date
        ROWS UNBOUNDED PRECEDING
    ) AS cumulative_received,
    
    -- Count of distributions
    ROW_NUMBER() OVER (
        PARTITION BY r.refugee_id, ac.category_id
        ORDER BY d.distribution_date
    ) AS distribution_number
FROM distributions d
JOIN allocations a ON d.allocation_id = a.allocation_id
JOIN needs n ON a.need_id = n.need_id
JOIN refugees r ON n.refugee_id = r.refugee_id
JOIN households h ON r.household_id = h.household_id
JOIN camps c ON h.camp_id = c.camp_id
JOIN aid_categories ac ON n.category_id = ac.category_id
ORDER BY d.distribution_date DESC;

-- ============================================================================
-- View: Refugee Vulnerability Profile
-- ============================================================================

CREATE OR REPLACE VIEW vw_vulnerability_profile AS
SELECT 
    r.refugee_id,
    r.unhcr_id,
    r.first_name || ' ' || r.last_name AS refugee_name,
    c.camp_name,
    h.household_code,
    h.size AS household_size,
    r.vulnerability_score,
    
    -- Percentile ranking across all refugees
    PERCENT_RANK() OVER (ORDER BY r.vulnerability_score) AS vulnerability_percentile,
    
    -- NTILE for risk buckets (quartiles)
    NTILE(4) OVER (ORDER BY r.vulnerability_score DESC) AS risk_quartile,
    
    -- Vulnerability flags
    r.is_unaccompanied_minor,
    r.is_elderly,
    r.is_pregnant_nursing,
    r.is_disabled,
    r.is_single_parent,
    r.has_chronic_illness,
    
    -- Count active needs
    COUNT(n.need_id) FILTER (WHERE n.status = 'pending') AS active_needs,
    
    r.arrival_date,
    EXTRACT(DAY FROM NOW() - r.arrival_date)::INT AS days_in_camp
FROM refugees r
JOIN households h ON r.household_id = h.household_id
JOIN camps c ON h.camp_id = c.camp_id
LEFT JOIN needs n ON r.refugee_id = n.refugee_id
WHERE r.status = 'active'
GROUP BY r.refugee_id, r.unhcr_id, r.first_name, r.last_name, c.camp_name,
         h.household_code, h.size, r.vulnerability_score,
         r.is_unaccompanied_minor, r.is_elderly, r.is_pregnant_nursing,
         r.is_disabled, r.is_single_parent, r.has_chronic_illness, r.arrival_date
ORDER BY r.vulnerability_score DESC;

-- ============================================================================
-- View: Daily Allocation Summary
-- ============================================================================

CREATE OR REPLACE VIEW vw_daily_allocation_summary AS
SELECT 
    DATE(a.allocated_date) AS allocation_date,
    c.camp_name,
    ac.category_name,
    COUNT(a.allocation_id) AS allocations_made,
    SUM(a.quantity_allocated) AS total_allocated,
    
    -- Comparison to previous day
    LAG(COUNT(a.allocation_id)) OVER (
        PARTITION BY c.camp_id, ac.category_id
        ORDER BY DATE(a.allocated_date)
    ) AS prev_day_allocations,
    
    -- 7-day moving average
    AVG(COUNT(a.allocation_id)) OVER (
        PARTITION BY c.camp_id, ac.category_id
        ORDER BY DATE(a.allocated_date)
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS avg_7day_allocations
FROM allocations a
JOIN aid_inventory ai ON a.inventory_id = ai.inventory_id
JOIN camps c ON ai.camp_id = c.camp_id
JOIN needs n ON a.need_id = n.need_id
JOIN aid_categories ac ON n.category_id = ac.category_id
GROUP BY DATE(a.allocated_date), c.camp_id, c.camp_name, ac.category_id, ac.category_name
ORDER BY allocation_date DESC, camp_name;

-- ============================================================================
-- Materialized View: Priority Buckets (for faster queries)
-- ============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_priority_buckets AS
SELECT 
    c.camp_id,
    c.camp_name,
    NTILE(5) OVER (ORDER BY n.need_score DESC) AS priority_bucket,
    COUNT(*) AS refugee_count,
    AVG(n.need_score)::DECIMAL(6,2) AS avg_score,
    MIN(n.need_score)::DECIMAL(6,2) AS min_score,
    MAX(n.need_score)::DECIMAL(6,2) AS max_score
FROM needs n
JOIN refugees r ON n.refugee_id = r.refugee_id
JOIN households h ON r.household_id = h.household_id
JOIN camps c ON h.camp_id = c.camp_id
WHERE n.status = 'pending'
GROUP BY c.camp_id, c.camp_name, NTILE(5) OVER (ORDER BY n.need_score DESC)
ORDER BY c.camp_name, priority_bucket;

-- Index for materialized view
CREATE INDEX IF NOT EXISTS idx_mv_priority_camp ON mv_priority_buckets(camp_id);

-- ============================================================================
-- Additional Indexes for View Performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_needs_assessed_date ON needs(assessed_date DESC);
CREATE INDEX IF NOT EXISTS idx_allocations_date ON allocations(allocated_date DESC);
CREATE INDEX IF NOT EXISTS idx_distributions_date ON distributions(distribution_date DESC);
CREATE INDEX IF NOT EXISTS idx_refugees_status_vuln ON refugees(status, vulnerability_score DESC);
