-- ============================================================================
-- Road Condition Aggregator - V001 Initial Schema
-- PostgreSQL 14+ with PostGIS 3.x
-- ============================================================================

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================================
-- Reference Tables
-- ============================================================================

-- Road classifications
CREATE TABLE road_classifications (
    class_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    code VARCHAR(10) NOT NULL UNIQUE,
    priority_weight NUMERIC(3, 1) NOT NULL DEFAULT 1.0,
    typical_speed_limit INTEGER,
    description TEXT
);

COMMENT ON TABLE road_classifications IS 'Road types with priority weights for repair scheduling';
COMMENT ON COLUMN road_classifications.priority_weight IS 'Higher weight = higher repair priority';

-- Damage types
CREATE TABLE damage_types (
    damage_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    code VARCHAR(10) NOT NULL UNIQUE,
    severity_weight NUMERIC(3, 1) NOT NULL DEFAULT 1.0,
    estimated_repair_cost NUMERIC(10, 2),
    estimated_repair_hours NUMERIC(5, 2),
    safety_hazard_level INTEGER CHECK (safety_hazard_level BETWEEN 1 AND 5),
    description TEXT
);

COMMENT ON TABLE damage_types IS 'Types of road damage with repair estimates';
COMMENT ON COLUMN damage_types.severity_weight IS 'Multiplier for severity scoring';

-- Severity level definitions
CREATE TABLE severity_levels (
    level INTEGER PRIMARY KEY CHECK (level BETWEEN 1 AND 10),
    name VARCHAR(30) NOT NULL,
    description TEXT,
    response_urgency VARCHAR(20) CHECK (response_urgency IN ('routine', 'priority', 'urgent', 'emergency'))
);

-- Report sources
CREATE TABLE report_sources (
    source_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    reliability_factor NUMERIC(3, 2) DEFAULT 1.0 CHECK (reliability_factor BETWEEN 0 AND 2),
    description TEXT
);

-- Districts/Administrative areas
CREATE TABLE districts (
    district_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(20) NOT NULL UNIQUE,
    boundary GEOMETRY(POLYGON, 4326),
    area_sq_km NUMERIC(10, 2),
    population INTEGER,
    maintenance_zone VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE districts IS 'Administrative districts for report aggregation';

-- Repair crews
CREATE TABLE crews (
    crew_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    base_location GEOGRAPHY(POINT, 4326),
    crew_type VARCHAR(30) CHECK (crew_type IN ('pothole', 'resurfacing', 'emergency', 'general')),
    member_count INTEGER DEFAULT 2,
    status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'assigned', 'off_duty', 'maintenance')),
    current_location GEOGRAPHY(POINT, 4326),
    equipment_capacity VARCHAR(50)
);

COMMENT ON TABLE crews IS 'Road repair crews and their locations';

-- ============================================================================
-- Core Infrastructure Tables
-- ============================================================================

-- Road segments (road network)
CREATE TABLE road_segments (
    segment_id SERIAL PRIMARY KEY,
    district_id INTEGER REFERENCES districts(district_id),
    road_class_id INTEGER NOT NULL REFERENCES road_classifications(class_id),
    road_name VARCHAR(200) NOT NULL,
    segment_name VARCHAR(100),
    geom GEOMETRY(LINESTRING, 4326) NOT NULL,
    length_m NUMERIC(12, 2) GENERATED ALWAYS AS (
        ST_Length(geom::geography)
    ) STORED,
    traffic_volume INTEGER,
    speed_limit INTEGER,
    lanes INTEGER DEFAULT 2,
    pavement_type VARCHAR(30),
    pavement_condition INTEGER CHECK (pavement_condition BETWEEN 1 AND 10),
    last_maintenance_date DATE,
    next_scheduled_maintenance DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'closed', 'construction', 'planned')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE road_segments IS 'Road network segments with pavement condition tracking';
COMMENT ON COLUMN road_segments.length_m IS 'Auto-calculated geodetic length in meters';

-- ============================================================================
-- Report and Clustering Tables
-- ============================================================================

-- Main road reports table
CREATE TABLE road_reports (
    report_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    district_id INTEGER REFERENCES districts(district_id),
    segment_id INTEGER REFERENCES road_segments(segment_id),
    damage_type_id INTEGER NOT NULL REFERENCES damage_types(damage_id),
    source_id INTEGER REFERENCES report_sources(source_id),
    
    -- Geospatial data
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    address_description TEXT,
    
    -- Severity and classification
    severity INTEGER NOT NULL CHECK (severity BETWEEN 1 AND 10),
    width_cm INTEGER,
    depth_cm INTEGER,
    length_cm INTEGER,
    
    -- Status tracking
    reported_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    verified_at TIMESTAMPTZ,
    verified_by VARCHAR(100),
    scheduled_repair_date DATE,
    repaired_at TIMESTAMPTZ,
    status VARCHAR(30) NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'verified', 'scheduled', 'in_progress', 'repaired', 'rejected', 'duplicate')),
    
    -- Additional info
    reporter_id VARCHAR(100),
    photo_url TEXT,
    notes TEXT,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE road_reports IS 'Citizen and sensor reports of road damage';
