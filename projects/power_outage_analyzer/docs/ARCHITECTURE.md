# Power Outage Pattern Analyzer - Architecture

## System Design

### Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│    regions      │       │   districts     │       │   substations   │
├─────────────────┤       ├─────────────────┤       ├─────────────────┤
│ PK region_id    │◄──┐   │ PK district_id  │◄──┐   │ PK substation_id│
│    name         │   │   │ FK region_id    │   │   │ FK district_id  │
│    boundary     │   │   │    name         │   │   │    name         │
│    (POLYGON)    │   │   │    boundary     │   │   │    location     │
└─────────────────┘   │   │    (POLYGON)    │   │   │    (POINT)      │
                      │   └─────────────────┘   │   │    capacity_kva │
                      │            │            │   └────────┬────────┘
                      │            │            │            │
         ┌────────────┴────────────┴────────────┴────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────┐
│                          power_lines                                 │
├─────────────────────────────────────────────────────────────────────┤
│ PK line_id                                                          │
│ FK start_substation_id → substations                                │
│ FK end_substation_id → substations                                  │
│    line_type (transmission/distribution)                            │
│    voltage_kv                                                       │
│    route (LINESTRING)                                               │
│    length_km                                                        │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                                 │
┌─────────────────┐              │              ┌─────────────────┐
│  transformers   │              │              │  service_points │
├─────────────────┤              │              ├─────────────────┤
│ PK transformer_id◄─────────────┼──────────────│ PK service_id   │
│ FK line_id      │              │              │ FK transformer_id
│ FK district_id  │              │              │    customer_id  │
│    location     │              │              │    location     │
│    (POINT)      │              │              │    (POINT)      │
│    capacity_kva │              │              │    service_type │
│    age_years    │              │              └────────┬────────┘
└────────┬────────┘              │                       │
         │                       │                       │
         │    ┌──────────────────┴───────────────────┐   │
         │    │                                      │   │
         ▼    ▼                                      ▼   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                            outages                                   │
├─────────────────────────────────────────────────────────────────────┤
│ PK outage_id (UUID)                                                 │
│ FK district_id → districts                                          │
│ FK transformer_id → transformers (nullable)                         │
│ FK line_id → power_lines (nullable)                                 │
│ FK cause_id → outage_causes                                         │
│    location (POINT - GEOGRAPHY)                                     │
│    affected_area (POLYGON - nullable)                               │
│    occurred_at (TIMESTAMPTZ)                                        │
│    restored_at (TIMESTAMPTZ)                                        │
│    duration_minutes                                                 │
│    customers_affected                                               │
│    estimated_load_lost_kw                                           │
│    weather_condition                                                │
│    is_planned                                                       │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  outage_causes  │    │ crew_dispatches │    │  outage_updates │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ PK cause_id     │    │ PK dispatch_id  │    │ PK update_id    │
│    name         │    │ FK outage_id    │    │ FK outage_id    │
│    category     │    │ FK crew_id      │    │    update_time  │
│    is_weather   │    │    dispatched_at│    │    message      │
│    avg_repair_hrs    │    arrived_at   │    │    est_restore  │
└─────────────────┘    │    completed_at │    └─────────────────┘
                       └─────────────────┘
```

## PostGIS Geospatial Strategy

### 1. K-Means Clustering for Hotspot Detection

```sql
-- Identify clusters of outages using K-Means algorithm
WITH clustered AS (
    SELECT 
        outage_id,
        location,
        ST_ClusterKMeans(location::geometry, 5) OVER () as cluster_id
    FROM outages
    WHERE occurred_at >= CURRENT_DATE - INTERVAL '6 months'
)
SELECT 
    cluster_id,
    COUNT(*) as outage_count,
    ST_Centroid(ST_Collect(location::geometry)) as cluster_center,
    ST_ConvexHull(ST_Collect(location::geometry)) as cluster_boundary,
    AVG(duration_minutes) as avg_duration
FROM clustered
GROUP BY cluster_id
ORDER BY outage_count DESC;
```

### 2. DBSCAN Density-Based Clustering

```sql
-- Find dense clusters with minimum 5 points within 500 meters
SELECT 
    ST_ClusterDBSCAN(location::geometry, eps := 500, minpoints := 5) OVER () as cluster_id,
    outage_id,
    location,
    occurred_at
FROM outages
WHERE occurred_at >= CURRENT_DATE - INTERVAL '90 days';
```

### 3. Proximity Analysis with ST_DWithin

```sql
-- Find all outages within 1km of failing transformers
SELECT 
    t.transformer_id,
    t.name,
    o.outage_id,
    ST_Distance(t.location::geography, o.location) as distance_meters
FROM transformers t
JOIN outages o ON ST_DWithin(
    t.location::geography, 
    o.location, 
    1000  -- 1000 meters
)
WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '1 year'
ORDER BY t.transformer_id, distance_meters;
```

### 4. Buffer Zone Analysis

```sql
-- Create risk zones around high-failure transformers
SELECT 
    t.transformer_id,
    ST_Buffer(t.location::geography, 500)::geometry as risk_zone_500m,
    ST_Buffer(t.location::geography, 1000)::geometry as risk_zone_1km,
    COUNT(o.outage_id) as nearby_outages
FROM transformers t
LEFT JOIN outages o ON ST_DWithin(t.location::geography, o.location, 1000)
GROUP BY t.transformer_id, t.location
HAVING COUNT(o.outage_id) >= 5;
```

### 5. Spatial Aggregation by District

```sql
-- Outage statistics by district boundary
SELECT 
    d.district_id,
    d.name as district_name,
    ST_Area(d.boundary::geography) / 1000000 as area_sq_km,
    COUNT(o.outage_id) as total_outages,
    SUM(o.customers_affected) as total_customers_affected,
    COUNT(o.outage_id)::FLOAT / (ST_Area(d.boundary::geography) / 1000000) as outages_per_sq_km
