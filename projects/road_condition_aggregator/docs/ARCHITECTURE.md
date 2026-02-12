# Road Condition Aggregator - Architecture

## Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   districts     │       │road_classific.  │       │  damage_types   │
├─────────────────┤       ├─────────────────┤       ├─────────────────┤
│ PK district_id  │       │ PK class_id     │       │ PK damage_id    │
│    name         │       │    name         │       │    name         │
│    boundary     │       │    priority_wt  │       │    severity_wt  │
│    (POLYGON)    │       │    speed_limit  │       │    repair_cost  │
└────────┬────────┘       └────────┬────────┘       └────────┬────────┘
         │                         │                         │
         │         ┌───────────────┴───────────────┐         │
         │         │                               │         │
         ▼         ▼                               ▼         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         road_segments                                │
├─────────────────────────────────────────────────────────────────────┤
│ PK segment_id                                                        │
│ FK district_id → districts                                           │
│ FK road_class_id → road_classifications                              │
│    road_name                                                         │
│    geom (LINESTRING)                                                 │
│    length_m (auto-calculated)                                        │
│    traffic_volume                                                    │
│    last_maintenance_date                                             │
│    pavement_condition (1-10)                                         │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 │ ST_DWithin / ST_Intersects
                                 │
┌────────────────────────────────┴────────────────────────────────────┐
│                         road_reports                                 │
├─────────────────────────────────────────────────────────────────────┤
│ PK report_id (UUID)                                                  │
│ FK district_id → districts                                           │
│ FK segment_id → road_segments (nullable, auto-matched)               │
│ FK damage_type_id → damage_types                                     │
│    location (POINT - GEOGRAPHY)                                      │
│    severity (1-10)                                                   │
│    source (citizen/survey/sensor)                                    │
│    reported_at                                                       │
│    verified_at                                                       │
│    status (new/verified/scheduled/repaired)                          │
│    photo_url                                                         │
│    notes                                                             │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ report_clusters │    │repair_work_orders│   │ cluster_history │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ PK cluster_id   │    │ PK work_order_id│    │ PK history_id   │
│    analysis_date│    │ FK cluster_id   │    │ FK cluster_id   │
│    centroid     │    │ FK crew_id      │    │    snapshot_date│
│    boundary     │    │    priority_score│   │    report_count │
│    report_count │    │    status       │    │    avg_severity │
│    avg_severity │    │    scheduled_dt │    └─────────────────┘
│    priority_score    │    completed_dt │
└─────────────────┘    │    actual_cost  │
                       └─────────────────┘
```

## Spatial Clustering Strategy

### DBSCAN Parameters

```sql
-- ST_ClusterDBSCAN(geometry, eps, minpoints)
-- eps: Maximum distance between points in same cluster (in geometry units)
-- minpoints: Minimum points to form a dense region

-- For road reports in WGS84 (degrees):
-- 0.0001° ≈ 11 meters
-- 0.001°  ≈ 111 meters
-- 0.01°   ≈ 1.1 kilometers

-- Recommended settings by context:
-- Urban dense:    eps=0.0002 (22m),  minpoints=3
-- Urban standard: eps=0.0005 (55m),  minpoints=3
-- Suburban:       eps=0.001  (111m), minpoints=2
-- Highway:        eps=0.002  (222m), minpoints=2
```

### Cluster-Based Work Order Generation

```sql
-- Step 1: Cluster recent reports
WITH clustered AS (
    SELECT 
        report_id,
        location,
        severity,
        damage_type_id,
        ST_ClusterDBSCAN(location::geometry, 0.0005, 3) OVER () as cluster_id
    FROM road_reports
    WHERE reported_at >= CURRENT_DATE - INTERVAL '30 days'
      AND status IN ('new', 'verified')
)
-- Step 2: Aggregate cluster statistics
SELECT 
    cluster_id,
    COUNT(*) as report_count,
    AVG(severity) as avg_severity,
    ST_Centroid(ST_Collect(location::geometry)) as work_center,
    ST_ConvexHull(ST_Collect(location::geometry)) as work_area
