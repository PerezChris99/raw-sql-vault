-- ============================================================================
-- Milk Supply Chain Auditor - Sample Data
-- PostgreSQL 14+
-- ============================================================================

-- Farmers
INSERT INTO farmers (farmer_code, farmer_name, district, sub_county, herd_size, certification_status, phone)
VALUES
('FRM-001', 'Mugisha Robert', 'Mbarara', 'Kashari', 25, 'certified', '+256777100001'),
('FRM-002', 'Akampurira Grace', 'Kiruhura', 'Sanga', 40, 'certified', '+256777100002'),
('FRM-003', 'Tumusiime John', 'Ntungamo', 'Ruhaama', 15, 'basic', '+256777100003'),
('FRM-004', 'Natukunda Mary', 'Isingiro', 'Ngarama', 30, 'certified', '+256777100004'),
('FRM-005', 'Byamugisha Peter', 'Bushenyi', 'Ishaka', 20, 'basic', '+256777100005'),
('FRM-006', 'Asiimwe Judith', 'Mbarara', 'Biharwe', 35, 'premium', '+256777100006');

-- Collection Centers
INSERT INTO collection_centers (center_code, center_name, district, cooling_capacity_liters, gps_latitude, gps_longitude)
VALUES
('CC-MBR-01', 'Mbarara Dairy Cooperative', 'Mbarara', 5000, -0.6065, 30.6576),
('CC-KRH-01', 'Kiruhura Farmers Hub', 'Kiruhura', 3000, -0.2200, 30.8100),
('CC-NTG-01', 'Ntungamo Collection Point', 'Ntungamo', 2000, -0.8833, 30.2667);

-- Processing Plants
INSERT INTO processing_plants (plant_code, plant_name, location, daily_capacity_liters, certifications)
VALUES
('PL-KLA-01', 'Jesa Farm Dairy', 'Kampala', 50000, ARRAY['ISO-22000', 'HACCP', 'EAC']),
('PL-MBR-01', 'Amos Dairies', 'Mbarara', 30000, ARRAY['HACCP', 'UNBS']),
('PL-JJA-01', 'Pearl Dairy Farms', 'Jinja', 80000, ARRAY['ISO-22000', 'HACCP', 'EU-Export']);

-- ============================================================================
-- BATCH CHAIN: Farm → Collection → Processing → Packaging → Distribution
-- This creates a traceable supply chain
-- ============================================================================

-- Level 0: Farm collection batches (no parent)
INSERT INTO batches (batch_id, parent_batch_id, stage, farmer_id, center_id, quantity_liters, fat_content, protein_content, temperature_celsius, quality_grade, created_at)
VALUES
-- Morning collection Jan 15
('FARM-001-2024-0115', NULL, 'collection', 1, NULL, 50.0, 3.8, 3.2, 28.0, 'A', '2024-01-15 06:30:00'),
('FARM-002-2024-0115', NULL, 'collection', 2, NULL, 80.0, 4.1, 3.4, 27.5, 'A', '2024-01-15 06:45:00'),
('FARM-003-2024-0115', NULL, 'collection', 3, NULL, 30.0, 3.5, 3.0, 29.0, 'B', '2024-01-15 07:00:00'),
('FARM-004-2024-0115', NULL, 'collection', 4, NULL, 60.0, 3.9, 3.3, 27.0, 'A', '2024-01-15 06:30:00'),
('FARM-005-2024-0115', NULL, 'collection', 5, NULL, 40.0, 3.6, 3.1, 30.0, 'B', '2024-01-15 07:15:00'),
('FARM-006-2024-0115', NULL, 'collection', 6, NULL, 70.0, 4.2, 3.5, 26.5, 'A', '2024-01-15 06:15:00');

-- Level 1: Collection center cooling (combines farm batches)
INSERT INTO batches (batch_id, parent_batch_id, stage, center_id, quantity_liters, temperature_celsius, min_temp_recorded, max_temp_recorded, quality_grade, created_at)
VALUES
-- Mbarara center combines FRM-001, FRM-006
('CC-MBR-2024-0115-AM', 'FARM-001-2024-0115', 'cooling', 1, 120.0, 4.0, 4.0, 4.5, 'A', '2024-01-15 09:00:00'),
-- Kiruhura center combines FRM-002, FRM-004
('CC-KRH-2024-0115-AM', 'FARM-002-2024-0115', 'cooling', 2, 140.0, 4.2, 4.0, 4.5, 'A', '2024-01-15 09:30:00'),
-- Ntungamo center combines FRM-003, FRM-005
('CC-NTG-2024-0115-AM', 'FARM-003-2024-0115', 'cooling', 3, 70.0, 4.5, 4.0, 5.0, 'B', '2024-01-15 10:00:00');

-- Add secondary parent links (for completeness in multi-origin batches)
-- Note: In practice, a junction table would handle many-to-many, but we keep it simple

-- Level 2: Transport to processing
INSERT INTO batches (batch_id, parent_batch_id, stage, center_id, plant_id, quantity_liters, temperature_celsius, min_temp_recorded, max_temp_recorded, quality_grade, created_at)
VALUES
('TRANS-MBR-KLA-0115', 'CC-MBR-2024-0115-AM', 'transport', 1, 1, 120.0, 5.0, 4.5, 6.0, 'A', '2024-01-15 11:00:00'),
('TRANS-KRH-KLA-0115', 'CC-KRH-2024-0115-AM', 'transport', 2, 1, 140.0, 5.2, 4.8, 6.5, 'A', '2024-01-15 11:30:00'),
('TRANS-NTG-MBR-0115', 'CC-NTG-2024-0115-AM', 'transport', 3, 2, 70.0, 5.5, 5.0, 7.0, 'B', '2024-01-15 12:00:00');