FROM districts d
LEFT JOIN outages o ON ST_Contains(d.boundary, o.location::geometry)
WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY d.district_id, d.name, d.boundary
ORDER BY outages_per_sq_km DESC;
```

### 6. Power Line Intersection Analysis

```sql
-- Find where power lines cross and might be vulnerable
SELECT 
    l1.line_id as line_1,
    l2.line_id as line_2,
    ST_Intersection(l1.route, l2.route) as intersection_point,
    l1.voltage_kv + l2.voltage_kv as combined_voltage
FROM power_lines l1
JOIN power_lines l2 ON l1.line_id < l2.line_id
    AND ST_Intersects(l1.route, l2.route)
WHERE l1.line_type = 'transmission' 
   OR l2.line_type = 'transmission';
```

## Indexing Strategy for Geospatial Queries

### GIST Indexes (Primary Spatial Index)

```sql
-- Essential spatial indexes
CREATE INDEX idx_outages_location_gist ON outages USING GIST(location);
CREATE INDEX idx_outages_affected_area_gist ON outages USING GIST(affected_area);
CREATE INDEX idx_districts_boundary_gist ON districts USING GIST(boundary);
CREATE INDEX idx_transformers_location_gist ON transformers USING GIST(location);
CREATE INDEX idx_power_lines_route_gist ON power_lines USING GIST(route);
CREATE INDEX idx_substations_location_gist ON substations USING GIST(location);
```

### SP-GIST Indexes (Point Data Optimization)

```sql
-- For point-only data (faster for nearest-neighbor queries)
CREATE INDEX idx_outages_location_spgist ON outages USING SPGIST(location);
```

### Composite Indexes (Spatial + Temporal)

```sql
-- Common query pattern: recent outages in area
CREATE INDEX idx_outages_time_location ON outages(occurred_at, location);

-- For filtering by district then spatial
CREATE INDEX idx_outages_district_location ON outages(district_id) 
    INCLUDE (location, occurred_at);
```

## Coordinate Reference Systems

### Storage Format (EPSG:4326 - WGS 84)
```sql
-- Store all coordinates in WGS 84
ALTER TABLE outages 
    ADD CONSTRAINT enforce_srid_location 
    CHECK (ST_SRID(location::geometry) = 4326);
```

### Calculation Projections
```sql
-- Use geography type for accurate distance (meters)
SELECT ST_Distance(
    a.location::geography,  -- Auto-converts to meters
    b.location::geography
) as distance_meters
FROM outages a, outages b;

-- Or transform to local UTM for area calculations
SELECT ST_Area(
    ST_Transform(boundary, 32637)  -- UTM Zone 37N example
) as area_sq_meters
FROM districts;
```

## Performance Considerations

### Query Optimization

```sql
-- Use && operator for bounding box pre-filter
SELECT * FROM outages o
WHERE o.location && ST_MakeEnvelope(-122.5, 37.5, -122.0, 38.0, 4326)
AND ST_Contains(district_polygon, o.location::geometry);

-- Limit cluster analysis to relevant time period
WITH recent_outages AS (
    SELECT location FROM outages
    WHERE occurred_at >= CURRENT_DATE - INTERVAL '90 days'
)
SELECT ST_ClusterKMeans(location::geometry, 10) OVER () as cluster
FROM recent_outages;
```

### Materialized Views for Heavy Analysis

```sql
-- Pre-compute cluster assignments nightly
CREATE MATERIALIZED VIEW mv_outage_clusters AS
SELECT 
    outage_id,
    location,
    occurred_at,
    ST_ClusterDBSCAN(location::geometry, eps := 500, minpoints := 3) OVER (
        PARTITION BY DATE_TRUNC('month', occurred_at)
    ) as monthly_cluster_id
FROM outages
WHERE occurred_at >= CURRENT_DATE - INTERVAL '24 months';

CREATE INDEX idx_mv_clusters ON mv_outage_clusters(monthly_cluster_id);
REFRESH MATERIALIZED VIEW mv_outage_clusters;
```

## GeoJSON Export for Visualization

```sql
-- Export outage clusters as GeoJSON for mapping
SELECT json_build_object(
    'type', 'FeatureCollection',
    'features', json_agg(
        json_build_object(
            'type', 'Feature',
            'geometry', ST_AsGeoJSON(cluster_center)::json,
            'properties', json_build_object(
                'cluster_id', cluster_id,
                'outage_count', outage_count,
                'avg_duration', avg_duration
            )
        )
    )
) as geojson
FROM vw_outage_hotspots;
```

## Integration Patterns

### Real-Time Outage Mapping
```sql
-- Get active outages with affected areas for live map
SELECT 
    outage_id,
    ST_AsGeoJSON(location) as location_geojson,
    ST_AsGeoJSON(affected_area) as affected_area_geojson,
    customers_affected,
    occurred_at,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - occurred_at))/3600 as hours_ongoing
FROM outages
WHERE restored_at IS NULL
ORDER BY customers_affected DESC;
```

### Crew Dispatch Optimization
```sql
-- Find nearest available crew to new outage
SELECT 
    c.crew_id,
    c.current_location,
    ST_Distance(c.current_location::geography, :new_outage_location::geography) as distance_m,
    c.specialization
FROM crews c
WHERE c.status = 'available'
ORDER BY c.current_location::geography <-> :new_outage_location::geography
LIMIT 5;
```
