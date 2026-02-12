-- ============================================================================
-- Power Outage Pattern Analyzer - V001 Initial Schema
-- PostgreSQL 14+ with PostGIS 3.x
-- ============================================================================

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- ============================================================================
-- Reference Tables
-- ============================================================================

-- Geographic regions (state/province level)
CREATE TABLE regions (
    region_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(10) NOT NULL UNIQUE,
    boundary GEOMETRY(POLYGON, 4326),
    population INTEGER,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE regions IS 'Top-level geographic regions containing multiple districts';
COMMENT ON COLUMN regions.boundary IS 'Region boundary polygon in WGS84 (EPSG:4326)';

-- Districts within regions
CREATE TABLE districts (
    district_id SERIAL PRIMARY KEY,
    region_id INTEGER NOT NULL REFERENCES regions(region_id),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,
    boundary GEOMETRY(POLYGON, 4326),
    population INTEGER,
    area_sq_km NUMERIC(10, 2),
    grid_zone VARCHAR(20),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(region_id, name)
);

COMMENT ON TABLE districts IS 'Administrative districts for outage aggregation';
COMMENT ON COLUMN districts.boundary IS 'District boundary polygon in WGS84';
COMMENT ON COLUMN districts.grid_zone IS 'Power grid zone identifier';

-- Substations (major power distribution points)
CREATE TABLE substations (
    substation_id SERIAL PRIMARY KEY,
    district_id INTEGER NOT NULL REFERENCES districts(district_id),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) NOT NULL UNIQUE,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    substation_type VARCHAR(50) NOT NULL CHECK (substation_type IN ('transmission', 'distribution', 'switching')),
    voltage_level_kv INTEGER NOT NULL,
    capacity_mva NUMERIC(10, 2),
    commissioned_date DATE,
    status VARCHAR(20) DEFAULT 'operational' CHECK (status IN ('operational', 'maintenance', 'offline', 'decommissioned')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE substations IS 'Electrical substations that distribute power';
COMMENT ON COLUMN substations.location IS 'Point location in WGS84 (geography type for accurate distance)';

-- Power lines connecting substations
CREATE TABLE power_lines (
    line_id SERIAL PRIMARY KEY,
    start_substation_id INTEGER NOT NULL REFERENCES substations(substation_id),
    end_substation_id INTEGER NOT NULL REFERENCES substations(substation_id),
    name VARCHAR(100),
    line_type VARCHAR(50) NOT NULL CHECK (line_type IN ('transmission', 'distribution', 'feeder')),
    voltage_kv INTEGER NOT NULL,
    route GEOMETRY(LINESTRING, 4326) NOT NULL,
    length_km NUMERIC(10, 2) GENERATED ALWAYS AS (
        ST_Length(route::geography) / 1000
    ) STORED,
    conductor_type VARCHAR(50),
    capacity_mw NUMERIC(10, 2),
    installation_year INTEGER,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'maintenance', 'damaged', 'decommissioned')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_different_substations CHECK (start_substation_id != end_substation_id)
);

COMMENT ON TABLE power_lines IS 'Transmission and distribution lines between substations';
COMMENT ON COLUMN power_lines.route IS 'Line route as LineString in WGS84';
COMMENT ON COLUMN power_lines.length_km IS 'Auto-calculated geodetic length in kilometers';

-- Transformers (distribution transformers)
CREATE TABLE transformers (
    transformer_id SERIAL PRIMARY KEY,
    district_id INTEGER NOT NULL REFERENCES districts(district_id),
    line_id INTEGER REFERENCES power_lines(line_id),
    name VARCHAR(100),
    code VARCHAR(30) NOT NULL UNIQUE,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    transformer_type VARCHAR(50) NOT NULL CHECK (transformer_type IN ('pole_mounted', 'pad_mounted', 'underground', 'substation')),
    capacity_kva NUMERIC(10, 2) NOT NULL,
    primary_voltage_v INTEGER NOT NULL,
    secondary_voltage_v INTEGER NOT NULL,
    installation_date DATE,
    age_years INTEGER GENERATED ALWAYS AS (
        EXTRACT(YEAR FROM AGE(CURRENT_DATE, installation_date))
    ) STORED,
    last_maintenance_date DATE,
    status VARCHAR(20) DEFAULT 'operational' CHECK (status IN ('operational', 'degraded', 'failed', 'replaced')),
    customers_served INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE transformers IS 'Distribution transformers serving customers';
COMMENT ON COLUMN transformers.age_years IS 'Auto-calculated age from installation date';

-- Service connection points (customer meters)
CREATE TABLE service_points (
    service_id SERIAL PRIMARY KEY,
    transformer_id INTEGER NOT NULL REFERENCES transformers(transformer_id),
    customer_id VARCHAR(50) NOT NULL UNIQUE,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    service_type VARCHAR(30) NOT NULL CHECK (service_type IN ('residential', 'commercial', 'industrial', 'municipal')),
    meter_number VARCHAR(50),
    contracted_load_kw NUMERIC(10, 2),
    connection_date DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'disconnected')),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE service_points IS 'Customer service connection points';

-- ============================================================================
-- Outage Reference Tables
-- ============================================================================

-- Outage causes
CREATE TABLE outage_causes (
    cause_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL CHECK (category IN ('weather', 'equipment', 'vegetation', 'animal', 'vehicle', 'human', 'overload', 'unknown')),
    is_preventable BOOLEAN DEFAULT false,
    typical_repair_hours NUMERIC(5, 2),
    description TEXT
);

COMMENT ON TABLE outage_causes IS 'Categorized causes of power outages';

-- Weather conditions
CREATE TABLE weather_conditions (
    condition_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    severity_level INTEGER CHECK (severity_level BETWEEN 1 AND 5),
    causes_outages BOOLEAN DEFAULT false
);

-- Crew teams
CREATE TABLE crews (
    crew_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    base_location GEOGRAPHY(POINT, 4326),
    specialization VARCHAR(50) CHECK (specialization IN ('transmission', 'distribution', 'emergency', 'vegetation', 'general')),
    member_count INTEGER DEFAULT 2,
    status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'dispatched', 'off_duty', 'standby')),
    current_location GEOGRAPHY(POINT, 4326)
);

