-- ============================================================================
-- Power Outage Pattern Analyzer - Service Area Analysis Report
-- Geographic coverage, crew dispatch optimization, real-time status
-- Run: psql -d power_outage_db -f service_area_analysis.sql
-- ============================================================================

\echo '=========================================='
\echo 'SERVICE AREA ANALYSIS REPORT'
\echo '=========================================='
\echo ''

\pset format aligned
\pset border 2
\pset linestyle unicode

-- Current timestamp
SELECT CURRENT_TIMESTAMP as "Report Generated At";

\echo ''
\echo '1. CURRENT ACTIVE OUTAGES'
\echo '-------------------------'
\echo 'Real-time outage status...'
\echo ''

SELECT 
    LEFT(outage_id::TEXT, 8) as "Outage ID",
    district_name as "District",
    customers_affected as "Customers",
    severity as "Severity",
    status as "Status",
    ROUND(hours_ongoing::NUMERIC, 1) as "Hours Ongoing",
    cause_name as "Cause"
FROM vw_active_outages
ORDER BY customers_affected DESC
LIMIT 15;

\echo ''
\echo '2. DISTRICT COVERAGE STATISTICS'
\echo '-------------------------------'
\echo 'Service coverage by administrative district...'
\echo ''

SELECT 
    district_name as "District",
    district_code as "Code",
    ROUND(area_sq_km, 1) as "Area (km²)",
    population as "Population",
    total_outages as "Outages (1yr)",
    outages_last_30d as "Outages (30d)",
    outages_per_sq_km as "Density (/km²)",
    outages_per_1000_pop as "Per 1000 Pop"
FROM vw_district_outage_stats
ORDER BY total_outages DESC;

\echo ''
\echo '3. DISTRICT RISK HEATMAP DATA'
\echo '-----------------------------'
\echo 'Risk levels for visualization...'
\echo ''

SELECT 
    name as "District",
    recent_outages as "Recent Outages",
    ROUND(avg_duration) as "Avg Duration (min)",
    equipment_failures as "Equipment Issues",
    weather_events as "Weather Events",
    risk_score as "Risk Score",
    risk_level as "Risk Level"
FROM vw_district_risk_heatmap
ORDER BY risk_score DESC;

\echo ''
\echo '4. CREW AVAILABILITY STATUS'
\echo '---------------------------'
\echo 'Current crew positions and availability...'
\echo ''

SELECT 
    c.crew_id as "ID",
    c.name as "Crew Name",
    c.specialization as "Specialization",
    c.member_count as "Members",
    c.status as "Status",
    ROUND(ST_X(c.current_location::geometry)::NUMERIC, 4) as "Longitude",
    ROUND(ST_Y(c.current_location::geometry)::NUMERIC, 4) as "Latitude"
FROM crews c
WHERE c.current_location IS NOT NULL
ORDER BY 
    CASE c.status 
        WHEN 'available' THEN 1 
        WHEN 'standby' THEN 2 
        ELSE 3 
    END;

\echo ''
\echo '5. OPTIMAL CREW DISPATCH EXAMPLE'
\echo '--------------------------------'
\echo 'Finding best crew for sample outage at (-122.40, 37.78)...'
\echo ''

SELECT 
    crew_id as "Crew ID",
    crew_name as "Crew",
    specialization as "Specialization",
    current_status as "Status",
    ROUND(distance_meters) as "Distance (m)",
    estimated_travel_minutes as "Travel (min)",
    suitability_score as "Score"
FROM fn_find_optimal_crew(-122.40, 37.78, NULL, 5);

\echo ''
\echo '6. OUTAGES NEAR MAJOR SUBSTATIONS'
\echo '---------------------------------'
\echo 'Recent outages within 2km of substations...'
\echo ''

SELECT 
    substation_name as "Substation",
    LEFT(outage_id::TEXT, 8) as "Outage",
    ROUND(distance_meters) as "Distance (m)",
    occurred_at::DATE as "Date",
    customers_affected as "Customers",
    status as "Status"
