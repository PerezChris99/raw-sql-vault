-- ============================================================================
-- Waste Collection Optimizer - Initial Schema
-- PostgreSQL 14+
-- Migration: V001 - Core tables for waste collection management
-- ============================================================================

-- Zones (areas of Kampala)
CREATE TABLE IF NOT EXISTS zones (
    zone_id SERIAL PRIMARY KEY,
    zone_name VARCHAR(100) NOT NULL UNIQUE,
    division VARCHAR(50) NOT NULL,
    area_sqkm DECIMAL(10,2),
    population INT,
    households INT,
    status VARCHAR(20) DEFAULT 'active'
);

-- Trucks
CREATE TABLE IF NOT EXISTS trucks (
    truck_id SERIAL PRIMARY KEY,
    plate_number VARCHAR(20) NOT NULL UNIQUE,
    model VARCHAR(100),
    capacity_kg INT NOT NULL,
    capacity_liters INT NOT NULL,
    fuel_type VARCHAR(20) DEFAULT 'diesel',
    status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'in_use', 'maintenance', 'retired'))
);

-- Routes
CREATE TABLE IF NOT EXISTS routes (
    route_id SERIAL PRIMARY KEY,
    zone_id INT REFERENCES zones(zone_id),
    route_name VARCHAR(100) NOT NULL,
    route_code VARCHAR(20) UNIQUE,
    distance_km DECIMAL(6,2),
    estimated_duration_mins INT,
    schedule_days VARCHAR(50), -- 'Mon,Wed,Fri'
    truck_id INT REFERENCES trucks(truck_id),
    status VARCHAR(20) DEFAULT 'active'
);

-- Bins
CREATE TABLE IF NOT EXISTS bins (
    bin_id SERIAL PRIMARY KEY,
    route_id INT REFERENCES routes(route_id),
    bin_code VARCHAR(20) UNIQUE,
    location_desc VARCHAR(200),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    capacity_liters INT NOT NULL DEFAULT 1100,
    bin_type VARCHAR(30) DEFAULT 'general' CHECK (bin_type IN ('general', 'recyclable', 'organic', 'hazardous')),
    current_level INT DEFAULT 0 CHECK (current_level BETWEEN 0 AND 100),
    last_emptied TIMESTAMP,
    installed_date DATE,
    status VARCHAR(20) DEFAULT 'active'
);

-- Bin level readings (IoT sensor data)
CREATE TABLE IF NOT EXISTS bin_readings (
    reading_id SERIAL PRIMARY KEY,
    bin_id INT NOT NULL REFERENCES bins(bin_id),
    level_pct INT NOT NULL CHECK (level_pct BETWEEN 0 AND 100),
    temperature DECIMAL(4,1),
    battery_pct INT,
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Collections (actual pickups)
CREATE TABLE IF NOT EXISTS collections (
    collection_id SERIAL PRIMARY KEY,
    bin_id INT NOT NULL REFERENCES bins(bin_id),
    truck_id INT REFERENCES trucks(truck_id),
    route_id INT REFERENCES routes(route_id),
    collected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    level_before INT,
    weight_kg DECIMAL(8,2),
    collector_name VARCHAR(100),
    notes TEXT
);

-- Daily route plans
CREATE TABLE IF NOT EXISTS route_plans (
    plan_id SERIAL PRIMARY KEY,
    route_id INT NOT NULL REFERENCES routes(route_id),
    plan_date DATE NOT NULL,
    truck_id INT REFERENCES trucks(truck_id),
    status VARCHAR(20) DEFAULT 'planned' CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    bins_collected INT DEFAULT 0,
    total_weight_kg DECIMAL(10,2),
    distance_actual_km DECIMAL(6,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (route_id, plan_date)
);

-- Indexes
CREATE INDEX idx_bins_route ON bins(route_id);
CREATE INDEX idx_bins_level ON bins(current_level DESC);
CREATE INDEX idx_readings_bin ON bin_readings(bin_id, recorded_at DESC);
CREATE INDEX idx_collections_bin ON collections(bin_id, collected_at DESC);
CREATE INDEX idx_route_plans_date ON route_plans(plan_date);

COMMENT ON TABLE bins IS 'Waste collection bins with IoT level sensors';
COMMENT ON COLUMN bins.current_level IS 'Current fill level percentage (0-100)';
