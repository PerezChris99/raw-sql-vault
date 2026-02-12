-- ============================================================================
-- Water Point Usage Monitor - Reference Data
-- PostgreSQL 14+ with TimescaleDB 2.x
-- Static reference data for borehole monitoring
-- ============================================================================

-- ============================================================================
-- Regions
-- ============================================================================

INSERT INTO regions (name, code, country, climate_zone, avg_rainfall_mm, notes)
VALUES
    ('Turkana County', 'TUR', 'Kenya', 'arid', 200, 'Northern Kenya, severe water scarcity'),
    ('Marsabit County', 'MAR', 'Kenya', 'arid', 250, 'Northern Kenya, nomadic communities'),
    ('Garissa County', 'GAR', 'Kenya', 'semi-arid', 350, 'Eastern Kenya, Tana River basin'),
    ('Kitui County', 'KIT', 'Kenya', 'semi-arid', 500, 'Eastern Kenya, prone to drought'),
    ('Machakos County', 'MAC', 'Kenya', 'semi-arid', 600, 'Central-Eastern Kenya'),
    ('Kajiado County', 'KAJ', 'Kenya', 'semi-arid', 550, 'Southern Kenya, Maasai communities'),
    ('Nakuru County', 'NAK', 'Kenya', 'tropical', 850, 'Rift Valley, mixed farming'),
    ('Kwale County', 'KWA', 'Kenya', 'tropical', 1100, 'Coastal Kenya, high water table')
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    climate_zone = EXCLUDED.climate_zone,
    avg_rainfall_mm = EXCLUDED.avg_rainfall_mm;

-- ============================================================================
-- Borehole Types
-- ============================================================================

INSERT INTO borehole_types (name, description, min_depth_m, max_depth_m, typical_yield_lpm, pump_types)
VALUES
    ('Shallow Well', 'Hand-dug or drilled well <30m', 5, 30, 15.0, ARRAY['hand_pump', 'solar_submersible']),
    ('Medium Depth', 'Drilled borehole 30-100m', 30, 100, 40.0, ARRAY['solar_submersible', 'electric_submersible']),
    ('Deep Borehole', 'Deep drilled borehole >100m', 100, 300, 80.0, ARRAY['electric_submersible', 'diesel_submersible']),
    ('Artesian Well', 'Self-flowing from confined aquifer', 50, 200, 60.0, ARRAY['none', 'flow_control']),
    ('Sand Dam Well', 'Well accessing sand dam storage', 3, 15, 10.0, ARRAY['hand_pump', 'solar_submersible'])
ON CONFLICT (name) DO UPDATE SET
    description = EXCLUDED.description,
    min_depth_m = EXCLUDED.min_depth_m,
    max_depth_m = EXCLUDED.max_depth_m,
    typical_yield_lpm = EXCLUDED.typical_yield_lpm;

-- ============================================================================
-- Pump Types
-- ============================================================================

INSERT INTO pump_types (name, category, max_head_m, max_flow_lpm, power_source, typical_lifespan_years, maintenance_interval_days)
VALUES
    ('Afridev Hand Pump', 'hand', 45, 15, 'manual', 15, 90),
    ('India Mark II', 'hand', 50, 12, 'manual', 20, 120),
    ('Grundfos SQFlex', 'submersible', 120, 80, 'solar', 10, 180),
    ('Lorentz PS2-600', 'submersible', 70, 60, 'solar', 12, 180),
    ('Dayliff Sunverter', 'submersible', 100, 50, 'solar', 8, 150),
    ('Pedrollo 4SR', 'submersible', 150, 100, 'electric', 8, 90),
    ('Grundfos SP', 'submersible', 200, 150, 'electric', 15, 120),
    ('Kirloskar KU4', 'submersible', 180, 120, 'electric', 10, 90),
    ('Honda WB30', 'surface', 30, 1100, 'diesel', 5, 30),
    ('Robin PTG307', 'surface', 35, 800, 'diesel', 6, 30)
