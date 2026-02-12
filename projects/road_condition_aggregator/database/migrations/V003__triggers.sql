-- ============================================================================
-- Road Condition Aggregator - V003 Triggers
-- PostgreSQL 14+ with PostGIS 3.x
-- Automated data management and spatial assignment triggers
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
-- Road Reports Triggers
-- ============================================================================

-- Auto-update modified timestamp
CREATE TRIGGER trg_road_reports_update_timestamp
    BEFORE UPDATE ON road_reports
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_timestamp();

-- Auto-assign district based on location
CREATE OR REPLACE FUNCTION fn_auto_assign_report_district()
RETURNS TRIGGER AS $$
DECLARE
    v_district_id INTEGER;
BEGIN
    -- Auto-assign district if not specified
    IF NEW.district_id IS NULL AND NEW.location IS NOT NULL THEN
        SELECT district_id
        INTO v_district_id
        FROM districts
        WHERE ST_Contains(boundary, NEW.location::geometry)
        LIMIT 1;
        
        IF v_district_id IS NOT NULL THEN
            NEW.district_id = v_district_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_assign_report_district
    BEFORE INSERT ON road_reports
    FOR EACH ROW
    EXECUTE FUNCTION fn_auto_assign_report_district();

-- Auto-match report to nearest road segment
CREATE OR REPLACE FUNCTION fn_auto_match_road_segment()
RETURNS TRIGGER AS $$
DECLARE
    v_segment_id INTEGER;
BEGIN
    -- Find nearest road segment within 50 meters
    IF NEW.segment_id IS NULL AND NEW.location IS NOT NULL THEN
        SELECT segment_id
        INTO v_segment_id
        FROM road_segments
        WHERE ST_DWithin(geom::geography, NEW.location, 50)
          AND status = 'active'
        ORDER BY ST_Distance(geom::geography, NEW.location)
        LIMIT 1;
        
        IF v_segment_id IS NOT NULL THEN
            NEW.segment_id = v_segment_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_match_road_segment
    BEFORE INSERT OR UPDATE OF location ON road_reports
    FOR EACH ROW
    EXECUTE FUNCTION fn_auto_match_road_segment();

-- Track report status changes
CREATE OR REPLACE FUNCTION fn_track_report_status()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        -- Update verified timestamp
        IF NEW.status = 'verified' AND NEW.verified_at IS NULL THEN
            NEW.verified_at = CURRENT_TIMESTAMP;
        END IF;
        
        -- Update repaired timestamp
        IF NEW.status = 'repaired' AND NEW.repaired_at IS NULL THEN
            NEW.repaired_at = CURRENT_TIMESTAMP;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_track_report_status
    BEFORE UPDATE OF status ON road_reports
    FOR EACH ROW
    EXECUTE FUNCTION fn_track_report_status();

-- ============================================================================
-- Road Segments Triggers
-- ============================================================================

-- Update timestamp for road segments
CREATE TRIGGER trg_road_segments_update_timestamp
    BEFORE UPDATE ON road_segments
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_timestamp();

-- Auto-assign district to segment based on geometry
CREATE OR REPLACE FUNCTION fn_auto_assign_segment_district()
RETURNS TRIGGER AS $$
DECLARE
    v_district_id INTEGER;
BEGIN
    IF NEW.district_id IS NULL AND NEW.geom IS NOT NULL THEN
        -- Find district that contains the segment centroid
        SELECT district_id
        INTO v_district_id
        FROM districts
        WHERE ST_Contains(boundary, ST_Centroid(NEW.geom))
        LIMIT 1;
        
        IF v_district_id IS NOT NULL THEN
            NEW.district_id = v_district_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_assign_segment_district
    BEFORE INSERT ON road_segments
    FOR EACH ROW
    EXECUTE FUNCTION fn_auto_assign_segment_district();

-- ============================================================================
-- Report Clusters Triggers
-- ============================================================================

-- Calculate cluster area when boundary is set
CREATE OR REPLACE FUNCTION fn_calculate_cluster_area()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.boundary IS NOT NULL THEN
        NEW.area_sq_m = ST_Area(NEW.boundary::geography);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calculate_cluster_area
    BEFORE INSERT OR UPDATE OF boundary ON report_clusters
    FOR EACH ROW
    EXECUTE FUNCTION fn_calculate_cluster_area();

