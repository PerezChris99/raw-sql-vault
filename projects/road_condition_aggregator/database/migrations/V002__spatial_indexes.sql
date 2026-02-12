-- ============================================================================
-- Road Condition Aggregator - V002 Spatial Indexes
-- PostgreSQL 14+ with PostGIS 3.x
-- GIST indexes for geospatial query optimization
-- ============================================================================

-- ============================================================================
-- Primary GIST Indexes (Spatial)
-- ============================================================================

-- Road reports - main spatial queries
CREATE INDEX idx_road_reports_location_gist 
    ON road_reports USING GIST((location::geometry));

-- Road segments - line geometry queries
CREATE INDEX idx_road_segments_geom_gist 
    ON road_segments USING GIST(geom);

-- Districts - boundary containment checks
CREATE INDEX idx_districts_boundary_gist 
    ON districts USING GIST(boundary);

-- Cluster centroids and boundaries
CREATE INDEX idx_report_clusters_centroid_gist 
    ON report_clusters USING GIST((centroid::geometry));

CREATE INDEX idx_report_clusters_boundary_gist 
    ON report_clusters USING GIST(boundary);

-- Crews - current location for dispatch
CREATE INDEX idx_crews_current_location_gist 
    ON crews USING GIST((current_location::geometry))
    WHERE current_location IS NOT NULL;

-- Work orders - work area
CREATE INDEX idx_work_orders_work_center_gist 
    ON repair_work_orders USING GIST((work_center::geometry));

CREATE INDEX idx_work_orders_work_area_gist 
    ON repair_work_orders USING GIST(work_area);

-- ============================================================================
-- SP-GIST Indexes (Point Nearest-Neighbor)
-- ============================================================================

-- For KNN queries on reports
CREATE INDEX idx_road_reports_location_spgist 
    ON road_reports USING SPGIST((location::geometry));

-- ============================================================================
-- B-Tree Indexes (Standard Lookups)
-- ============================================================================

-- Road reports - temporal queries
CREATE INDEX idx_road_reports_reported_at 
    ON road_reports(reported_at DESC);

CREATE INDEX idx_road_reports_status 
    ON road_reports(status, reported_at DESC);

-- Active/new reports only (partial index)
CREATE INDEX idx_road_reports_active 
    ON road_reports(reported_at DESC, severity DESC) 
    WHERE status IN ('new', 'verified');

-- Reports by severity (for priority filtering)
CREATE INDEX idx_road_reports_severity 
    ON road_reports(severity DESC, reported_at DESC);

-- Reports by district
CREATE INDEX idx_road_reports_district 
    ON road_reports(district_id, status, reported_at DESC);

-- Reports by segment
CREATE INDEX idx_road_reports_segment 
    ON road_reports(segment_id, reported_at DESC)
    WHERE segment_id IS NOT NULL;

-- Reports by damage type
CREATE INDEX idx_road_reports_damage_type 
    ON road_reports(damage_type_id, reported_at DESC);

-- Road segments indexes
CREATE INDEX idx_road_segments_district 
    ON road_segments(district_id);

CREATE INDEX idx_road_segments_road_class 
    ON road_segments(road_class_id);

CREATE INDEX idx_road_segments_status 
    ON road_segments(status);

CREATE INDEX idx_road_segments_condition 
    ON road_segments(pavement_condition ASC)
    WHERE status = 'active';

-- Report clusters indexes
CREATE INDEX idx_report_clusters_date 
    ON report_clusters(analysis_date DESC);

CREATE INDEX idx_report_clusters_status 
    ON report_clusters(status, analysis_date DESC);

CREATE INDEX idx_report_clusters_priority 
    ON report_clusters(priority_score DESC)
    WHERE status = 'pending';

-- Report cluster mapping
CREATE INDEX idx_report_cluster_mapping_cluster 
    ON report_cluster_mapping(cluster_id, analysis_date);

CREATE INDEX idx_report_cluster_mapping_report 
    ON report_cluster_mapping(report_id, analysis_date);

-- Work orders indexes
CREATE INDEX idx_work_orders_status 
    ON repair_work_orders(status, scheduled_date);

CREATE INDEX idx_work_orders_scheduled 
    ON repair_work_orders(scheduled_date, priority_rank)
    WHERE status IN ('pending', 'scheduled', 'assigned');

CREATE INDEX idx_work_orders_crew 
    ON repair_work_orders(crew_id, status);

CREATE INDEX idx_work_orders_cluster 
    ON repair_work_orders(cluster_id);

-- Work order history
CREATE INDEX idx_work_order_history_wo 
    ON work_order_history(work_order_id, changed_at DESC);

-- Daily statistics
CREATE INDEX idx_daily_stats_date 
    ON daily_statistics(stat_date DESC);

-- District summary
CREATE INDEX idx_district_summary_date 
    ON district_daily_summary(summary_date DESC, district_id);

-- Audit log
CREATE INDEX idx_audit_log_table_record 
    ON audit_log(table_name, record_id, performed_at DESC);

CREATE INDEX idx_audit_log_time 
    ON audit_log(performed_at DESC);

-- ============================================================================
-- Composite Indexes for Common Query Patterns
-- ============================================================================

-- Spatial + Temporal queries (most common pattern)
CREATE INDEX idx_road_reports_composite_time_location 
    ON road_reports(reported_at DESC) 
    INCLUDE (location, severity, status, damage_type_id);

-- District + Status + Time
CREATE INDEX idx_road_reports_composite_district_status 
    ON road_reports(district_id, status, reported_at DESC) 
    INCLUDE (location, severity);

-- For DBSCAN clustering analysis
CREATE INDEX idx_road_reports_cluster_analysis 
    ON road_reports(reported_at DESC)
    INCLUDE (location, severity, damage_type_id)
    WHERE status IN ('new', 'verified')
      AND reported_at >= CURRENT_DATE - INTERVAL '30 days';

-- ============================================================================
-- Expression Indexes
-- ============================================================================

-- Report date only (for daily grouping)
CREATE INDEX idx_road_reports_date 
    ON road_reports(DATE(reported_at AT TIME ZONE 'UTC'));

-- Report week (for weekly aggregations)
CREATE INDEX idx_road_reports_week 
    ON road_reports(DATE_TRUNC('week', reported_at));

-- Report month (for monthly aggregations)
CREATE INDEX idx_road_reports_month 
    ON road_reports(DATE_TRUNC('month', reported_at));
