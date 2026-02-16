-- ============================================================================
-- Land Dispute Resolver - Overlap Detection Report
-- Uses PostGIS ST_Intersects for spatial overlap detection
-- PostgreSQL 14+ with PostGIS
-- ============================================================================

-- ============================================================================
-- CORE PATTERN: ST_Intersects for detecting overlapping parcels
-- ============================================================================

-- User's sample pattern - Detecting overlapping land parcels
SELECT 
    p1.owner_name AS owner_1,
    p2.owner_name AS owner_2,
    p1.plot_number AS plot_1,
    p2.plot_number AS plot_2
FROM parcels p1, parcels p2 
WHERE ST_Intersects(p1.boundary, p2.boundary) 
    AND p1.parcel_id != p2.parcel_id;

-- ============================================================================
-- DETAILED OVERLAP ANALYSIS
-- ============================================================================

-- Full overlap report with area calculations
SELECT 
    p1.parcel_id AS parcel_1_id,
    p1.plot_number AS plot_1,
    p1.owner_name AS owner_1,
    p1.title_type AS title_1,
    p1.registered_date AS registered_1,
    p2.parcel_id AS parcel_2_id,
    p2.plot_number AS plot_2,
    p2.owner_name AS owner_2,
    p2.title_type AS title_2,
    p2.registered_date AS registered_2,
    -- Area calculations (in square meters, using Uganda's UTM zone 36N)
    ST_Area(ST_Transform(p1.boundary, 32636)) AS parcel_1_area_m2,
    ST_Area(ST_Transform(p2.boundary, 32636)) AS parcel_2_area_m2,
    ST_Area(ST_Transform(ST_Intersection(p1.boundary, p2.boundary), 32636)) AS overlap_area_m2,
    -- Overlap percentage
    ROUND((ST_Area(ST_Intersection(p1.boundary, p2.boundary)) / 
           LEAST(ST_Area(p1.boundary), ST_Area(p2.boundary)) * 100)::NUMERIC, 2) AS overlap_pct,
    -- Senior claim (older registration gets priority)
    CASE 
        WHEN p1.registered_date < p2.registered_date THEN p1.owner_name
        ELSE p2.owner_name
    END AS senior_claimant
FROM parcels p1
JOIN parcels p2 ON p1.parcel_id < p2.parcel_id  -- Avoid duplicates
WHERE ST_Intersects(p1.boundary, p2.boundary)
ORDER BY ST_Area(ST_Intersection(p1.boundary, p2.boundary)) DESC;

-- ============================================================================
-- DISTRICT-LEVEL DISPUTE SUMMARY
-- ============================================================================

SELECT 
    d.district_name,
    d.region,
    COUNT(DISTINCT p.parcel_id) AS total_parcels,
    (SELECT COUNT(*) 
     FROM vw_overlapping_parcels v 
     JOIN parcels p1 ON v.parcel_1_id = p1.parcel_id 
     WHERE p1.district_id = d.district_id) AS overlap_incidents,
    (SELECT COUNT(*) 
     FROM disputes ds 
     JOIN parcels p1 ON ds.parcel_1_id = p1.parcel_id 
     WHERE p1.district_id = d.district_id) AS active_disputes
FROM land_districts d
LEFT JOIN parcels p ON d.district_id = p.district_id
GROUP BY d.district_id, d.district_name, d.region
ORDER BY total_parcels DESC;

-- ============================================================================
-- PRIORITY DISPUTES (Large overlaps or conflicting title types)
-- ============================================================================

SELECT 
    v.parcel_1_id,
    v.owner_1,
    v.title_1,
    v.parcel_2_id,
    v.owner_2,
    v.title_2,
    v.overlap_area_m2,
    v.overlap_percentage,
    CASE
        WHEN v.overlap_percentage > 50 THEN 'CRITICAL - Major Overlap'
        WHEN v.overlap_percentage > 25 THEN 'HIGH - Significant Overlap'
        WHEN v.overlap_percentage > 10 THEN 'MEDIUM - Partial Overlap'
        ELSE 'LOW - Minor Boundary Issue'
    END AS priority_level,
    CASE 
        WHEN v.title_1 != v.title_2 THEN 'CONFLICT - Different Title Types'
        ELSE 'Same Title Type'
    END AS title_conflict
FROM vw_overlapping_parcels v
ORDER BY v.overlap_percentage DESC;

-- ============================================================================
-- ENCROACHMENT DETECTION (One parcel mostly inside another)
-- ============================================================================

SELECT 
    p_outer.plot_number AS larger_parcel,
    p_outer.owner_name AS larger_owner,
    p_inner.plot_number AS encroaching_parcel,
    p_inner.owner_name AS encroacher,
    ROUND((ST_Area(ST_Intersection(p_outer.boundary, p_inner.boundary)) / 
           ST_Area(p_inner.boundary) * 100)::NUMERIC, 2) AS pct_of_smaller_inside_larger,
    ST_Area(ST_Transform(p_inner.boundary, 32636)) AS encroaching_parcel_area_m2
FROM parcels p_outer
JOIN parcels p_inner ON ST_Intersects(p_outer.boundary, p_inner.boundary)
    AND p_outer.parcel_id != p_inner.parcel_id
    AND ST_Area(p_outer.boundary) > ST_Area(p_inner.boundary)
WHERE ST_Area(ST_Intersection(p_outer.boundary, p_inner.boundary)) / 
      ST_Area(p_inner.boundary) > 0.5  -- More than 50% inside
ORDER BY pct_of_smaller_inside_larger DESC;

-- ============================================================================
-- RECENT REGISTRATIONS WITH CONFLICTS
-- ============================================================================

SELECT 
    p.plot_number,
    p.owner_name,
    p.title_type,
    p.registered_date,
    COUNT(v.parcel_2_id) AS conflicts_with,
    STRING_AGG(v.owner_2, ', ') AS conflicting_owners
FROM parcels p
LEFT JOIN vw_overlapping_parcels v ON p.parcel_id = v.parcel_1_id
WHERE p.registered_date > CURRENT_DATE - INTERVAL '2 years'
GROUP BY p.parcel_id, p.plot_number, p.owner_name, p.title_type, p.registered_date
HAVING COUNT(v.parcel_2_id) > 0
ORDER BY p.registered_date DESC;

-- ============================================================================
-- SUMMARY STATISTICS
-- ============================================================================

SELECT 
    'Total Parcels' AS metric,
    COUNT(*)::TEXT AS value
FROM parcels
UNION ALL
SELECT 
    'Parcels with Overlaps',
    COUNT(DISTINCT parcel_1_id)::TEXT
FROM vw_overlapping_parcels
UNION ALL
SELECT 
    'Total Overlap Pairs',
    COUNT(*)::TEXT
FROM vw_overlapping_parcels
UNION ALL
SELECT 
    'Active Disputes',
    COUNT(*)::TEXT
FROM disputes WHERE status = 'pending'
UNION ALL
SELECT 
    'Avg Overlap Area (m²)',
    ROUND(AVG(overlap_area_m2)::NUMERIC, 2)::TEXT
FROM vw_overlapping_parcels;