-- Log cluster history on status change
CREATE OR REPLACE FUNCTION fn_log_cluster_history()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status OR TG_OP = 'INSERT' THEN
        INSERT INTO cluster_history (
            cluster_id, snapshot_date, report_count, avg_severity, status
        ) VALUES (
            NEW.cluster_id, CURRENT_DATE, NEW.report_count, NEW.avg_severity, NEW.status
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_cluster_history
    AFTER INSERT OR UPDATE OF status ON report_clusters
    FOR EACH ROW
    EXECUTE FUNCTION fn_log_cluster_history();

-- ============================================================================
-- Work Order Triggers
-- ============================================================================

-- Update work order timestamp
CREATE TRIGGER trg_work_orders_update_timestamp
    BEFORE UPDATE ON repair_work_orders
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_timestamp();

-- Track work order status changes
CREATE OR REPLACE FUNCTION fn_track_work_order_status()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        -- Log status change
        INSERT INTO work_order_history (
            work_order_id, old_status, new_status, notes
        ) VALUES (
            NEW.work_order_id, OLD.status, NEW.status, 'Status auto-logged by trigger'
        );
        
        -- Update timestamps based on status
        IF NEW.status = 'in_progress' AND NEW.started_at IS NULL THEN
            NEW.started_at = CURRENT_TIMESTAMP;
        ELSIF NEW.status = 'completed' AND NEW.completed_at IS NULL THEN
            NEW.completed_at = CURRENT_TIMESTAMP;
            
            -- Calculate actual hours if not set
            IF NEW.actual_hours IS NULL AND NEW.started_at IS NOT NULL THEN
                NEW.actual_hours = EXTRACT(EPOCH FROM (NEW.completed_at - NEW.started_at)) / 3600;
            END IF;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_track_work_order_status
    BEFORE UPDATE OF status ON repair_work_orders
    FOR EACH ROW
    EXECUTE FUNCTION fn_track_work_order_status();

-- Update cluster status when work order status changes
CREATE OR REPLACE FUNCTION fn_sync_cluster_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.cluster_id IS NOT NULL THEN
        UPDATE report_clusters
        SET status = CASE 
            WHEN NEW.status = 'completed' THEN 'completed'
            WHEN NEW.status IN ('in_progress', 'assigned') THEN 'in_progress'
            WHEN NEW.status = 'scheduled' THEN 'work_order_created'
            ELSE status
        END
        WHERE cluster_id = NEW.cluster_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_cluster_status
    AFTER UPDATE OF status ON repair_work_orders
    FOR EACH ROW
    EXECUTE FUNCTION fn_sync_cluster_status();

-- Update crew status when assigned to work order
CREATE OR REPLACE FUNCTION fn_update_crew_on_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- Mark crew as assigned when work order is assigned
    IF NEW.status = 'assigned' AND NEW.crew_id IS NOT NULL THEN
        UPDATE crews SET status = 'assigned' WHERE crew_id = NEW.crew_id;
    -- Mark crew as available when work order is completed
    ELSIF NEW.status = 'completed' AND OLD.crew_id IS NOT NULL THEN
        UPDATE crews SET status = 'available' WHERE crew_id = OLD.crew_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_crew_on_assignment
    AFTER UPDATE OF status ON repair_work_orders
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_crew_on_assignment();

-- ============================================================================
-- Daily Statistics Triggers
-- ============================================================================

-- Update daily statistics on report changes
CREATE OR REPLACE FUNCTION fn_update_daily_statistics()
RETURNS TRIGGER AS $$
DECLARE
    v_stat_date DATE;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_stat_date = DATE(OLD.reported_at AT TIME ZONE 'UTC');
    ELSE
        v_stat_date = DATE(NEW.reported_at AT TIME ZONE 'UTC');
    END IF;
    
    -- Upsert daily statistics
    INSERT INTO daily_statistics (
        stat_date,
        total_reports,
        new_reports,
        verified_reports,
        repaired_reports,
        avg_severity,
        calculated_at
    )
    SELECT 
        v_stat_date,
        COUNT(*),
        COUNT(*) FILTER (WHERE status = 'new'),
        COUNT(*) FILTER (WHERE status = 'verified'),
        COUNT(*) FILTER (WHERE status = 'repaired'),
        ROUND(AVG(severity), 2),
        CURRENT_TIMESTAMP
    FROM road_reports
    WHERE DATE(reported_at AT TIME ZONE 'UTC') = v_stat_date
    ON CONFLICT (stat_date) DO UPDATE SET
        total_reports = EXCLUDED.total_reports,
        new_reports = EXCLUDED.new_reports,
        verified_reports = EXCLUDED.verified_reports,
        repaired_reports = EXCLUDED.repaired_reports,
        avg_severity = EXCLUDED.avg_severity,
        calculated_at = CURRENT_TIMESTAMP;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_daily_stats
    AFTER INSERT OR UPDATE OR DELETE ON road_reports
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_daily_statistics();

-- ============================================================================
-- Audit Triggers
-- ============================================================================

-- Generic audit function for road_reports
CREATE OR REPLACE FUNCTION fn_audit_road_reports()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, action, new_values)
        VALUES ('road_reports', NEW.report_id::TEXT, 'INSERT', to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_values, new_values)
        VALUES ('road_reports', NEW.report_id::TEXT, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_values)
        VALUES ('road_reports', OLD.report_id::TEXT, 'DELETE', to_jsonb(OLD));
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_road_reports
    AFTER INSERT OR UPDATE OR DELETE ON road_reports
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_road_reports();

-- ============================================================================
-- Validation Triggers
-- ============================================================================

-- Validate report location is within a valid district
CREATE OR REPLACE FUNCTION fn_validate_report_location()
RETURNS TRIGGER AS $$
DECLARE
    v_in_district BOOLEAN;
BEGIN
    IF NEW.location IS NOT NULL THEN
        SELECT EXISTS(
            SELECT 1 FROM districts
            WHERE ST_Contains(boundary, NEW.location::geometry)
        ) INTO v_in_district;
        
        IF NOT v_in_district THEN
            RAISE WARNING 'Report location (%) may be outside service area', NEW.report_id;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_report_location
    AFTER INSERT OR UPDATE OF location ON road_reports
    FOR EACH ROW
    EXECUTE FUNCTION fn_validate_report_location();