-- Level 3: Processing at plant
INSERT INTO batches (batch_id, parent_batch_id, stage, plant_id, quantity_liters, temperature_celsius, quality_grade, created_at, processed_at)
VALUES
-- Jesa combines transports from Mbarara and Kiruhura
('PROC-JES-2024-0115', 'TRANS-MBR-KLA-0115', 'processing', 1, 260.0, 4.0, 'A', '2024-01-15 14:00:00', '2024-01-15 16:00:00'),
-- Amos processes Ntungamo batch
('PROC-AMO-2024-0115', 'TRANS-NTG-MBR-0115', 'processing', 2, 70.0, 4.0, 'B', '2024-01-15 15:00:00', '2024-01-15 17:00:00');

-- Level 4: Packaging
INSERT INTO batches (batch_id, parent_batch_id, stage, plant_id, quantity_liters, quality_grade, created_at, expires_at)
VALUES
-- Fresh milk 500ml packs from Jesa
('PKG-JES-FM500-0115-001', 'PROC-JES-2024-0115', 'packaging', 1, 100.0, 'A', '2024-01-15 17:00:00', '2024-01-22 00:00:00'),
('PKG-JES-FM500-0115-002', 'PROC-JES-2024-0115', 'packaging', 1, 100.0, 'A', '2024-01-15 17:30:00', '2024-01-22 00:00:00'),
-- Yogurt from Jesa
('PKG-JES-YGT-0115-001', 'PROC-JES-2024-0115', 'packaging', 1, 60.0, 'A', '2024-01-15 18:00:00', '2024-01-29 00:00:00'),
-- Fresh milk from Amos
('PKG-AMO-FM1L-0115-001', 'PROC-AMO-2024-0115', 'packaging', 2, 70.0, 'B', '2024-01-15 18:00:00', '2024-01-22 00:00:00');

-- Level 5: Distribution
INSERT INTO batches (batch_id, parent_batch_id, stage, plant_id, quantity_liters, quality_grade, created_at)
VALUES
('DIST-JES-KLA-0116-001', 'PKG-JES-FM500-0115-001', 'distribution', 1, 100.0, 'A', '2024-01-16 05:00:00'),
('DIST-JES-JJA-0116-001', 'PKG-JES-FM500-0115-002', 'distribution', 1, 100.0, 'A', '2024-01-16 05:30:00'),
('DIST-AMO-MBR-0116-001', 'PKG-AMO-FM1L-0115-001', 'distribution', 2, 70.0, 'B', '2024-01-16 06:00:00');

-- ============================================================================
-- CONTAMINATION SCENARIO (for testing trace functions)
-- ============================================================================

-- Add a contaminated batch chain
INSERT INTO batches (batch_id, parent_batch_id, stage, farmer_id, quantity_liters, quality_grade, is_contaminated, contamination_reason, created_at)
VALUES
('FARM-007-2024-0120', NULL, 'collection', 3, 25.0, 'R', TRUE, 'Aflatoxin detected above threshold', '2024-01-20 07:00:00');

INSERT INTO batches (batch_id, parent_batch_id, stage, center_id, quantity_liters, quality_grade, created_at)
VALUES
('CC-NTG-2024-0120-AM', 'FARM-007-2024-0120', 'cooling', 3, 25.0, 'R', '2024-01-20 09:00:00');

-- Quality tests
INSERT INTO batch_tests (batch_id, test_type, test_result, test_value, threshold_min, threshold_max, tested_by)
VALUES
('FARM-001-2024-0115', 'fat_content', 'pass', 3.8, 3.5, 5.0, 'Lab Tech A'),
('FARM-001-2024-0115', 'somatic_cell_count', 'pass', 180000, 0, 400000, 'Lab Tech A'),
('PROC-JES-2024-0115', 'pasteurization_temp', 'pass', 72.5, 72.0, 75.0, 'QC Officer'),
('PROC-JES-2024-0115', 'coliform_count', 'pass', 5, 0, 10, 'Lab Tech B'),
('FARM-007-2024-0120', 'aflatoxin_m1', 'fail', 0.8, 0, 0.5, 'Lab Tech C');

-- Deliveries
INSERT INTO deliveries (batch_id, delivery_date, destination, destination_type, quantity_units, unit_type, status)
VALUES
('DIST-JES-KLA-0116-001', '2024-01-16', 'Shoprite Lugogo', 'retailer', 200, '500ml', 'delivered'),
('DIST-JES-JJA-0116-001', '2024-01-16', 'Game Stores Jinja', 'retailer', 200, '500ml', 'delivered'),
('DIST-AMO-MBR-0116-001', '2024-01-16', 'Mbarara Wholesale Hub', 'distributor', 70, '1L', 'delivered');

SELECT 'Sample data loaded' AS status;
SELECT 'Farmers: ' || COUNT(*) FROM farmers;
SELECT 'Batches: ' || COUNT(*) FROM batches;
SELECT 'Chain depth: ' || MAX(depth) FROM (
    SELECT batch_id, depth FROM fn_trace_to_origin('DIST-JES-KLA-0116-001')
) sub;
