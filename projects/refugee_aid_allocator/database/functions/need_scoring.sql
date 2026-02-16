-- ============================================================================
-- Refugee Aid Allocator - Need Scoring Functions
-- PostgreSQL 14+
-- Functions: Calculate and update need scores
-- ============================================================================

-- ============================================================================
-- Function: Calculate Need Score for a Single Need
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_calculate_need_score(p_need_id INT)
RETURNS TABLE (
    need_id INT,
    refugee_id INT,
    urgency_component DECIMAL(6,2),
    vulnerability_component DECIMAL(6,2),
    household_component DECIMAL(6,2),
    wait_time_component DECIMAL(6,2),
    category_component DECIMAL(6,2),
    total_score DECIMAL(6,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        n.need_id,
        n.refugee_id,
        (ul.urgency_score * 0.35)::DECIMAL(6,2) AS urgency_component,
        (r.vulnerability_score * 0.25)::DECIMAL(6,2) AS vulnerability_component,
        (LEAST(h.size * 10, 100) * 0.20)::DECIMAL(6,2) AS household_component,
        (LEAST(EXTRACT(DAY FROM NOW() - n.assessed_date) * 3, 100) * 0.15)::DECIMAL(6,2) AS wait_time_component,
        (ac.priority_weight * 100 * 0.05)::DECIMAL(6,2) AS category_component,
        (
            (ul.urgency_score * 0.35) +
            (r.vulnerability_score * 0.25) +
            (LEAST(h.size * 10, 100) * 0.20) +
            (LEAST(EXTRACT(DAY FROM NOW() - n.assessed_date) * 3, 100) * 0.15) +
            (ac.priority_weight * 100 * 0.05)
        )::DECIMAL(6,2) AS total_score
    FROM needs n
    JOIN refugees r ON n.refugee_id = r.refugee_id
    JOIN households h ON r.household_id = h.household_id
    JOIN urgency_levels ul ON n.urgency_id = ul.urgency_id
    JOIN aid_categories ac ON n.category_id = ac.category_id
    WHERE n.need_id = p_need_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Function: Batch Update All Need Scores
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_update_all_need_scores()
RETURNS TABLE (
    updated_count INT,
    avg_score DECIMAL(6,2),
    min_score DECIMAL(6,2),
    max_score DECIMAL(6,2)
) AS $$
DECLARE
    v_count INT;
BEGIN
    -- Update all pending needs
    UPDATE needs n SET need_score = (
        SELECT 
            (ul.urgency_score * 0.35) +
            (r.vulnerability_score * 0.25) +
            (LEAST(h.size * 10, 100) * 0.20) +
            (LEAST(EXTRACT(DAY FROM NOW() - n.assessed_date) * 3, 100) * 0.15) +
            (ac.priority_weight * 100 * 0.05)
        FROM refugees r
        JOIN households h ON r.household_id = h.household_id
        JOIN urgency_levels ul ON n.urgency_id = ul.urgency_id
        JOIN aid_categories ac ON n.category_id = ac.category_id
        WHERE r.refugee_id = n.refugee_id
    )
    WHERE n.status = 'pending';
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    -- Return statistics
    RETURN QUERY
    SELECT 
        v_count::INT,
        AVG(need_score)::DECIMAL(6,2),
        MIN(need_score)::DECIMAL(6,2),
        MAX(need_score)::DECIMAL(6,2)
    FROM needs
    WHERE status = 'pending';
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Function: Get Priority Queue (User's Sample Query Pattern)
-- SELECT refugee_id, RANK() OVER (ORDER BY need_score DESC) as priority FROM needs
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_priority_queue(
    p_camp_name VARCHAR DEFAULT NULL,
    p_category_code VARCHAR DEFAULT NULL,
    p_limit INT DEFAULT 50
)
RETURNS TABLE (
    refugee_id INT,
    refugee_name VARCHAR,
    camp_name VARCHAR,
    aid_type VARCHAR,
    need_score DECIMAL(6,2),
    priority BIGINT,
    urgency VARCHAR,
    days_waiting INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.refugee_id,
        (r.first_name || ' ' || r.last_name)::VARCHAR AS refugee_name,
        c.camp_name::VARCHAR,
        ac.category_name::VARCHAR AS aid_type,
        n.need_score,
        -- User's sample: RANK() OVER (ORDER BY need_score DESC) as priority
        RANK() OVER (ORDER BY n.need_score DESC) AS priority,
        ul.urgency_name::VARCHAR AS urgency,
        EXTRACT(DAY FROM NOW() - n.assessed_date)::INT AS days_waiting
    FROM needs n
    JOIN refugees r ON n.refugee_id = r.refugee_id
    JOIN households h ON r.household_id = h.household_id
    JOIN camps c ON h.camp_id = c.camp_id
    JOIN aid_categories ac ON n.category_id = ac.category_id
    JOIN urgency_levels ul ON n.urgency_id = ul.urgency_id
    WHERE n.status = 'pending'
      AND (p_camp_name IS NULL OR c.camp_name = p_camp_name)
      AND (p_category_code IS NULL OR ac.category_code = p_category_code)
    ORDER BY n.need_score DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Function: Calculate Vulnerability Score
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_calculate_vulnerability_score(p_refugee_id INT)
RETURNS TABLE (
    refugee_id INT,
    base_score INT,
    unaccompanied_minor_bonus INT,
    elderly_bonus INT,
    pregnant_nursing_bonus INT,
    disabled_bonus INT,
    single_parent_bonus INT,
    chronic_illness_bonus INT,
    total_score INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.refugee_id,
        10 AS base_score,
        CASE WHEN r.is_unaccompanied_minor THEN 30 ELSE 0 END,
        CASE WHEN r.is_elderly THEN 20 ELSE 0 END,
        CASE WHEN r.is_pregnant_nursing THEN 25 ELSE 0 END,
        CASE WHEN r.is_disabled THEN 25 ELSE 0 END,
        CASE WHEN r.is_single_parent THEN 15 ELSE 0 END,
        CASE WHEN r.has_chronic_illness THEN 20 ELSE 0 END,
        (10 +
         CASE WHEN r.is_unaccompanied_minor THEN 30 ELSE 0 END +
         CASE WHEN r.is_elderly THEN 20 ELSE 0 END +
         CASE WHEN r.is_pregnant_nursing THEN 25 ELSE 0 END +
         CASE WHEN r.is_disabled THEN 25 ELSE 0 END +
         CASE WHEN r.is_single_parent THEN 15 ELSE 0 END +
         CASE WHEN r.has_chronic_illness THEN 20 ELSE 0 END
        )::INT AS total_score
    FROM refugees r
    WHERE r.refugee_id = p_refugee_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Function: Update Vulnerability Score for Refugee
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_update_vulnerability_score(p_refugee_id INT)
RETURNS INT AS $$
DECLARE
    v_score INT;
BEGIN
    SELECT total_score INTO v_score
    FROM fn_calculate_vulnerability_score(p_refugee_id);
    
    UPDATE refugees 
    SET vulnerability_score = v_score,
        updated_at = NOW()
    WHERE refugee_id = p_refugee_id;
    
    RETURN v_score;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Function: Get Camp-Level Statistics
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_camp_statistics(p_camp_name VARCHAR DEFAULT NULL)
RETURNS TABLE (
    camp_name VARCHAR,
    total_refugees BIGINT,
    total_pending_needs BIGINT,
    avg_need_score DECIMAL(6,2),
    critical_needs BIGINT,
    high_needs BIGINT,
    medium_needs BIGINT,
    low_needs BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.camp_name::VARCHAR,
        COUNT(DISTINCT r.refugee_id) AS total_refugees,
        COUNT(n.need_id) FILTER (WHERE n.status = 'pending') AS total_pending_needs,
        AVG(n.need_score)::DECIMAL(6,2) AS avg_need_score,
        COUNT(n.need_id) FILTER (WHERE ul.urgency_name = 'critical' AND n.status = 'pending') AS critical_needs,
        COUNT(n.need_id) FILTER (WHERE ul.urgency_name = 'high' AND n.status = 'pending') AS high_needs,
        COUNT(n.need_id) FILTER (WHERE ul.urgency_name = 'medium' AND n.status = 'pending') AS medium_needs,
        COUNT(n.need_id) FILTER (WHERE ul.urgency_name = 'low' AND n.status = 'pending') AS low_needs
    FROM camps c
    LEFT JOIN households h ON c.camp_id = h.camp_id AND h.status = 'active'
    LEFT JOIN refugees r ON h.household_id = r.household_id AND r.status = 'active'
    LEFT JOIN needs n ON r.refugee_id = n.refugee_id
    LEFT JOIN urgency_levels ul ON n.urgency_id = ul.urgency_id
    WHERE (p_camp_name IS NULL OR c.camp_name = p_camp_name)
    GROUP BY c.camp_id, c.camp_name
    ORDER BY total_pending_needs DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON FUNCTION fn_calculate_need_score IS 'Calculate need score breakdown for a single need';
COMMENT ON FUNCTION fn_update_all_need_scores IS 'Batch update all pending need scores';
COMMENT ON FUNCTION fn_get_priority_queue IS 'User sample query: RANK() OVER (ORDER BY need_score DESC)';
COMMENT ON FUNCTION fn_calculate_vulnerability_score IS 'Calculate vulnerability score from flags';
COMMENT ON FUNCTION fn_get_camp_statistics IS 'Get summary statistics for camps';
