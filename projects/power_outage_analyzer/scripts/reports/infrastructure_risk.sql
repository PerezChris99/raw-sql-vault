-- ============================================================================
-- Power Outage Pattern Analyzer - Infrastructure Risk Assessment Report
-- Analyzes transformers, substations, and power lines for failure risk
-- Run: psql -d power_outage_db -f infrastructure_risk.sql
-- ============================================================================

\echo '=========================================='
\echo 'INFRASTRUCTURE RISK ASSESSMENT REPORT'
\echo '=========================================='
\echo ''

\pset format aligned
\pset border 2
\pset linestyle unicode

-- Current timestamp
SELECT CURRENT_TIMESTAMP as "Report Generated At";

\echo ''
\echo '1. TRANSFORMER RISK ZONES'
\echo '-------------------------'
\echo 'Transformers with nearby outages requiring inspection...'
\echo ''

SELECT 
    transformer_code as "Transformer",
    age_years as "Age (yrs)",
    nearby_outages as "Nearby Outages",
    risk_level as "Risk Level",
    recommended_inspection_date as "Inspect By"
FROM fn_transformer_risk_zones(2, 500, 365)
ORDER BY 
    CASE risk_level 
        WHEN 'critical' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        ELSE 4 
    END,
    nearby_outages DESC
LIMIT 20;

\echo ''
\echo '2. COMPREHENSIVE INFRASTRUCTURE RISK SCORES'
\echo '-------------------------------------------'
\echo 'All infrastructure ranked by risk...'
\echo ''

SELECT 
    entity_type as "Type",
    entity_id as "ID",
    entity_name as "Name",
    outages_90d as "Outages (90d)",
    outages_1y as "Outages (1yr)",
    age_factor as "Age Factor",
    proximity_factor as "Proximity Factor",
    overall_risk_score as "Risk Score",
    risk_category as "Category"
FROM fn_calculate_infrastructure_risk()
WHERE risk_category IN ('critical', 'high')
ORDER BY overall_risk_score DESC
LIMIT 25;

\echo ''
\echo '3. TRANSFORMER AGE ANALYSIS'
\echo '---------------------------'
\echo 'Aging transformers with failure correlation...'
\echo ''

SELECT 
    t.code as "Transformer",
    d.name as "District",
    t.age_years as "Age (yrs)",
    t.capacity_kva as "Capacity (kVA)",
    t.customers_served as "Customers",
    t.status as "Status",
    t.last_maintenance_date as "Last Maintenance",
    (SELECT COUNT(*) FROM outages o 
     WHERE ST_DWithin(t.location, o.location, 500)
       AND o.occurred_at >= CURRENT_DATE - INTERVAL '1 year') as "Nearby Outages (1yr)",
    CASE 
        WHEN t.age_years >= 30 THEN 'REPLACE'
        WHEN t.age_years >= 25 THEN 'CRITICAL INSPECTION'
        WHEN t.age_years >= 20 THEN 'ENHANCED MONITORING'
        ELSE 'ROUTINE'
    END as "Recommendation"
FROM transformers t
JOIN districts d ON t.district_id = d.district_id
WHERE t.age_years IS NOT NULL
ORDER BY t.age_years DESC
LIMIT 20;

\echo ''
\echo '4. POWER LINE VULNERABILITY'
\echo '---------------------------'
\echo 'Lines with high failure proximity...'
\echo ''

SELECT 
    line_id as "Line ID",
    name as "Line Name",
    line_type as "Type",
    voltage_kv as "Voltage (kV)",
    ROUND(length_km::NUMERIC, 2) as "Length (km)",
    installation_year as "Install Year",
    nearby_outages_1y as "Outages (1yr)",
    line_intersections as "Intersections",
    vulnerability_score as "Vuln. Score"
FROM vw_power_line_vulnerability
WHERE nearby_outages_1y > 0
ORDER BY vulnerability_score DESC
LIMIT 15;

\echo ''
\echo '5. SUBSTATION IMPACT ANALYSIS'
\echo '-----------------------------'
\echo 'Substations with surrounding outage activity...'
\echo ''

