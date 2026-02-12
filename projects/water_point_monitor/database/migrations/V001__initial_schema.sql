-- ============================================================================
-- Water Point Usage Monitor - V001 Initial Schema
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Base tables for borehole monitoring
-- ============================================================================

-- ============================================================================
-- Enable Required Extensions
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- Reference Tables
-- ============================================================================

-- Regions / Geographic areas
CREATE TABLE regions (
    region_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20) UNIQUE NOT NULL,
    country VARCHAR(100) NOT NULL DEFAULT 'Kenya',
    climate_zone VARCHAR(50),  -- arid, semi-arid, tropical, etc.
    avg_rainfall_mm INTEGER,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_regions_country ON regions(country);

COMMENT ON TABLE regions IS 'Geographic regions containing water points';

-- Borehole types
CREATE TABLE borehole_types (
    type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    min_depth_m INTEGER,
    max_depth_m INTEGER,
    typical_yield_lpm NUMERIC(8,2),  -- liters per minute
    pump_types TEXT[],  -- Compatible pump types
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE borehole_types IS 'Classification of borehole types';

-- Pump types reference
CREATE TABLE pump_types (
    pump_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL,  -- submersible, hand, solar, etc.
    max_head_m INTEGER,  -- Maximum pumping depth
    max_flow_lpm NUMERIC(8,2),
    power_source VARCHAR(50),  -- electric, solar, manual, hybrid
    typical_lifespan_years INTEGER,
    maintenance_interval_days INTEGER,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE pump_types IS 'Pump type specifications';

-- Alert types
CREATE TABLE alert_types (
    alert_type_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    severity VARCHAR(20) NOT NULL DEFAULT 'warning',
    threshold_value NUMERIC(10,2),
    risk_weight NUMERIC(4,2) DEFAULT 0.10,
    response_sla_hours INTEGER DEFAULT 24,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_alert_severity CHECK (severity IN ('info', 'warning', 'critical', 'emergency'))
);

COMMENT ON TABLE alert_types IS 'Types of breakdown/anomaly alerts';

-- ============================================================================
-- Core Tables
-- ============================================================================

-- Boreholes (Water Points)
CREATE TABLE boreholes (
    borehole_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    
    -- Location
    region_id UUID REFERENCES regions(region_id),
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),
    altitude_m INTEGER,
    village VARCHAR(200),
    ward VARCHAR(100),
    
    -- Classification
    type_id UUID REFERENCES borehole_types(type_id),
    pump_type_id UUID REFERENCES pump_types(pump_type_id),
    
    -- Technical specs
    depth_m NUMERIC(8,2),
    casing_diameter_mm INTEGER,
    yield_lpm NUMERIC(8,2),  -- Design/test yield
    static_water_level_m NUMERIC(8,2),
    dynamic_water_level_m NUMERIC(8,2),
    
    -- Operational
    installation_date DATE,
    commissioning_date DATE,
    last_maintenance_date DATE,
    next_maintenance_date DATE,
    
    -- Usage
    population_served INTEGER,
    households_served INTEGER,
    usage_hours_per_day NUMERIC(4,2) DEFAULT 8,
    
    -- Status
    status VARCHAR(50) DEFAULT 'operational',
    health_score NUMERIC(5,2) DEFAULT 100.00,  -- 0-100
    last_health_check TIMESTAMPTZ,
    
    -- Metadata
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_borehole_status CHECK (
        status IN ('operational', 'degraded', 'maintenance', 'offline', 'decommissioned')
    ),
    CONSTRAINT chk_health_score CHECK (health_score BETWEEN 0 AND 100)
);

CREATE INDEX idx_boreholes_region ON boreholes(region_id);
CREATE INDEX idx_boreholes_status ON boreholes(status);
CREATE INDEX idx_boreholes_health ON boreholes(health_score);
CREATE INDEX idx_boreholes_maintenance ON boreholes(next_maintenance_date);

COMMENT ON TABLE boreholes IS 'Water point/borehole master data';

-- ============================================================================
-- Usage Logs (Will become Hypertable)
-- ============================================================================

CREATE TABLE usage_logs (
    logged_at TIMESTAMPTZ NOT NULL,
    borehole_id UUID NOT NULL REFERENCES boreholes(borehole_id),
    
    -- Usage metrics
    usage_liters NUMERIC(12,2),          -- Total liters this reading
    flow_rate_lpm NUMERIC(8,2),          -- Liters per minute
    
    -- Pump metrics
    pump_runtime_sec INTEGER DEFAULT 0,   -- Seconds pump ran
    pump_cycles INTEGER DEFAULT 0,        -- Number of on/off cycles
    pump_status VARCHAR(20) DEFAULT 'unknown',
    
    -- Environmental
    pressure_bar NUMERIC(6,3),           -- System pressure
    voltage NUMERIC(6,2),                -- Power supply voltage
    temperature_c NUMERIC(5,2),          -- Water temperature
    
    -- Data source
    source VARCHAR(50) DEFAULT 'sensor', -- sensor, manual, estimated
    reading_quality VARCHAR(20) DEFAULT 'normal', -- normal, interpolated, suspect
    
    -- Metadata
    raw_payload JSONB,                   -- Original sensor data
    
    CONSTRAINT pk_usage_logs PRIMARY KEY (logged_at, borehole_id),
    CONSTRAINT chk_pump_status CHECK (
        pump_status IN ('running', 'stopped', 'error', 'unknown')
    )
);

-- Note: Additional indexes created after hypertable conversion
COMMENT ON TABLE usage_logs IS 'Time-series usage data - converted to TimescaleDB hypertable';

-- ============================================================================
-- Maintenance Logs
-- ============================================================================

CREATE TABLE maintenance_logs (
    maintenance_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    borehole_id UUID NOT NULL REFERENCES boreholes(borehole_id),
    
    -- Scheduling
    scheduled_date DATE,
    completed_date DATE,
    work_type VARCHAR(100) NOT NULL,  -- preventive, corrective, emergency
    
    -- Details
    technician_name VARCHAR(200),
    findings TEXT,
    work_performed TEXT,
    parts_replaced TEXT[],
    cost_estimate NUMERIC(12,2),
    actual_cost NUMERIC(12,2),
    
    -- Outcome
    status VARCHAR(50) DEFAULT 'scheduled',
    health_before NUMERIC(5,2),
    health_after NUMERIC(5,2),
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_maintenance_status CHECK (
        status IN ('scheduled', 'in_progress', 'completed', 'cancelled', 'deferred')
    )
);

CREATE INDEX idx_maintenance_borehole ON maintenance_logs(borehole_id);
CREATE INDEX idx_maintenance_date ON maintenance_logs(scheduled_date);
CREATE INDEX idx_maintenance_status ON maintenance_logs(status);

COMMENT ON TABLE maintenance_logs IS 'Maintenance work records';

-- ============================================================================
-- Breakdown Alerts
-- ============================================================================

CREATE TABLE breakdown_alerts (
    alert_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    borehole_id UUID NOT NULL REFERENCES boreholes(borehole_id),
    alert_type_id UUID REFERENCES alert_types(alert_type_id),
    
    -- Detection
    detected_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    detection_method VARCHAR(100),  -- automated, manual, scheduled
    
    -- Risk assessment
    risk_score NUMERIC(5,2) NOT NULL,  -- 0-100
    severity VARCHAR(20) NOT NULL,
    
    -- Indicators (JSONB for flexibility)
    indicators JSONB,
    /*
    Example:
    {
        "usage_drop_pct": 45.2,
        "flow_degradation": 0.7,
        "pump_cycles_per_hour": 12,
        "pressure_anomaly": true,
        "runtime_increase_pct": 25
    }
    */
    
    -- Response
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMPTZ,
    acknowledged_by VARCHAR(200),
    
    -- Resolution
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    maintenance_id UUID REFERENCES maintenance_logs(maintenance_id),
    
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_alert_severity CHECK (
        severity IN ('info', 'warning', 'critical', 'emergency')
    ),
    CONSTRAINT chk_risk_score CHECK (risk_score BETWEEN 0 AND 100)
);

CREATE INDEX idx_alerts_borehole ON breakdown_alerts(borehole_id);
CREATE INDEX idx_alerts_detected ON breakdown_alerts(detected_at DESC);
CREATE INDEX idx_alerts_unresolved ON breakdown_alerts(resolved, severity) 
    WHERE resolved = FALSE;
CREATE INDEX idx_alerts_risk ON breakdown_alerts(risk_score DESC) 
    WHERE resolved = FALSE;

COMMENT ON TABLE breakdown_alerts IS 'Anomaly and breakdown risk alerts';

-- ============================================================================
-- Health Score History
-- ============================================================================

CREATE TABLE health_score_history (
    recorded_at TIMESTAMPTZ NOT NULL,
    borehole_id UUID NOT NULL REFERENCES boreholes(borehole_id),
    health_score NUMERIC(5,2) NOT NULL,
    
    -- Component scores
    usage_score NUMERIC(5,2),
    flow_score NUMERIC(5,2),
    pressure_score NUMERIC(5,2),
    pump_score NUMERIC(5,2),
    
    -- Change tracking
    score_change NUMERIC(5,2),
    trend VARCHAR(20),  -- improving, stable, declining
    
    PRIMARY KEY (recorded_at, borehole_id)
);

COMMENT ON TABLE health_score_history IS 'Daily health score snapshots';

-- ============================================================================
-- Triggers for Updated Timestamps
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_boreholes_updated 
    BEFORE UPDATE ON boreholes
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_maintenance_updated 
    BEFORE UPDATE ON maintenance_logs
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

CREATE TRIGGER trg_regions_updated 
    BEFORE UPDATE ON regions
    FOR EACH ROW EXECUTE FUNCTION fn_update_timestamp();

-- ============================================================================
-- Verification
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'V001 Schema created successfully';
    RAISE NOTICE 'Tables: regions, borehole_types, pump_types, alert_types, boreholes, usage_logs, maintenance_logs, breakdown_alerts, health_score_history';
END $$;
