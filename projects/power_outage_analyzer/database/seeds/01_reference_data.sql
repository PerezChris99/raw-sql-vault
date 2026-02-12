-- ============================================================================
-- Power Outage Pattern Analyzer - Reference Data
-- Basic lookup tables and initial configuration
-- ============================================================================

-- ============================================================================
-- Outage Causes
-- ============================================================================

INSERT INTO outage_causes (name, category, is_preventable, typical_repair_hours, description) VALUES
-- Weather-related
('Lightning Strike', 'weather', false, 2.0, 'Direct lightning damage to equipment'),
('High Winds', 'weather', false, 3.0, 'Wind damage causing line breaks or debris contact'),
('Ice/Snow Accumulation', 'weather', false, 4.0, 'Ice loading on lines causing sag or breaks'),
('Flooding', 'weather', false, 8.0, 'Substation or equipment flooding'),
('Tornado', 'weather', false, 12.0, 'Severe wind damage from tornado'),
('Hurricane/Typhoon', 'weather', false, 24.0, 'Extensive damage from tropical storm'),
('Heat Wave', 'weather', false, 1.0, 'Overload due to increased cooling demand'),

-- Equipment failures
('Transformer Failure', 'equipment', true, 4.0, 'Distribution transformer malfunction'),
('Cable Fault', 'equipment', true, 3.0, 'Underground cable deterioration or damage'),
('Switch/Breaker Failure', 'equipment', true, 2.0, 'Switching equipment malfunction'),
('Insulator Failure', 'equipment', true, 2.5, 'Porcelain or polymer insulator breakdown'),
('Conductor Break', 'equipment', true, 3.5, 'Power line conductor failure'),
('Pole Failure', 'equipment', true, 4.0, 'Utility pole collapse or damage'),
('Fuse Blown', 'equipment', true, 0.5, 'Protective fuse operation'),
('Relay Malfunction', 'equipment', true, 1.5, 'Protective relay failure'),

-- Vegetation
('Tree Contact', 'vegetation', true, 2.0, 'Tree branch touching power line'),
('Tree Fall', 'vegetation', true, 3.0, 'Fallen tree on power line'),
('Vegetation Growth', 'vegetation', true, 1.5, 'Vegetation encroachment causing fault'),

-- Animal
('Bird Contact', 'animal', false, 1.0, 'Bird causing phase-to-phase fault'),
('Squirrel Contact', 'animal', false, 0.5, 'Squirrel contact with equipment'),
('Snake Contact', 'animal', false, 0.5, 'Snake entry into equipment'),
('Large Animal Contact', 'animal', false, 2.0, 'Vehicle or large animal pole collision'),

-- Vehicle/External
('Vehicle Accident', 'vehicle', false, 3.0, 'Vehicle collision with utility pole'),
('Construction Damage', 'human', true, 2.5, 'Dig-in or construction equipment contact'),
('Vandalism', 'human', false, 3.0, 'Intentional damage to equipment'),

-- Overload
('System Overload', 'overload', true, 1.0, 'Demand exceeding capacity'),
('Equipment Overload', 'overload', true, 1.5, 'Specific equipment capacity exceeded'),

-- Unknown
('Under Investigation', 'unknown', false, 2.0, 'Cause not yet determined'),
('Unknown/Other', 'unknown', false, 2.0, 'Unable to determine cause');

-- ============================================================================
-- Weather Conditions
-- ============================================================================

INSERT INTO weather_conditions (name, severity_level, causes_outages) VALUES
('Clear', 1, false),
('Partly Cloudy', 1, false),
('Cloudy', 2, false),
('Light Rain', 2, false),
('Heavy Rain', 3, true),
('Thunderstorm', 4, true),
('Severe Thunderstorm', 5, true),
('Light Snow', 2, false),
('Heavy Snow', 4, true),
('Blizzard', 5, true),
('Ice Storm', 5, true),
('Freezing Rain', 5, true),
('High Winds', 4, true),
('Extreme Heat', 4, true),
('Extreme Cold', 4, true),
('Fog', 2, false),
('Tornado Warning', 5, true),
('Hurricane/Tropical Storm', 5, true);

-- ============================================================================
-- Regions (Example: Fictional Power Grid Area)
-- ============================================================================

INSERT INTO regions (name, code, boundary, population) VALUES
('North Metro Region', 'NMR', 
 ST_GeomFromText('POLYGON((-122.5 37.9, -122.0 37.9, -122.0 37.6, -122.5 37.6, -122.5 37.9))', 4326),
 450000),
('South Metro Region', 'SMR', 
 ST_GeomFromText('POLYGON((-122.5 37.6, -122.0 37.6, -122.0 37.3, -122.5 37.3, -122.5 37.6))', 4326),
 380000),
('East Valley Region', 'EVR', 
 ST_GeomFromText('POLYGON((-122.0 37.8, -121.6 37.8, -121.6 37.4, -122.0 37.4, -122.0 37.8))', 4326),
 290000),
('West Coast Region', 'WCR', 
 ST_GeomFromText('POLYGON((-122.6 37.8, -122.5 37.8, -122.5 37.4, -122.6 37.4, -122.6 37.8))', 4326),
 195000);

-- ============================================================================
-- Districts
-- ============================================================================