SELECT 
    substation_name as "Substation",
    COUNT(outage_id) as "Nearby Outages",
    ROUND(AVG(distance_meters)) as "Avg Distance (m)",
    SUM(customers_affected) as "Total Customers Affected",
    ROUND(AVG(duration_minutes)) as "Avg Duration (min)"
FROM vw_outages_near_substations
WHERE occurred_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY substation_id, substation_name
ORDER BY COUNT(outage_id) DESC
LIMIT 10;

\echo ''
\echo '6. EQUIPMENT FAILURE PROXIMITY MAP'
\echo '-----------------------------------'
\echo 'Equipment cause outages near aging infrastructure...'
\echo ''

WITH equipment_outages AS (
    SELECT 
        o.outage_id,
        o.location,
        o.occurred_at,
        o.customers_affected,
        oc.name as cause
    FROM outages o
    JOIN outage_causes oc ON o.cause_id = oc.cause_id
    WHERE oc.category = 'equipment'
      AND o.occurred_at >= CURRENT_DATE - INTERVAL '180 days'
),
near_transformers AS (
    SELECT 
        t.transformer_id,
        t.code,
        t.age_years,
        eo.outage_id,
        eo.cause,
        ST_Distance(t.location, eo.location) as distance_m
    FROM transformers t
    JOIN equipment_outages eo ON ST_DWithin(t.location, eo.location, 300)
    WHERE t.age_years >= 15
)
SELECT 
    code as "Transformer",
    age_years as "Age (yrs)",
    COUNT(DISTINCT outage_id) as "Equipment Failures Nearby",
    ROUND(AVG(distance_m)::NUMERIC) as "Avg Distance (m)",
    ARRAY_AGG(DISTINCT cause) as "Failure Types"
FROM near_transformers
GROUP BY transformer_id, code, age_years
HAVING COUNT(DISTINCT outage_id) >= 2
ORDER BY COUNT(DISTINCT outage_id) DESC
LIMIT 15;

\echo ''
\echo '7. MAINTENANCE PRIORITY QUEUE'
\echo '-----------------------------'
\echo 'Recommended maintenance schedule based on risk...'
\echo ''

WITH priority_queue AS (
    SELECT 
        entity_type,
        entity_id,
        entity_name,
        risk_category,
        overall_risk_score,
        CASE risk_category
            WHEN 'critical' THEN CURRENT_DATE + INTERVAL '7 days'
            WHEN 'high' THEN CURRENT_DATE + INTERVAL '30 days'
            WHEN 'medium' THEN CURRENT_DATE + INTERVAL '90 days'
            ELSE CURRENT_DATE + INTERVAL '180 days'
        END as recommended_action_date
    FROM fn_calculate_infrastructure_risk()
    WHERE risk_category IN ('critical', 'high', 'medium')
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY overall_risk_score DESC) as "Priority",
    entity_type as "Type",
    entity_name as "Equipment",
    risk_category as "Risk Level",
    overall_risk_score as "Risk Score",
    recommended_action_date::DATE as "Action By"
FROM priority_queue
ORDER BY overall_risk_score DESC
LIMIT 20;

\echo ''
\echo '8. RISK TREND (Last 6 Months by Category)'
\echo '-----------------------------------------'
\echo ''

SELECT 
    DATE_TRUNC('month', o.occurred_at)::DATE as "Month",
    COUNT(*) FILTER (WHERE oc.category = 'equipment') as "Equipment",
    COUNT(*) FILTER (WHERE oc.category = 'weather') as "Weather",
    COUNT(*) FILTER (WHERE oc.category = 'vegetation') as "Vegetation",
    COUNT(*) FILTER (WHERE oc.category = 'overload') as "Overload",
    COUNT(*) as "Total"
FROM outages o
LEFT JOIN outage_causes oc ON o.cause_id = oc.cause_id
WHERE o.occurred_at >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '6 months'
GROUP BY DATE_TRUNC('month', o.occurred_at)
ORDER BY "Month" DESC;

\echo ''
\echo '========================================'
\echo 'END OF INFRASTRUCTURE RISK REPORT'
\echo '========================================'