FROM clustered
WHERE cluster_id IS NOT NULL  -- Exclude noise points
GROUP BY cluster_id
HAVING COUNT(*) >= 3;
```

## Priority Scoring Algorithm

```sql
-- Priority Score = Base Score × Modifiers

-- Base Score Components:
--   severity_factor   = AVG(severity) / 10        -- 0.1 to 1.0
--   density_factor    = LOG(report_count + 1)     -- More reports = higher priority
--   age_factor        = 1 + (days_since_oldest / 30) * 0.5  -- Older = higher

-- Modifier Components:
--   road_importance   = road_class_weight         -- Highway(3), Arterial(2), Local(1)
--   traffic_factor    = LOG(traffic_volume / 1000 + 1)
--   safety_factor     = damage_type_weight        -- Sinkhole(3), Pothole(2), Crack(1)

priority_score = (
    (avg_severity / 10) * 40 +           -- Severity: up to 40 points
    LOG(report_count + 1) * 20 +         -- Density: up to 20 points
    (days_oldest / 30) * 10              -- Age: up to 10 points
) * road_importance * safety_factor;
```

## Spatial Join Patterns

### Reports to Road Segments
```sql
-- Find the nearest road segment for each report
SELECT DISTINCT ON (rr.report_id)
    rr.report_id,
    rs.segment_id,
    rs.road_name,
    ST_Distance(rr.location, rs.geom::geography) as distance_m
FROM road_reports rr
JOIN road_segments rs ON ST_DWithin(
    rr.location,
    rs.geom::geography,
    50  -- 50 meter search radius
)
ORDER BY rr.report_id, ST_Distance(rr.location, rs.geom::geography);
```

### Aggregate Reports by Road Segment
```sql
SELECT 
    rs.segment_id,
    rs.road_name,
    rs.road_class,
    ST_Length(rs.geom::geography) as length_m,
    COUNT(rr.report_id) as report_count,
    COUNT(rr.report_id) / (ST_Length(rs.geom::geography) / 100) as reports_per_100m,
    AVG(rr.severity) as avg_severity,
    ARRAY_AGG(DISTINCT dt.name) as damage_types
FROM road_segments rs
LEFT JOIN road_reports rr ON ST_DWithin(rs.geom::geography, rr.location, 15)
LEFT JOIN damage_types dt ON rr.damage_type_id = dt.damage_id
WHERE rr.reported_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY rs.segment_id, rs.road_name, rs.road_class, rs.geom;
```

## Indexing Strategy

### GIST Indexes for Spatial Queries
```sql
-- Primary spatial indexes
CREATE INDEX idx_road_reports_location_gist 
    ON road_reports USING GIST((location::geometry));

CREATE INDEX idx_road_segments_geom_gist 
    ON road_segments USING GIST(geom);

CREATE INDEX idx_districts_boundary_gist 
    ON districts USING GIST(boundary);

-- Cluster analysis index
CREATE INDEX idx_report_clusters_centroid_gist 
    ON report_clusters USING GIST((centroid::geometry));

CREATE INDEX idx_report_clusters_boundary_gist 
    ON report_clusters USING GIST(boundary);
```

### Composite Indexes for Filtered Spatial Queries
```sql
-- Status + Location (common query pattern)
CREATE INDEX idx_reports_status_location ON road_reports(status)
    INCLUDE (location) WHERE status IN ('new', 'verified');

-- Time + Severity for priority filtering
CREATE INDEX idx_reports_time_severity 
    ON road_reports(reported_at DESC, severity DESC);

-- District + Status for administrative queries
CREATE INDEX idx_reports_district_status 
    ON road_reports(district_id, status, reported_at DESC);