INSERT INTO districts (region_id, name, code, boundary, population, area_sq_km, grid_zone) VALUES
-- North Metro Region districts
(1, 'Downtown Core', 'NMR-DC', 
 ST_GeomFromText('POLYGON((-122.42 37.79, -122.38 37.79, -122.38 37.76, -122.42 37.76, -122.42 37.79))', 4326),
 85000, 12.5, 'GRID-N1'),
(1, 'Financial District', 'NMR-FD', 
 ST_GeomFromText('POLYGON((-122.40 37.795, -122.38 37.795, -122.38 37.785, -122.40 37.785, -122.40 37.795))', 4326),
 42000, 4.2, 'GRID-N1'),
(1, 'Northside Heights', 'NMR-NH', 
 ST_GeomFromText('POLYGON((-122.45 37.88, -122.40 37.88, -122.40 37.82, -122.45 37.82, -122.45 37.88))', 4326),
 78000, 28.5, 'GRID-N2'),
(1, 'Harbor Point', 'NMR-HP', 
 ST_GeomFromText('POLYGON((-122.50 37.82, -122.45 37.82, -122.45 37.78, -122.50 37.78, -122.50 37.82))', 4326),
 55000, 18.3, 'GRID-N3'),

-- South Metro Region districts
(2, 'Industrial Park', 'SMR-IP', 
 ST_GeomFromText('POLYGON((-122.45 37.55, -122.38 37.55, -122.38 37.48, -122.45 37.48, -122.45 37.55))', 4326),
 32000, 42.0, 'GRID-S1'),
(2, 'South Central', 'SMR-SC', 
 ST_GeomFromText('POLYGON((-122.42 37.58, -122.35 37.58, -122.35 37.52, -122.42 37.52, -122.42 37.58))', 4326),
 95000, 24.6, 'GRID-S1'),
(2, 'Riverside', 'SMR-RS', 
 ST_GeomFromText('POLYGON((-122.48 37.45, -122.40 37.45, -122.40 37.38, -122.48 37.38, -122.48 37.45))', 4326),
 68000, 35.2, 'GRID-S2'),
(2, 'South Shore', 'SMR-SS', 
 ST_GeomFromText('POLYGON((-122.50 37.52, -122.45 37.52, -122.45 37.45, -122.50 37.45, -122.50 37.52))', 4326),
 48000, 22.1, 'GRID-S3'),

-- East Valley Region districts
(3, 'Valley Center', 'EVR-VC', 
 ST_GeomFromText('POLYGON((-121.95 37.72, -121.85 37.72, -121.85 37.62, -121.95 37.62, -121.95 37.72))', 4326),
 72000, 55.8, 'GRID-E1'),
(3, 'East Hills', 'EVR-EH', 
 ST_GeomFromText('POLYGON((-121.85 37.78, -121.70 37.78, -121.70 37.65, -121.85 37.65, -121.85 37.78))', 4326),
 45000, 88.3, 'GRID-E2'),
(3, 'Lakeview', 'EVR-LV', 
 ST_GeomFromText('POLYGON((-121.92 37.58, -121.80 37.58, -121.80 37.48, -121.92 37.48, -121.92 37.58))', 4326),
 58000, 62.4, 'GRID-E3'),

-- West Coast Region districts
(4, 'Ocean View', 'WCR-OV', 
 ST_GeomFromText('POLYGON((-122.58 37.75, -122.52 37.75, -122.52 37.65, -122.58 37.65, -122.58 37.75))', 4326),
 42000, 38.5, 'GRID-W1'),
(4, 'Coastal Heights', 'WCR-CH', 
 ST_GeomFromText('POLYGON((-122.58 37.65, -122.52 37.65, -122.52 37.55, -122.58 37.55, -122.58 37.65))', 4326),
 35000, 42.2, 'GRID-W2'),
(4, 'Beach District', 'WCR-BD', 
 ST_GeomFromText('POLYGON((-122.56 37.55, -122.50 37.55, -122.50 37.45, -122.56 37.45, -122.56 37.55))', 4326),
 28000, 35.8, 'GRID-W3');

-- ============================================================================
-- Crews
-- ============================================================================

INSERT INTO crews (name, base_location, specialization, member_count, status, current_location) VALUES
('Alpha Team', ST_GeogFromText('POINT(-122.40 37.78)'), 'emergency', 4, 'available', ST_GeogFromText('POINT(-122.40 37.78)')),
('Bravo Team', ST_GeogFromText('POINT(-122.42 37.55)'), 'distribution', 3, 'available', ST_GeogFromText('POINT(-122.42 37.55)')),
('Charlie Team', ST_GeogFromText('POINT(-121.88 37.68)'), 'distribution', 3, 'available', ST_GeogFromText('POINT(-121.88 37.68)')),
('Delta Team', ST_GeogFromText('POINT(-122.55 37.60)'), 'emergency', 4, 'available', ST_GeogFromText('POINT(-122.55 37.60)')),
('Echo Team', ST_GeogFromText('POINT(-122.38 37.82)'), 'transmission', 4, 'available', ST_GeogFromText('POINT(-122.38 37.82)')),
('Foxtrot Team', ST_GeogFromText('POINT(-122.45 37.48)'), 'distribution', 3, 'standby', NULL),
('Golf Team', ST_GeogFromText('POINT(-121.75 37.72)'), 'general', 3, 'available', ST_GeogFromText('POINT(-121.75 37.72)')),
('Hotel Team', ST_GeogFromText('POINT(-122.48 37.68)'), 'vegetation', 4, 'available', ST_GeogFromText('POINT(-122.48 37.68)'));