COMMENT ON COLUMN road_reports.location IS 'Point location in WGS84 (geography for accurate distance)';
COMMENT ON COLUMN road_reports.severity IS 'Damage severity from 1 (minor) to 10 (dangerous)';

-- Pre-computed report clusters
CREATE TABLE report_clusters (
    cluster_id SERIAL PRIMARY KEY,
    analysis_date DATE NOT NULL DEFAULT CURRENT_DATE,
    cluster_number INTEGER NOT NULL,
    centroid GEOGRAPHY(POINT, 4326),
    boundary GEOMETRY(POLYGON, 4326),
    area_sq_m NUMERIC(12, 2),
    report_count INTEGER NOT NULL,
    avg_severity NUMERIC(4, 2),
    max_severity INTEGER,
    total_estimated_cost NUMERIC(12, 2),
    primary_damage_type_id INTEGER REFERENCES damage_types(damage_id),
    priority_score NUMERIC(8, 2),
    affected_road_names TEXT[],
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'work_order_created', 'in_progress', 'completed')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(analysis_date, cluster_number)
);

COMMENT ON TABLE report_clusters IS 'DBSCAN clustering results for work order generation';

-- Cluster history for trend tracking
CREATE TABLE cluster_history (
    history_id SERIAL PRIMARY KEY,
    cluster_id INTEGER REFERENCES report_clusters(cluster_id),
    snapshot_date DATE NOT NULL,
    report_count INTEGER,
    avg_severity NUMERIC(4, 2),
    status VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Report to cluster mapping
CREATE TABLE report_cluster_mapping (
    mapping_id SERIAL PRIMARY KEY,
    report_id UUID NOT NULL REFERENCES road_reports(report_id) ON DELETE CASCADE,
    cluster_id INTEGER NOT NULL REFERENCES report_clusters(cluster_id) ON DELETE CASCADE,
    analysis_date DATE NOT NULL,
    distance_to_centroid NUMERIC(10, 2),
    UNIQUE(report_id, analysis_date)
);

-- ============================================================================
-- Work Order Tables
-- ============================================================================

-- Repair work orders (generated from clusters)
CREATE TABLE repair_work_orders (
    work_order_id SERIAL PRIMARY KEY,
    cluster_id INTEGER REFERENCES report_clusters(cluster_id),
    crew_id INTEGER REFERENCES crews(crew_id),
    
    -- Work area
    work_center GEOGRAPHY(POINT, 4326),
    work_area GEOMETRY(POLYGON, 4326),
    affected_segment_ids INTEGER[],
    
    -- Scheduling
    priority_score NUMERIC(8, 2) NOT NULL,
    priority_rank INTEGER,
    scheduled_date DATE,
    scheduled_time_start TIME,
    scheduled_time_end TIME,
    
    -- Execution
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    actual_hours NUMERIC(6, 2),
    
    -- Status
    status VARCHAR(30) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'scheduled', 'assigned', 'in_progress', 'completed', 'cancelled', 'rescheduled')),
    
    -- Cost tracking
    estimated_cost NUMERIC(12, 2),
    actual_cost NUMERIC(12, 2),
    materials_used JSONB,
    
    -- Notes
    notes TEXT,
    completion_notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE repair_work_orders IS 'Repair work orders generated from clustered reports';

-- Work order status history
CREATE TABLE work_order_history (
    history_id SERIAL PRIMARY KEY,
    work_order_id INTEGER NOT NULL REFERENCES repair_work_orders(work_order_id) ON DELETE CASCADE,
    old_status VARCHAR(30),
    new_status VARCHAR(30) NOT NULL,
    changed_by VARCHAR(100),
    notes TEXT,
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- Analytics Tables
-- ============================================================================

-- Daily statistics
CREATE TABLE daily_statistics (
    stat_date DATE PRIMARY KEY,
    total_reports INTEGER DEFAULT 0,
    new_reports INTEGER DEFAULT 0,
    verified_reports INTEGER DEFAULT 0,
    repaired_reports INTEGER DEFAULT 0,
    avg_severity NUMERIC(4, 2),
    clusters_identified INTEGER DEFAULT 0,
    work_orders_created INTEGER DEFAULT 0,
    work_orders_completed INTEGER DEFAULT 0,
    calculated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- District summary (refreshed daily)
CREATE TABLE district_daily_summary (
    summary_id SERIAL PRIMARY KEY,
    district_id INTEGER NOT NULL REFERENCES districts(district_id),
    summary_date DATE NOT NULL,
    report_count INTEGER DEFAULT 0,
    avg_severity NUMERIC(4, 2),
    pothole_count INTEGER DEFAULT 0,
    cluster_count INTEGER DEFAULT 0,
    pending_work_orders INTEGER DEFAULT 0,
    completed_work_orders INTEGER DEFAULT 0,
    UNIQUE(district_id, summary_date)
);

-- Audit log
CREATE TABLE audit_log (
    log_id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id TEXT NOT NULL,
    action VARCHAR(20) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    performed_by VARCHAR(100),
    performed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
