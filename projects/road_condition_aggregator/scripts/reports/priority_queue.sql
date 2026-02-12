-- ============================================================================
-- Road Condition Aggregator - Priority Queue Report
-- PostgreSQL 14+ with PostGIS 3.x
-- Report: Prioritized repair queue with cluster details
-- ============================================================================

\echo '=============================================='
\echo 'ROAD CONDITION AGGREGATOR - PRIORITY QUEUE'
\echo 'Generated: ' :NOW
\echo '=============================================='
\echo ''

-- ============================================================================
-- Executive Summary
-- ============================================================================

\echo '>> EXECUTIVE SUMMARY'
\echo ''

WITH summary AS (
    SELECT 
        COUNT(*) as total_clusters,
        SUM(report_count) as total_reports,
        ROUND(AVG(priority_score), 1) as avg_priority,
        COUNT(*) FILTER (WHERE priority_score >= 70) as critical_clusters,
        SUM(estimated_cost) as total_estimated_cost
    FROM fn_get_priority_queue()
)
SELECT 
    total_clusters as "Clusters",
    total_reports as "Total Reports",
    avg_priority as "Avg Priority",
    critical_clusters as "Critical (70+)",
    '$' || TO_CHAR(total_estimated_cost, 'FM999,999.00') as "Est. Cost"
FROM summary;

\echo ''

-- ============================================================================
-- Top Priority Clusters (User's Sample Query Pattern)
-- ============================================================================

\echo '>> TOP 10 PRIORITY CLUSTERS'
\echo '   (Using DBSCAN: eps=0.01, minpoints=3)'
\echo ''

SELECT 
    priority_rank as "#",
    cluster_id as "Cluster",
    report_count as "Reports",
    avg_severity as "Avg Sev",
    max_severity as "Max Sev",
    priority_score as "Priority",
    ARRAY_TO_STRING(affected_roads, ', ') as "Affected Roads",
    '$' || TO_CHAR(estimated_cost, 'FM999,999.00') as "Est Cost",
    days_pending || 'd' as "Age"
FROM fn_get_priority_queue(0.01, 3, 30, 10);

\echo ''

-- ============================================================================
-- Direct DBSCAN Query (Matching User's Sample)
-- ============================================================================

\echo '>> DBSCAN CLUSTER SUMMARY (User Sample Query)'
\echo '   SELECT ST_ClusterDBSCAN(geom, 0.01, 3) ... HAVING COUNT(*) > 5'
\echo ''

SELECT 
    cluster_id as "Cluster ID",
    COUNT(*) as "Report Count",
    ROUND(AVG(severity), 2) as "Avg Severity"
FROM (
    SELECT 
        report_id,
        severity,
        ST_ClusterDBSCAN(location::geometry, 0.01, 3) OVER () as cluster_id
    FROM road_reports
    WHERE status IN ('new', 'verified')
) clustered
GROUP BY cluster_id
HAVING COUNT(*) > 5
ORDER BY "Avg Severity" DESC;

\echo ''

-- ============================================================================
-- SLA Compliance Overview
-- ============================================================================

\echo '>> SLA COMPLIANCE STATUS'
\echo ''

WITH report_sla AS (
    SELECT 
        rr.report_id,
        rr.severity,
        rr.reported_at,
        (fn_sla_compliance_check(rr.severity, rr.reported_at)).*
    FROM road_reports rr
    WHERE rr.status IN ('new', 'verified')
)
SELECT 
    compliance_status as "Status",
    COUNT(*) as "Reports",
    ROUND(AVG(days_elapsed), 1) as "Avg Days",
    ROUND(AVG(urgency_multiplier), 2) as "Urgency Mult"
FROM report_sla
GROUP BY compliance_status
ORDER BY 
    CASE compliance_status 
        WHEN 'overdue' THEN 1 
        WHEN 'at_risk' THEN 2 
        ELSE 3 
    END;

\echo ''

-- ============================================================================
-- Geographic Distribution
-- ============================================================================

\echo '>> CLUSTER GEOGRAPHIC DISTRIBUTION'
\echo ''

SELECT 
    pq.cluster_id as "Cluster",
    pq.report_count as "Reports",
    ROUND(ST_Y(pq.work_center::geometry)::NUMERIC, 6) as "Latitude",
    ROUND(ST_X(pq.work_center::geometry)::NUMERIC, 6) as "Longitude",
    pq.priority_score as "Priority"
FROM fn_get_priority_queue(0.01, 3, 30, 10) pq
ORDER BY pq.priority_rank;

\echo ''

-- ============================================================================
-- Cost Breakdown by Priority Tier
-- ============================================================================

\echo '>> COST BREAKDOWN BY PRIORITY TIER'
\echo ''

WITH tiered AS (
    SELECT 
        CASE 
            WHEN priority_score >= 80 THEN 'Critical (80+)'
            WHEN priority_score >= 60 THEN 'High (60-79)'
            WHEN priority_score >= 40 THEN 'Medium (40-59)'
            ELSE 'Low (<40)'
        END as priority_tier,
        report_count,
        estimated_cost
    FROM fn_get_priority_queue()
)
SELECT 
    priority_tier as "Priority Tier",
    COUNT(*) as "Clusters",
    SUM(report_count) as "Reports",
    '$' || TO_CHAR(SUM(estimated_cost), 'FM999,999.00') as "Total Cost"
FROM tiered
GROUP BY priority_tier
ORDER BY 
    CASE priority_tier 
        WHEN 'Critical (80+)' THEN 1
        WHEN 'High (60-79)' THEN 2
        WHEN 'Medium (40-59)' THEN 3
        ELSE 4
    END;

\echo ''
\echo '=============================================='
\echo 'END OF PRIORITY QUEUE REPORT'
\echo '=============================================='