```

## Work Order Generation Flow

```
┌─────────────────┐
│ 1. Collect      │  Fresh reports from last N days
│    Reports      │  Filter by status (new, verified)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 2. Run DBSCAN   │  ST_ClusterDBSCAN(geom, eps, minpoints)
│    Clustering   │  Identify dense report areas
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 3. Calculate    │  Aggregate reports per cluster
│    Statistics   │  avg_severity, count, age, damage types
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 4. Join Roads   │  ST_DWithin to find affected segments
│    Data         │  Get road class, traffic volume
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 5. Calculate    │  Apply priority scoring formula
│    Priority     │  Sort by priority_score DESC
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 6. Generate     │  Create repair_work_orders
│    Work Orders  │  Assign crews, schedule dates
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ 7. Export       │  GeoJSON for field crews
│    Routes       │  Optimized repair sequence
└─────────────────┘
```

## GeoJSON Export Format

```sql
SELECT json_build_object(
    'type', 'FeatureCollection',
    'generated_at', CURRENT_TIMESTAMP,
    'features', json_agg(
        json_build_object(
            'type', 'Feature',
            'geometry', ST_AsGeoJSON(work_center)::json,
            'properties', json_build_object(
                'cluster_id', cluster_id,
                'report_count', report_count,
                'avg_severity', avg_severity,
                'priority_score', priority_score,
                'work_order_id', work_order_id,
                'scheduled_date', scheduled_date,
                'affected_roads', affected_roads
            )
        )
    )
) as geojson
FROM vw_work_order_map;
```

## Integration Patterns

### 311 System Integration
```sql
-- Incoming report from 311 API
INSERT INTO road_reports (
    location, severity, damage_type_id, source, notes
) VALUES (
    ST_GeogFromText('POINT(-122.4194 37.7749)'),
    7,
    (SELECT damage_id FROM damage_types WHERE name = 'pothole'),
    'citizen',
    'Large pothole near intersection'
);
-- Triggers auto-assign district, match segment, update cluster
```

### Real-Time Dashboard Query
```sql
-- Active clusters with work order status
SELECT 
    rc.cluster_id,
    rc.centroid,
    rc.report_count,
    rc.avg_severity,
    rc.priority_score,
    wo.status as work_order_status,
    wo.scheduled_date,
    c.name as assigned_crew
FROM report_clusters rc
LEFT JOIN repair_work_orders wo ON rc.cluster_id = wo.cluster_id
LEFT JOIN crews c ON wo.crew_id = c.crew_id
WHERE rc.analysis_date = CURRENT_DATE
ORDER BY rc.priority_score DESC;
```

## Performance Considerations

### Query Optimization
```sql
-- Use && operator for bounding box pre-filter
SELECT * FROM road_reports rr
WHERE rr.location::geometry && ST_MakeEnvelope(-122.5, 37.7, -122.3, 37.9, 4326)
  AND ST_DWithin(rr.location, target_segment::geography, 25);

-- Limit cluster analysis to manageable dataset
WITH recent_reports AS (
    SELECT location, severity FROM road_reports
    WHERE reported_at >= CURRENT_DATE - INTERVAL '30 days'
      AND status IN ('new', 'verified')
    LIMIT 10000  -- Cap for performance
)
SELECT ST_ClusterDBSCAN(location::geometry, 0.0005, 3) OVER () as cluster
FROM recent_reports;
```

### Materialized Views for Reports
```sql
-- Pre-compute daily cluster snapshot
CREATE MATERIALIZED VIEW mv_daily_clusters AS
SELECT 
    CURRENT_DATE as analysis_date,
    cluster_id,
    ST_Centroid(ST_Collect(location::geometry)) as centroid,
    ST_ConvexHull(ST_Collect(location::geometry)) as boundary,
    COUNT(*) as report_count,
    AVG(severity) as avg_severity
FROM (
    SELECT 
        report_id,
        location,
        severity,
        ST_ClusterDBSCAN(location::geometry, 0.0005, 3) OVER () as cluster_id
    FROM road_reports
    WHERE reported_at >= CURRENT_DATE - INTERVAL '30 days'
) clustered
WHERE cluster_id IS NOT NULL
GROUP BY cluster_id;

-- Refresh nightly
REFRESH MATERIALIZED VIEW mv_daily_clusters;
```