FROM vw_outages_near_substations
WHERE occurred_at >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY substation_name, distance_meters
LIMIT 20;

\echo ''
\echo '7. SERVICE AREA OUTAGE DENSITY'
\echo '------------------------------'
\echo 'Monthly density trends by district...'
\echo ''

SELECT 
    TO_CHAR(month, 'YYYY-MM') as "Month",
    district_name as "District",
    outage_count as "Outages",
    total_customers_affected as "Customers",
    ROUND(avg_duration) as "Avg Duration",
    ROUND(outages_per_sq_km, 2) as "Density (/km²)"
FROM vw_monthly_outage_density
WHERE month >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '3 months'
ORDER BY month DESC, outage_count DESC
LIMIT 30;

\echo ''
\echo '8. PROXIMITY ANALYSIS: OUTAGES NEAR POINT'
\echo '-----------------------------------------'
\echo 'Sample: All outages within 2km of downtown (-122.405, 37.785)...'
\echo ''

SELECT 
    LEFT(outage_id::TEXT, 8) as "Outage",
    ROUND(distance_meters) as "Distance (m)",
    occurred_at::DATE as "Date",
    customers_affected as "Customers",
    duration_minutes as "Duration (min)",
    cause_name as "Cause",
    severity as "Severity"
FROM fn_outages_near_point(-122.405, 37.785, 2000, 90)
ORDER BY distance_meters
LIMIT 15;

\echo ''
\echo '9. NEAREST OUTAGES TO A LOCATION'
\echo '--------------------------------'
\echo 'Using KNN spatial index for fast nearest neighbor...'
\echo ''

SELECT 
    LEFT(outage_id::TEXT, 8) as "Outage",
    ROUND(distance_meters) as "Distance (m)",
    direction as "Direction",
    occurred_at::DATE as "Date",
    customers_affected as "Customers",
    district_name as "District"
FROM fn_nearest_outages(-122.40, 37.75, 10, 180);

\echo ''
\echo '10. DISPATCH RESPONSE TIME ANALYSIS'
\echo '-----------------------------------'
\echo 'Average crew response metrics by district...'
\echo ''

SELECT 
    d.name as "District",
    COUNT(cd.dispatch_id) as "Dispatches",
    ROUND(AVG(EXTRACT(EPOCH FROM (cd.arrived_at - cd.dispatched_at)) / 60)) as "Avg Response (min)",
    ROUND(AVG(EXTRACT(EPOCH FROM (cd.completed_at - cd.arrived_at)) / 60)) as "Avg Repair (min)",
    ROUND(AVG(cd.travel_distance_km)::NUMERIC, 1) as "Avg Travel (km)"
FROM crew_dispatches cd
JOIN outages o ON cd.outage_id = o.outage_id
JOIN districts d ON o.district_id = d.district_id
WHERE cd.completed_at IS NOT NULL
  AND cd.dispatched_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY d.district_id, d.name
HAVING COUNT(cd.dispatch_id) >= 3
ORDER BY "Avg Response (min)";

\echo ''
\echo '11. ACTIVE OUTAGE TIMELINE'
\echo '--------------------------'
\echo 'Recent 30-day temporal pattern...'
\echo ''

SELECT 
    outage_date as "Date",
    TO_CHAR(outage_date, 'Day') as "Day of Week",
    COUNT(*) FILTER (WHERE hour_of_day BETWEEN 6 AND 11) as "Morning",
    COUNT(*) FILTER (WHERE hour_of_day BETWEEN 12 AND 17) as "Afternoon",
    COUNT(*) FILTER (WHERE hour_of_day BETWEEN 18 AND 23) as "Evening",
    COUNT(*) FILTER (WHERE hour_of_day BETWEEN 0 AND 5) as "Night",
    COUNT(*) as "Total"
FROM vw_recent_outage_timeline
GROUP BY outage_date
ORDER BY outage_date DESC
LIMIT 14;

\echo ''
\echo '========================================'
\echo 'END OF SERVICE AREA ANALYSIS REPORT'
\echo '========================================'
