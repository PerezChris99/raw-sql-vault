-- ============================================================================
-- Power Outage Pattern Analyzer - V002 Spatial Indexes
-- PostgreSQL 14+ with PostGIS 3.x
-- GIST and SP-GIST indexes for geospatial query optimization
-- ============================================================================

-- ============================================================================
-- Primary GIST Indexes (Spatial)
-- ============================================================================

-- Outages - main spatial queries
CREATE INDEX idx_outages_location_gist 
    ON outages USING GIST((location::geometry));

CREATE INDEX idx_outages_affected_area_gist 
    ON outages USING GIST(affected_area);

-- Districts - boundary containment checks
CREATE INDEX idx_districts_boundary_gist 
    ON districts USING GIST(boundary);

-- Regions - large area queries
CREATE INDEX idx_regions_boundary_gist 
    ON regions USING GIST(boundary);

-- Substations - point locations
CREATE INDEX idx_substations_location_gist 
    ON substations USING GIST((location::geometry));

-- Transformers - point locations
CREATE INDEX idx_transformers_location_gist 
    ON transformers USING GIST((location::geometry));

-- Power lines - route queries
CREATE INDEX idx_power_lines_route_gist 
    ON power_lines USING GIST(route);

-- Service points
CREATE INDEX idx_service_points_location_gist 
    ON service_points USING GIST((location::geometry));

-- Crews - current location for dispatch
CREATE INDEX idx_crews_current_location_gist 
    ON crews USING GIST((current_location::geometry))
    WHERE current_location IS NOT NULL;

-- Cluster analysis results
CREATE INDEX idx_outage_clusters_centroid_gist 
    ON outage_clusters USING GIST((centroid::geometry));

CREATE INDEX idx_outage_clusters_boundary_gist 
    ON outage_clusters USING GIST(boundary);

-- Infrastructure risk locations
CREATE INDEX idx_risk_scores_location_gist 
    ON infrastructure_risk_scores USING GIST((location::geometry));

-- ============================================================================
-- SP-GIST Indexes (Optimized for Point Nearest-Neighbor)
-- ============================================================================

-- For KNN (k-nearest neighbor) queries on outages
CREATE INDEX idx_outages_location_spgist 
    ON outages USING SPGIST((location::geometry));

-- For finding nearest transformers
CREATE INDEX idx_transformers_location_spgist 
    ON transformers USING SPGIST((location::geometry));

-- ============================================================================
-- B-Tree Indexes (Standard Lookups)
-- ============================================================================

-- Outages - temporal queries
CREATE INDEX idx_outages_occurred_at 
    ON outages(occurred_at DESC);

CREATE INDEX idx_outages_restored_at 
    ON outages(restored_at DESC) 
    WHERE restored_at IS NOT NULL;

-- Active outages (partial index for monitoring)
CREATE INDEX idx_outages_active 
    ON outages(occurred_at DESC, customers_affected DESC) 
    WHERE status NOT IN ('restored', 'closed');

-- Outages by status
CREATE INDEX idx_outages_status 
    ON outages(status, occurred_at DESC);

-- Outages by district and time
CREATE INDEX idx_outages_district_time 
    ON outages(district_id, occurred_at DESC);

-- Outages by cause
CREATE INDEX idx_outages_cause 
    ON outages(cause_id, occurred_at DESC);

-- Outages by severity
CREATE INDEX idx_outages_severity 
    ON outages(severity, occurred_at DESC);

-- Major events only
CREATE INDEX idx_outages_major_events 
    ON outages(occurred_at DESC, customers_affected DESC) 
    WHERE is_major_event = true;

-- Districts
CREATE INDEX idx_districts_region 
    ON districts(region_id);

CREATE INDEX idx_districts_code 
    ON districts(code);

-- Substations
CREATE INDEX idx_substations_district 
    ON substations(district_id);

CREATE INDEX idx_substations_status 
    ON substations(status);

-- Transformers
CREATE INDEX idx_transformers_district 
    ON transformers(district_id);

CREATE INDEX idx_transformers_status 
    ON transformers(status);

CREATE INDEX idx_transformers_age 
    ON transformers(age_years DESC) 
    WHERE age_years IS NOT NULL;

-- Power lines
CREATE INDEX idx_power_lines_start_substation 
    ON power_lines(start_substation_id);

CREATE INDEX idx_power_lines_end_substation 
    ON power_lines(end_substation_id);

CREATE INDEX idx_power_lines_status 
    ON power_lines(status);

-- Service points
CREATE INDEX idx_service_points_transformer 
    ON service_points(transformer_id);

CREATE INDEX idx_service_points_customer 
    ON service_points(customer_id);

-- Crew dispatches
CREATE INDEX idx_crew_dispatches_outage 
    ON crew_dispatches(outage_id, dispatched_at DESC);

CREATE INDEX idx_crew_dispatches_crew 
    ON crew_dispatches(crew_id, dispatched_at DESC);

CREATE INDEX idx_crew_dispatches_pending 
    ON crew_dispatches(dispatched_at DESC) 
    WHERE completed_at IS NULL;

-- Status history
CREATE INDEX idx_status_history_outage 
    ON outage_status_history(outage_id, changed_at DESC);

-- Outage updates
CREATE INDEX idx_outage_updates_outage 
    ON outage_updates(outage_id, created_at DESC);

-- Daily statistics
CREATE INDEX idx_daily_stats_date 
    ON daily_outage_statistics(stat_date DESC);

-- Cluster analysis
CREATE INDEX idx_outage_clusters_date_type 
    ON outage_clusters(analysis_date DESC, analysis_type);

-- Risk scores
CREATE INDEX idx_risk_scores_date_type 
    ON infrastructure_risk_scores(assessment_date DESC, entity_type);

CREATE INDEX idx_risk_scores_level 
    ON infrastructure_risk_scores(risk_level, assessment_date DESC) 
    WHERE risk_level IN ('high', 'critical');

-- Audit log
CREATE INDEX idx_audit_log_table_record 
    ON audit_log(table_name, record_id, performed_at DESC);

CREATE INDEX idx_audit_log_time 
    ON audit_log(performed_at DESC);

-- ============================================================================
-- Composite Indexes for Common Query Patterns
-- ============================================================================

-- Spatial + Temporal queries (most common pattern)
CREATE INDEX idx_outages_composite_time_location 
    ON outages(occurred_at DESC) 
    INCLUDE (location, customers_affected, status);

-- District + Status + Time
CREATE INDEX idx_outages_composite_district_status 
    ON outages(district_id, status, occurred_at DESC) 
    INCLUDE (customers_affected, location);

-- For cluster analysis
CREATE INDEX idx_outages_cluster_analysis 
    ON outages(occurred_at DESC)
    INCLUDE (location, duration_minutes, customers_affected, cause_id)
    WHERE occurred_at >= CURRENT_DATE - INTERVAL '1 year';

-- ============================================================================
-- Expression Indexes
-- ============================================================================

-- Outage date only (for daily grouping)
CREATE INDEX idx_outages_occurred_date 
    ON outages(DATE(occurred_at AT TIME ZONE 'UTC'));

-- Outage month (for monthly aggregations)
CREATE INDEX idx_outages_occurred_month 
    ON outages(DATE_TRUNC('month', occurred_at));

-- Outage week (for weekly reports)
CREATE INDEX idx_outages_occurred_week 
    ON outages(DATE_TRUNC('week', occurred_at));