COMMENT ON TABLE crews IS 'Maintenance and repair crews';

-- ============================================================================
-- Core Outage Tables
-- ============================================================================

-- Main outages table
CREATE TABLE outages (
    outage_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    district_id INTEGER NOT NULL REFERENCES districts(district_id),
    substation_id INTEGER REFERENCES substations(substation_id),
    transformer_id INTEGER REFERENCES transformers(transformer_id),
    line_id INTEGER REFERENCES power_lines(line_id),
    cause_id INTEGER REFERENCES outage_causes(cause_id),
    weather_condition_id INTEGER REFERENCES weather_conditions(condition_id),
    
    -- Geospatial data
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    affected_area GEOMETRY(POLYGON, 4326),
    
    -- Temporal data
    reported_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMPTZ,
    occurred_at TIMESTAMPTZ NOT NULL,
    estimated_restore_at TIMESTAMPTZ,
    restored_at TIMESTAMPTZ,
    
    -- Calculated duration
    duration_minutes INTEGER GENERATED ALWAYS AS (
        CASE 
            WHEN restored_at IS NOT NULL 
            THEN EXTRACT(EPOCH FROM (restored_at - occurred_at)) / 60
            ELSE NULL
        END
    ) STORED,
    
    -- Impact metrics
    customers_affected INTEGER NOT NULL DEFAULT 0,
    estimated_load_lost_kw NUMERIC(12, 2),
    saidi_contribution_minutes NUMERIC(12, 4),
    saifi_contribution NUMERIC(8, 6),
    
    -- Classification
    outage_type VARCHAR(30) NOT NULL DEFAULT 'unplanned' CHECK (outage_type IN ('planned', 'unplanned', 'emergency', 'rolling')),
    severity VARCHAR(20) DEFAULT 'minor' CHECK (severity IN ('minor', 'moderate', 'major', 'critical')),
    is_major_event BOOLEAN DEFAULT false,
    
    -- Status tracking
    status VARCHAR(30) NOT NULL DEFAULT 'active' CHECK (status IN ('reported', 'confirmed', 'active', 'crew_assigned', 'in_repair', 'restored', 'closed')),
    
    -- Additional info
    description TEXT,
    root_cause_analysis TEXT,
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE outages IS 'Power outage incidents with geospatial and temporal data';
COMMENT ON COLUMN outages.location IS 'Point location of outage origin (geography for distance calculations)';
COMMENT ON COLUMN outages.affected_area IS 'Polygon representing affected service area';
COMMENT ON COLUMN outages.saidi_contribution_minutes IS 'System Average Interruption Duration Index contribution';
COMMENT ON COLUMN outages.saifi_contribution IS 'System Average Interruption Frequency Index contribution';

-- Outage status history
CREATE TABLE outage_status_history (
    history_id SERIAL PRIMARY KEY,
    outage_id UUID NOT NULL REFERENCES outages(outage_id) ON DELETE CASCADE,
    old_status VARCHAR(30),
    new_status VARCHAR(30) NOT NULL,
    changed_by VARCHAR(100),
    notes TEXT,
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Outage updates (public communications)
CREATE TABLE outage_updates (
    update_id SERIAL PRIMARY KEY,
    outage_id UUID NOT NULL REFERENCES outages(outage_id) ON DELETE CASCADE,
    update_type VARCHAR(30) CHECK (update_type IN ('initial', 'progress', 'eta_update', 'restored', 'closed')),
    message TEXT NOT NULL,
    estimated_restore_at TIMESTAMPTZ,
    is_public BOOLEAN DEFAULT true,
    created_by VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Crew dispatches
CREATE TABLE crew_dispatches (
    dispatch_id SERIAL PRIMARY KEY,
    outage_id UUID NOT NULL REFERENCES outages(outage_id) ON DELETE CASCADE,
    crew_id INTEGER NOT NULL REFERENCES crews(crew_id),
    dispatched_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    acknowledged_at TIMESTAMPTZ,
    en_route_at TIMESTAMPTZ,
    arrived_at TIMESTAMPTZ,
    work_started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    travel_distance_km NUMERIC(8, 2),
    notes TEXT
);

COMMENT ON TABLE crew_dispatches IS 'Crew assignments and response tracking for outages';

-- ============================================================================
-- Analytics Tables
-- ============================================================================

-- Daily aggregated statistics
CREATE TABLE daily_outage_statistics (
    stat_date DATE PRIMARY KEY,
    total_outages INTEGER DEFAULT 0,
    planned_outages INTEGER DEFAULT 0,
    unplanned_outages INTEGER DEFAULT 0,
    total_customers_affected INTEGER DEFAULT 0,
    total_duration_minutes INTEGER DEFAULT 0,
    avg_duration_minutes NUMERIC(8, 2),
    saidi NUMERIC(10, 4),
    saifi NUMERIC(8, 6),
    weather_related INTEGER DEFAULT 0,
    equipment_related INTEGER DEFAULT 0,
    worst_district_id INTEGER REFERENCES districts(district_id),
    calculated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Cluster analysis results (refreshed periodically)
CREATE TABLE outage_clusters (
    cluster_id SERIAL PRIMARY KEY,
    analysis_date DATE NOT NULL,
    analysis_type VARCHAR(30) NOT NULL CHECK (analysis_type IN ('kmeans', 'dbscan', 'hierarchical')),
    cluster_number INTEGER NOT NULL,
    centroid GEOGRAPHY(POINT, 4326),
    boundary GEOMETRY(POLYGON, 4326),
    outage_count INTEGER NOT NULL,
    avg_duration_minutes NUMERIC(8, 2),
    total_customers_affected INTEGER,
    primary_cause_id INTEGER REFERENCES outage_causes(cause_id),
    risk_score NUMERIC(5, 2),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(analysis_date, analysis_type, cluster_number)
);

COMMENT ON TABLE outage_clusters IS 'Pre-computed spatial clusters for hotspot analysis';

-- Infrastructure risk scores
CREATE TABLE infrastructure_risk_scores (
    score_id SERIAL PRIMARY KEY,
    assessment_date DATE NOT NULL,
    entity_type VARCHAR(30) NOT NULL CHECK (entity_type IN ('transformer', 'line', 'substation')),
    entity_id INTEGER NOT NULL,
    location GEOGRAPHY(POINT, 4326),
    nearby_outages_90d INTEGER,
    nearby_outages_1y INTEGER,
    failure_probability NUMERIC(5, 4),
    risk_score NUMERIC(5, 2),
    risk_level VARCHAR(20) CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
    recommended_action TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE infrastructure_risk_scores IS 'Risk assessments for infrastructure components';

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
