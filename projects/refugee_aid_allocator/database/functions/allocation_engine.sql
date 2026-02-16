-- ============================================================================
-- Refugee Aid Allocator - Allocation Engine Functions
-- PostgreSQL 14+
-- Functions: Allocate aid based on priority ranking
-- ============================================================================

-- ============================================================================
-- Function: Allocate Aid by Priority (Core Allocation Engine)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_allocate_by_priority(
    p_camp_id INT,
    p_category_id INT,
    p_quantity_to_allocate DECIMAL(12,2),
    p_allocated_by VARCHAR DEFAULT 'System'
)
RETURNS TABLE (
    allocations_made INT,
    total_allocated DECIMAL(12,2),
    remaining_quantity DECIMAL(12,2),
    refugees_served INT
) AS $$
DECLARE
    v_allocation_count INT := 0;
    v_total_allocated DECIMAL(12,2) := 0;
    v_remaining DECIMAL(12,2) := p_quantity_to_allocate;
    v_inventory_id INT;
    v_need RECORD;
BEGIN
    -- Get inventory record
    SELECT inventory_id INTO v_inventory_id
    FROM aid_inventory
    WHERE camp_id = p_camp_id AND category_id = p_category_id;
    
    IF v_inventory_id IS NULL THEN
        RAISE EXCEPTION 'No inventory found for camp % and category %', p_camp_id, p_category_id;
    END IF;
    
    -- Allocate to needs in priority order (using RANK pattern)
    FOR v_need IN
        SELECT 
            n.need_id,
            n.refugee_id,
            n.quantity_needed,
            n.need_score,
            RANK() OVER (ORDER BY n.need_score DESC) AS priority_rank
        FROM needs n
        JOIN refugees r ON n.refugee_id = r.refugee_id
        JOIN households h ON r.household_id = h.household_id
        WHERE h.camp_id = p_camp_id
          AND n.category_id = p_category_id
          AND n.status = 'pending'
        ORDER BY n.need_score DESC
    LOOP
        EXIT WHEN v_remaining <= 0;
        
        DECLARE
            v_qty_to_alloc DECIMAL(12,2);
        BEGIN
            -- Allocate full need or remaining quantity
            v_qty_to_alloc := LEAST(v_need.quantity_needed, v_remaining);
            
            -- Create allocation record
            INSERT INTO allocations (
                need_id, inventory_id, quantity_allocated, 
                allocated_by, priority_rank, status
            ) VALUES (
                v_need.need_id, v_inventory_id, v_qty_to_alloc,
                p_allocated_by, v_need.priority_rank, 'pending'
            );
            
            -- Update need status
            UPDATE needs SET 
                status = CASE 
                    WHEN v_qty_to_alloc >= quantity_needed THEN 'fulfilled'
                    ELSE 'partial'
                END,
                updated_at = NOW()
            WHERE need_id = v_need.need_id;
            
            -- Update inventory reserved
            UPDATE aid_inventory SET
                quantity_reserved = quantity_reserved + v_qty_to_alloc,
                updated_at = NOW()
            WHERE inventory_id = v_inventory_id;
            
            v_remaining := v_remaining - v_qty_to_alloc;
            v_total_allocated := v_total_allocated + v_qty_to_alloc;
            v_allocation_count := v_allocation_count + 1;
        END;
    END LOOP;
    
    RETURN QUERY SELECT 
        v_allocation_count,
        v_total_allocated,
        v_remaining,
        v_allocation_count;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Function: Process Distribution (Mark as Distributed)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_process_distribution(
    p_allocation_id INT,
    p_distributed_by VARCHAR,
    p_received_by VARCHAR DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_alloc RECORD;
BEGIN
    -- Get allocation details
    SELECT a.*, ai.inventory_id
    INTO v_alloc
    FROM allocations a
    JOIN aid_inventory ai ON a.inventory_id = ai.inventory_id
    WHERE a.allocation_id = p_allocation_id
      AND a.status IN ('pending', 'ready');
    
    IF v_alloc IS NULL THEN
        RAISE EXCEPTION 'Allocation % not found or already distributed', p_allocation_id;
    END IF;
    
    -- Create distribution record
    INSERT INTO distributions (
        allocation_id, quantity_distributed, distributed_by, 
        received_by, signature_collected, notes
    ) VALUES (
        p_allocation_id, v_alloc.quantity_allocated, p_distributed_by,
        p_received_by, p_received_by IS NOT NULL, p_notes
    );
    
    -- Update allocation status
    UPDATE allocations SET 
        status = 'distributed'
    WHERE allocation_id = p_allocation_id;
    
    -- Update inventory
    UPDATE aid_inventory SET
        quantity_available = quantity_available - v_alloc.quantity_allocated,
        quantity_reserved = quantity_reserved - v_alloc.quantity_allocated,
        updated_at = NOW()
    WHERE inventory_id = v_alloc.inventory_id;
    
    -- Log history
    INSERT INTO allocation_history (
        allocation_id, action, old_status, new_status, changed_by
    ) VALUES (
        p_allocation_id, 'distributed', v_alloc.status, 'distributed', p_distributed_by
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Function: Get Allocation Queue for Camp
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_get_allocation_queue(
    p_camp_name VARCHAR,
    p_limit INT DEFAULT 100
)
RETURNS TABLE (
    priority_rank BIGINT,
    refugee_name VARCHAR,
    household_code VARCHAR,
    aid_type VARCHAR,
    urgency VARCHAR,
    quantity DECIMAL(10,2),
    unit VARCHAR,
    need_score DECIMAL(6,2),
    days_waiting INT,
    vulnerability_score INT
) AS $$
BEGIN
    RETURN QUERY
    WITH ranked_needs AS (
        SELECT 
            n.need_id,
            r.first_name || ' ' || r.last_name AS refugee_name,
            h.household_code,
            ac.category_name AS aid_type,
            ul.urgency_name AS urgency,
            n.quantity_needed AS quantity,
            ac.unit_of_measure AS unit,
            n.need_score,
            EXTRACT(DAY FROM NOW() - n.assessed_date)::INT AS days_waiting,
            r.vulnerability_score,
            -- User's RANK() pattern
            RANK() OVER (ORDER BY n.need_score DESC) AS priority_rank
        FROM needs n
        JOIN refugees r ON n.refugee_id = r.refugee_id
        JOIN households h ON r.household_id = h.household_id
        JOIN camps c ON h.camp_id = c.camp_id
        JOIN aid_categories ac ON n.category_id = ac.category_id
        JOIN urgency_levels ul ON n.urgency_id = ul.urgency_id
        WHERE n.status = 'pending'
          AND c.camp_name = p_camp_name
    )
    SELECT 
        rn.priority_rank,
        rn.refugee_name::VARCHAR,
        rn.household_code::VARCHAR,
        rn.aid_type::VARCHAR,
        rn.urgency::VARCHAR,
        rn.quantity,
        rn.unit::VARCHAR,
        rn.need_score,
        rn.days_waiting,
        rn.vulnerability_score
    FROM ranked_needs rn
    ORDER BY rn.priority_rank
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Function: Check Inventory Availability
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_check_inventory(
    p_camp_name VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    camp_name VARCHAR,
    category_name VARCHAR,
    available DECIMAL(12,2),
    reserved DECIMAL(12,2),
    free_stock DECIMAL(12,2),
    reorder_level DECIMAL(12,2),
    needs_restock BOOLEAN,
    pending_needs BIGINT,
    demand_gap DECIMAL(12,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.camp_name::VARCHAR,
        ac.category_name::VARCHAR,
        ai.quantity_available,
        ai.quantity_reserved,
        (ai.quantity_available - ai.quantity_reserved) AS free_stock,
        ai.reorder_level,
        (ai.quantity_available - ai.quantity_reserved) < ai.reorder_level AS needs_restock,
        COUNT(n.need_id) FILTER (WHERE n.status = 'pending'),
        COALESCE(SUM(n.quantity_needed) FILTER (WHERE n.status = 'pending'), 0) - 
            (ai.quantity_available - ai.quantity_reserved) AS demand_gap
    FROM aid_inventory ai
    JOIN camps c ON ai.camp_id = c.camp_id
    JOIN aid_categories ac ON ai.category_id = ac.category_id
    LEFT JOIN households h ON c.camp_id = h.camp_id AND h.status = 'active'
    LEFT JOIN refugees r ON h.household_id = r.household_id AND r.status = 'active'
    LEFT JOIN needs n ON r.refugee_id = n.refugee_id AND n.category_id = ac.category_id
    WHERE (p_camp_name IS NULL OR c.camp_name = p_camp_name)
    GROUP BY c.camp_id, c.camp_name, ac.category_id, ac.category_name,
             ai.quantity_available, ai.quantity_reserved, ai.reorder_level
    ORDER BY demand_gap DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Function: Generate Distribution Report
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_distribution_summary(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    camp_name VARCHAR,
    category_name VARCHAR,
    total_distributions BIGINT,
    total_quantity DECIMAL(12,2),
    refugees_served BIGINT,
    avg_per_distribution DECIMAL(10,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.camp_name::VARCHAR,
        ac.category_name::VARCHAR,
        COUNT(d.distribution_id),
        SUM(d.quantity_distributed),
        COUNT(DISTINCT r.refugee_id),
        AVG(d.quantity_distributed)::DECIMAL(10,2)
    FROM distributions d
    JOIN allocations a ON d.allocation_id = a.allocation_id
    JOIN needs n ON a.need_id = n.need_id
    JOIN refugees r ON n.refugee_id = r.refugee_id
    JOIN households h ON r.household_id = h.household_id
    JOIN camps c ON h.camp_id = c.camp_id
    JOIN aid_categories ac ON n.category_id = ac.category_id
    WHERE d.distribution_date::DATE BETWEEN p_start_date AND p_end_date
    GROUP BY c.camp_id, c.camp_name, ac.category_id, ac.category_name
    ORDER BY total_quantity DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Procedure: Restock Inventory
-- ============================================================================

CREATE OR REPLACE PROCEDURE sp_restock_inventory(
    p_camp_id INT,
    p_category_id INT,
    p_quantity DECIMAL(12,2)
)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE aid_inventory SET
        quantity_available = quantity_available + p_quantity,
        last_restock_date = CURRENT_DATE,
        last_restock_quantity = p_quantity,
        updated_at = NOW()
    WHERE camp_id = p_camp_id
      AND category_id = p_category_id;
    
    IF NOT FOUND THEN
        INSERT INTO aid_inventory (camp_id, category_id, quantity_available, 
                                   last_restock_date, last_restock_quantity)
        VALUES (p_camp_id, p_category_id, p_quantity, CURRENT_DATE, p_quantity);
    END IF;
    
    COMMIT;
END;
$$;

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON FUNCTION fn_allocate_by_priority IS 'Core allocation engine using RANK() priority';
COMMENT ON FUNCTION fn_process_distribution IS 'Record actual distribution and update inventory';
COMMENT ON FUNCTION fn_get_allocation_queue IS 'Get prioritized allocation queue for a camp';
COMMENT ON FUNCTION fn_check_inventory IS 'Check inventory levels and demand gaps';
COMMENT ON FUNCTION fn_distribution_summary IS 'Summary of distributions over a date range';