ON CONFLICT (name) DO UPDATE SET
    category = EXCLUDED.category,
    max_head_m = EXCLUDED.max_head_m,
    max_flow_lpm = EXCLUDED.max_flow_lpm,
    power_source = EXCLUDED.power_source,
    maintenance_interval_days = EXCLUDED.maintenance_interval_days;

-- ============================================================================
-- Alert Types
-- ============================================================================

INSERT INTO alert_types (code, name, description, severity, threshold_value, risk_weight, response_sla_hours)
VALUES
    ('USAGE_DROP', 'Usage Drop', 'Daily usage dropped >30% below 7-day average', 'warning', 30.0, 0.40, 24),
    ('USAGE_CRITICAL', 'Critical Usage Drop', 'Daily usage dropped >50% below average', 'critical', 50.0, 0.60, 12),
    ('FLOW_DEGRADED', 'Flow Rate Degradation', 'Flow rate below 60% of design yield', 'warning', 60.0, 0.30, 48),
    ('FLOW_CRITICAL', 'Critical Flow Rate', 'Flow rate below 40% of design yield', 'critical', 40.0, 0.50, 24),
    ('PUMP_CYCLING', 'Excessive Pump Cycling', 'More than 10 pump cycles per hour', 'warning', 10.0, 0.15, 72),
    ('PRESSURE_LOW', 'Low Pressure', 'System pressure below 1.5 bar', 'warning', 1.5, 0.10, 48),
    ('PRESSURE_HIGH', 'High Pressure', 'System pressure above 5 bar', 'warning', 5.0, 0.10, 48),
    ('VOLTAGE_LOW', 'Low Voltage', 'Power supply voltage below threshold', 'info', 10.0, 0.05, 72),
    ('MAINTENANCE_DUE', 'Maintenance Due', 'Scheduled maintenance overdue', 'info', NULL, 0.10, 168),
    ('OFFLINE', 'System Offline', 'No data received for >4 hours', 'critical', 4.0, 0.70, 8),
    ('BREAKDOWN', 'Breakdown Detected', 'Multiple indicators suggest breakdown', 'emergency', 80.0, 1.00, 4)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    severity = EXCLUDED.severity,
    threshold_value = EXCLUDED.threshold_value,
    risk_weight = EXCLUDED.risk_weight,
    response_sla_hours = EXCLUDED.response_sla_hours;

-- ============================================================================
-- Sample Boreholes
-- ============================================================================

DO $$
DECLARE
    v_turkana_id UUID;
    v_marsabit_id UUID;
    v_kitui_id UUID;
    v_nakuru_id UUID;
    v_medium_type_id UUID;
    v_deep_type_id UUID;
    v_shallow_type_id UUID;
    v_grundfos_id UUID;
    v_lorentz_id UUID;
    v_afridev_id UUID;
