-- ============================================================================
-- Power Outage Pattern Analyzer - V003 Triggers
-- PostgreSQL 14+ with PostGIS 3.x
-- Automated data management and audit triggers
-- ============================================================================

-- ============================================================================
-- Utility Functions
-- ============================================================================

-- Update timestamp function
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- Outage Triggers
-- ============================================================================

-- Auto-update modified timestamp
CREATE TRIGGER trg_outages_update_timestamp
    BEFORE UPDATE ON outages
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_timestamp();

-- Status change tracking
CREATE OR REPLACE FUNCTION fn_outage_status_changed()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO outage_status_history (
            outage_id, 
            old_status, 
            new_status, 
            notes
        )
        VALUES (
            NEW.outage_id,
            OLD.status,
            NEW.status,
            'Status auto-logged by trigger'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_outage_status_change
    AFTER UPDATE OF status ON outages
    FOR EACH ROW
    EXECUTE FUNCTION fn_outage_status_changed();

-- Auto-calculate SAIDI/SAIFI contribution on restore
CREATE OR REPLACE FUNCTION fn_calculate_reliability_metrics()
RETURNS TRIGGER AS $$
DECLARE
    v_total_customers INTEGER;
BEGIN
    -- Only calculate when outage is restored
    IF NEW.restored_at IS NOT NULL AND OLD.restored_at IS NULL THEN
        -- Get total customers in district
        SELECT COALESCE(SUM(customers_served), 0)
        INTO v_total_customers
        FROM transformers
        WHERE district_id = NEW.district_id;
        
        IF v_total_customers > 0 THEN
            -- SAIDI = (Customer Minutes Interrupted) / Total Customers
            NEW.saidi_contribution_minutes = 
                (NEW.customers_affected * NEW.duration_minutes)::NUMERIC / v_total_customers;
            
            -- SAIFI = (Customers Interrupted) / Total Customers
            NEW.saifi_contribution = 
                NEW.customers_affected::NUMERIC / v_total_customers;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calculate_reliability_metrics
    BEFORE UPDATE OF restored_at ON outages
    FOR EACH ROW
    EXECUTE FUNCTION fn_calculate_reliability_metrics();

-- Auto-determine severity based on customers affected
CREATE OR REPLACE FUNCTION fn_determine_outage_severity()
RETURNS TRIGGER AS $$
BEGIN
    -- Auto-classify severity based on customers affected
    IF NEW.severity IS NULL OR NEW.severity = 'minor' THEN
        NEW.severity = CASE
            WHEN NEW.customers_affected >= 10000 THEN 'critical'
            WHEN NEW.customers_affected >= 5000 THEN 'major'
            WHEN NEW.customers_affected >= 1000 THEN 'moderate'
            ELSE 'minor'
        END;
        
        -- Mark as major event if critical or very large
        IF NEW.customers_affected >= 10000 OR NEW.severity = 'critical' THEN
            NEW.is_major_event = true;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_determine_severity
    BEFORE INSERT OR UPDATE OF customers_affected ON outages
    FOR EACH ROW
    EXECUTE FUNCTION fn_determine_outage_severity();

-- Auto-assign district based on location
CREATE OR REPLACE FUNCTION fn_auto_assign_district()
RETURNS TRIGGER AS $$
DECLARE
    v_district_id INTEGER;
BEGIN
    -- Only auto-assign if not already specified
    IF NEW.district_id IS NULL AND NEW.location IS NOT NULL THEN
        SELECT district_id
        INTO v_district_id
        FROM districts
        WHERE ST_Contains(boundary, (NEW.location::geometry))
        LIMIT 1;
        
        IF v_district_id IS NOT NULL THEN
            NEW.district_id = v_district_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_assign_district
    BEFORE INSERT ON outages
    FOR EACH ROW
    EXECUTE FUNCTION fn_auto_assign_district();

-- ============================================================================
-- Crew Dispatch Triggers
-- ============================================================================

-- Update outage status when crew is dispatched
CREATE OR REPLACE FUNCTION fn_crew_dispatch_status_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Update outage status based on dispatch progress
    IF TG_OP = 'INSERT' THEN
        UPDATE outages 
        SET status = 'crew_assigned'
        WHERE outage_id = NEW.outage_id
          AND status IN ('reported', 'confirmed', 'active');
          
    ELSIF TG_OP = 'UPDATE' THEN
        -- Crew arrived
        IF NEW.arrived_at IS NOT NULL AND OLD.arrived_at IS NULL THEN
            UPDATE outages 
            SET status = 'in_repair'
            WHERE outage_id = NEW.outage_id
              AND status = 'crew_assigned';
        END IF;
        
        -- Crew completed
        IF NEW.completed_at IS NOT NULL AND OLD.completed_at IS NULL THEN
            UPDATE outages 
            SET status = 'restored',
                restored_at = COALESCE(restored_at, NEW.completed_at)
            WHERE outage_id = NEW.outage_id
              AND status = 'in_repair';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_crew_dispatch_status
    AFTER INSERT OR UPDATE ON crew_dispatches
    FOR EACH ROW
    EXECUTE FUNCTION fn_crew_dispatch_status_update();

-- Update crew status when dispatched
CREATE OR REPLACE FUNCTION fn_update_crew_status_on_dispatch()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE crews SET status = 'dispatched' WHERE crew_id = NEW.crew_id;
    ELSIF TG_OP = 'UPDATE' AND NEW.completed_at IS NOT NULL AND OLD.completed_at IS NULL THEN
        UPDATE crews SET status = 'available' WHERE crew_id = NEW.crew_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_crew_status
    AFTER INSERT OR UPDATE ON crew_dispatches
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_crew_status_on_dispatch();

-- ============================================================================
-- Transformer Triggers
-- ============================================================================

-- Update customer count when service points change
CREATE OR REPLACE FUNCTION fn_update_transformer_customer_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE transformers 
        SET customers_served = customers_served + 1
        WHERE transformer_id = NEW.transformer_id;
        
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE transformers 
        SET customers_served = customers_served - 1
        WHERE transformer_id = OLD.transformer_id;
        
    ELSIF TG_OP = 'UPDATE' AND OLD.transformer_id != NEW.transformer_id THEN
        UPDATE transformers 
        SET customers_served = customers_served - 1
        WHERE transformer_id = OLD.transformer_id;
        
        UPDATE transformers 
        SET customers_served = customers_served + 1
        WHERE transformer_id = NEW.transformer_id;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_customer_count
    AFTER INSERT OR UPDATE OR DELETE ON service_points
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_transformer_customer_count();

-- ============================================================================
-- Daily Statistics Trigger
-- ============================================================================

-- Auto-update daily statistics when outages change
CREATE OR REPLACE FUNCTION fn_update_daily_statistics()
RETURNS TRIGGER AS $$
DECLARE
    v_stat_date DATE;
BEGIN
    -- Determine relevant date
    IF TG_OP = 'DELETE' THEN
        v_stat_date = DATE(OLD.occurred_at AT TIME ZONE 'UTC');
    ELSE
        v_stat_date = DATE(NEW.occurred_at AT TIME ZONE 'UTC');
    END IF;
    
    -- Upsert daily statistics
    INSERT INTO daily_outage_statistics (
        stat_date,
        total_outages,
        planned_outages,
        unplanned_outages,
        total_customers_affected,
        total_duration_minutes,
        avg_duration_minutes,
        weather_related,
        equipment_related,
        calculated_at
    )
    SELECT 
        v_stat_date,
        COUNT(*),
        COUNT(*) FILTER (WHERE outage_type = 'planned'),
        COUNT(*) FILTER (WHERE outage_type = 'unplanned'),
        COALESCE(SUM(customers_affected), 0),
        COALESCE(SUM(duration_minutes), 0),
        ROUND(AVG(duration_minutes), 2),
        COUNT(*) FILTER (WHERE cause_id IN (SELECT cause_id FROM outage_causes WHERE category = 'weather')),
        COUNT(*) FILTER (WHERE cause_id IN (SELECT cause_id FROM outage_causes WHERE category = 'equipment')),
        CURRENT_TIMESTAMP
    FROM outages
    WHERE DATE(occurred_at AT TIME ZONE 'UTC') = v_stat_date
    ON CONFLICT (stat_date) DO UPDATE SET
        total_outages = EXCLUDED.total_outages,
        planned_outages = EXCLUDED.planned_outages,
        unplanned_outages = EXCLUDED.unplanned_outages,
        total_customers_affected = EXCLUDED.total_customers_affected,
        total_duration_minutes = EXCLUDED.total_duration_minutes,
        avg_duration_minutes = EXCLUDED.avg_duration_minutes,
        weather_related = EXCLUDED.weather_related,
        equipment_related = EXCLUDED.equipment_related,
        calculated_at = CURRENT_TIMESTAMP;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_daily_stats
    AFTER INSERT OR UPDATE OR DELETE ON outages
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_daily_statistics();

-- ============================================================================
-- Audit Triggers
-- ============================================================================

-- Generic audit function
CREATE OR REPLACE FUNCTION fn_audit_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, action, new_values)
        VALUES (TG_TABLE_NAME, NEW.outage_id::TEXT, 'INSERT', to_jsonb(NEW));
        RETURN NEW;
        
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_values, new_values)
        VALUES (TG_TABLE_NAME, NEW.outage_id::TEXT, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
        
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_values)
        VALUES (TG_TABLE_NAME, OLD.outage_id::TEXT, 'DELETE', to_jsonb(OLD));
        RETURN OLD;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Apply audit trigger to outages
CREATE TRIGGER trg_audit_outages
    AFTER INSERT OR UPDATE OR DELETE ON outages
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_changes();

-- ============================================================================
-- Geospatial Validation Triggers
-- ============================================================================

-- Validate location is within district boundary
CREATE OR REPLACE FUNCTION fn_validate_location_in_district()
RETURNS TRIGGER AS $$
DECLARE
    v_is_valid BOOLEAN;
BEGIN
    IF NEW.location IS NOT NULL AND NEW.district_id IS NOT NULL THEN
        SELECT ST_Contains(boundary, NEW.location::geometry)
        INTO v_is_valid
        FROM districts
        WHERE district_id = NEW.district_id;
        
        IF NOT v_is_valid THEN
            RAISE WARNING 'Outage location may be outside district boundary (outage_id: %)', NEW.outage_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_outage_location
    AFTER INSERT OR UPDATE OF location, district_id ON outages
    FOR EACH ROW
    EXECUTE FUNCTION fn_validate_location_in_district();
