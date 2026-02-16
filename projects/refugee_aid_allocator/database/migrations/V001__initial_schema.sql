-- ============================================================================
-- Refugee Aid Allocator - Initial Schema
-- PostgreSQL 14+ (Compatible with MySQL/SQL Server)
-- Migration: V001 - Core tables for refugee aid management
-- ============================================================================

-- ============================================================================
-- Reference Tables
-- ============================================================================

-- Camps table
CREATE TABLE IF NOT EXISTS camps (
    camp_id SERIAL PRIMARY KEY,
    camp_name VARCHAR(100) NOT NULL UNIQUE,
    country VARCHAR(50) NOT NULL DEFAULT 'Uganda',
    district VARCHAR(100) NOT NULL,
    location_desc TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    capacity INT NOT NULL,
    current_population INT DEFAULT 0,
    established_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'closed', 'temporary')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Aid categories
CREATE TABLE IF NOT EXISTS aid_categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    category_code VARCHAR(10) NOT NULL UNIQUE,
    unit_of_measure VARCHAR(20) NOT NULL,
    priority_weight DECIMAL(3,2) DEFAULT 1.00,
    description TEXT,
    is_recurring BOOLEAN DEFAULT FALSE,
    recurrence_days INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Households
CREATE TABLE IF NOT EXISTS households (
    household_id SERIAL PRIMARY KEY,
    camp_id INT NOT NULL REFERENCES camps(camp_id),
    household_code VARCHAR(20) NOT NULL UNIQUE,
    head_name VARCHAR(100),
    size INT NOT NULL DEFAULT 1,
    shelter_type VARCHAR(30) CHECK (shelter_type IN ('tent', 'semi-permanent', 'permanent', 'transit')),
    has_special_needs BOOLEAN DEFAULT FALSE,
    special_needs_desc TEXT,
    registration_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'relocated', 'departed', 'deceased')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Refugees
CREATE TABLE IF NOT EXISTS refugees (
    refugee_id SERIAL PRIMARY KEY,
    household_id INT NOT NULL REFERENCES households(household_id),
    unhcr_id VARCHAR(20) UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    date_of_birth DATE,
    gender VARCHAR(10) CHECK (gender IN ('male', 'female', 'other')),
    nationality VARCHAR(50),
    arrival_date DATE NOT NULL,
    is_head_of_household BOOLEAN DEFAULT FALSE,
    vulnerability_score INT DEFAULT 0 CHECK (vulnerability_score BETWEEN 0 AND 100),
    
    -- Vulnerability flags
    is_unaccompanied_minor BOOLEAN DEFAULT FALSE,
    is_elderly BOOLEAN DEFAULT FALSE,
    is_pregnant_nursing BOOLEAN DEFAULT FALSE,
    is_disabled BOOLEAN DEFAULT FALSE,
    is_single_parent BOOLEAN DEFAULT FALSE,
    has_chronic_illness BOOLEAN DEFAULT FALSE,
    
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'relocated', 'resettled', 'departed', 'deceased')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- Needs Assessment Tables
-- ============================================================================

-- Urgency levels reference
CREATE TABLE IF NOT EXISTS urgency_levels (
    urgency_id SERIAL PRIMARY KEY,
    urgency_name VARCHAR(20) NOT NULL UNIQUE,
    urgency_score INT NOT NULL,
    description TEXT,
    response_sla_hours INT
);

-- Need assessments
CREATE TABLE IF NOT EXISTS needs (
    need_id SERIAL PRIMARY KEY,
    refugee_id INT NOT NULL REFERENCES refugees(refugee_id),
    category_id INT NOT NULL REFERENCES aid_categories(category_id),
    urgency_id INT NOT NULL REFERENCES urgency_levels(urgency_id),
    quantity_needed DECIMAL(10,2) NOT NULL DEFAULT 1,
    need_score DECIMAL(6,2) DEFAULT 0,
    assessed_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    assessed_by VARCHAR(100),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'partial', 'fulfilled', 'cancelled')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Prevent duplicate active needs
    UNIQUE (refugee_id, category_id, status)
);

-- ============================================================================
-- Allocation & Distribution Tables
-- ============================================================================

-- Aid inventory per camp
CREATE TABLE IF NOT EXISTS aid_inventory (
    inventory_id SERIAL PRIMARY KEY,
    camp_id INT NOT NULL REFERENCES camps(camp_id),
    category_id INT NOT NULL REFERENCES aid_categories(category_id),
    quantity_available DECIMAL(12,2) NOT NULL DEFAULT 0,
    quantity_reserved DECIMAL(12,2) NOT NULL DEFAULT 0,
    reorder_level DECIMAL(12,2),
    last_restock_date DATE,
    last_restock_quantity DECIMAL(12,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE (camp_id, category_id)
);

-- Allocations (planned distributions)
CREATE TABLE IF NOT EXISTS allocations (
    allocation_id SERIAL PRIMARY KEY,
    need_id INT NOT NULL REFERENCES needs(need_id),
    inventory_id INT NOT NULL REFERENCES aid_inventory(inventory_id),
    quantity_allocated DECIMAL(10,2) NOT NULL,
    allocated_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    allocated_by VARCHAR(100),
    priority_rank INT,
    scheduled_distribution DATE,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'ready', 'distributed', 'cancelled')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Distribution log (actual handouts)
CREATE TABLE IF NOT EXISTS distributions (
    distribution_id SERIAL PRIMARY KEY,
    allocation_id INT NOT NULL REFERENCES allocations(allocation_id),
    quantity_distributed DECIMAL(10,2) NOT NULL,
    distribution_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    distributed_by VARCHAR(100),
    received_by VARCHAR(100),
    signature_collected BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- Audit & History Tables
-- ============================================================================

-- Allocation history for tracking
CREATE TABLE IF NOT EXISTS allocation_history (
    history_id SERIAL PRIMARY KEY,
    allocation_id INT NOT NULL,
    action VARCHAR(20) NOT NULL,
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

-- ============================================================================
-- Indexes for Performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_refugees_household ON refugees(household_id);
CREATE INDEX IF NOT EXISTS idx_refugees_vulnerability ON refugees(vulnerability_score DESC);
CREATE INDEX IF NOT EXISTS idx_households_camp ON households(camp_id);
CREATE INDEX IF NOT EXISTS idx_needs_refugee ON needs(refugee_id);
CREATE INDEX IF NOT EXISTS idx_needs_category ON needs(category_id);
CREATE INDEX IF NOT EXISTS idx_needs_status ON needs(status);
CREATE INDEX IF NOT EXISTS idx_needs_score ON needs(need_score DESC);
CREATE INDEX IF NOT EXISTS idx_allocations_need ON allocations(need_id);
CREATE INDEX IF NOT EXISTS idx_allocations_status ON allocations(status);
CREATE INDEX IF NOT EXISTS idx_inventory_camp ON aid_inventory(camp_id);

-- ============================================================================
-- Comments
-- ============================================================================

COMMENT ON TABLE camps IS 'Refugee camp locations and capacity information';
COMMENT ON TABLE refugees IS 'Individual refugee records with vulnerability factors';
COMMENT ON TABLE needs IS 'Assessed aid needs per refugee with scoring';
COMMENT ON TABLE allocations IS 'Planned aid allocations ranked by priority';
COMMENT ON COLUMN needs.need_score IS 'Calculated score: urgency(35%) + vulnerability(25%) + household(20%) + wait(15%) + category(5%)';