BEGIN
    -- Get region IDs
    SELECT region_id INTO v_turkana_id FROM regions WHERE code = 'TUR';
    SELECT region_id INTO v_marsabit_id FROM regions WHERE code = 'MAR';
    SELECT region_id INTO v_kitui_id FROM regions WHERE code = 'KIT';
    SELECT region_id INTO v_nakuru_id FROM regions WHERE code = 'NAK';
    
    -- Get type IDs
    SELECT type_id INTO v_medium_type_id FROM borehole_types WHERE name = 'Medium Depth';
    SELECT type_id INTO v_deep_type_id FROM borehole_types WHERE name = 'Deep Borehole';
    SELECT type_id INTO v_shallow_type_id FROM borehole_types WHERE name = 'Shallow Well';
    
    -- Get pump IDs
    SELECT pump_type_id INTO v_grundfos_id FROM pump_types WHERE name = 'Grundfos SQFlex';
    SELECT pump_type_id INTO v_lorentz_id FROM pump_types WHERE name = 'Lorentz PS2-600';
    SELECT pump_type_id INTO v_afridev_id FROM pump_types WHERE name = 'Afridev Hand Pump';

    -- Insert boreholes with various statuses
    INSERT INTO boreholes (
        name, code, region_id, latitude, longitude, village,
        type_id, pump_type_id, depth_m, yield_lpm, static_water_level_m,
        installation_date, last_maintenance_date, next_maintenance_date,
        population_served, households_served, status, health_score
    )
    VALUES
    -- Operational boreholes (good health)
    ('Lodwar Market BH1', 'TUR-LOD-001', v_turkana_id, 3.1156, 35.5960, 'Lodwar Town',
     v_medium_type_id, v_grundfos_id, 65, 50.0, 25.0,
     '2021-03-15', '2024-11-01', '2025-05-01',
     2500, 450, 'operational', 92.5),
    
    ('Kakuma Camp BH2', 'TUR-KAK-002', v_turkana_id, 3.7208, 34.8542, 'Kakuma',
     v_deep_type_id, v_grundfos_id, 120, 80.0, 45.0,
     '2020-06-20', '2024-10-15', '2025-04-15',
     5000, 900, 'operational', 88.0),
    
    -- Degraded borehole (showing warning signs)
    ('Marsabit Town BH1', 'MAR-MTN-001', v_marsabit_id, 2.3384, 37.9891, 'Marsabit Town',
     v_medium_type_id, v_lorentz_id, 75, 45.0, 30.0,
     '2019-08-10', '2024-08-01', '2025-02-01',
     3500, 600, 'degraded', 62.0),
    
    -- At-risk borehole (high breakdown probability)
    ('Sololo Village BH1', 'MAR-SOL-002', v_marsabit_id, 3.5736, 38.3842, 'Sololo',
     v_shallow_type_id, v_afridev_id, 28, 12.0, 8.0,
     '2018-02-25', '2024-02-15', '2024-08-15',
     800, 120, 'degraded', 45.0),
    
    -- Kitui boreholes
    ('Kitui Central BH1', 'KIT-KCN-001', v_kitui_id, -1.3667, 38.0167, 'Kitui Town',
     v_medium_type_id, v_grundfos_id, 55, 40.0, 20.0,
     '2022-01-10', '2024-12-01', '2025-06-01',
     4000, 700, 'operational', 85.0),
    
    ('Mutomo Market BH1', 'KIT-MUT-002', v_kitui_id, -2.0833, 38.2000, 'Mutomo',
     v_medium_type_id, v_lorentz_id, 70, 35.0, 25.0,
     '2021-07-05', '2024-09-20', '2025-03-20',
     2000, 350, 'operational', 78.0),
    
    -- Nakuru boreholes (good rainfall area)
    ('Nakuru East BH1', 'NAK-EAS-001', v_nakuru_id, -0.2833, 36.0833, 'Nakuru East',
     v_deep_type_id, v_grundfos_id, 110, 100.0, 40.0,
     '2020-11-15', '2024-11-20', '2025-05-20',
     8000, 1500, 'operational', 95.0),
    
    -- Offline borehole (needs repair)
    ('Molo Town BH1', 'NAK-MOL-002', v_nakuru_id, -0.2500, 35.7333, 'Molo',
     v_medium_type_id, v_lorentz_id, 60, 50.0, 22.0,
     '2019-04-20', '2024-06-15', '2024-12-15',
     3000, 500, 'offline', 15.0);
END $$;

-- ============================================================================
-- Verify Reference Data
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE 'Reference data loaded:';
    RAISE NOTICE '  - Regions: %', (SELECT COUNT(*) FROM regions);
    RAISE NOTICE '  - Borehole types: %', (SELECT COUNT(*) FROM borehole_types);
    RAISE NOTICE '  - Pump types: %', (SELECT COUNT(*) FROM pump_types);
    RAISE NOTICE '  - Alert types: %', (SELECT COUNT(*) FROM alert_types);
    RAISE NOTICE '  - Boreholes: %', (SELECT COUNT(*) FROM boreholes);
END $$;
