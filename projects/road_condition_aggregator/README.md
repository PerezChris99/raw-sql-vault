# Project #7: Road Condition Aggregator

## Problem Statement
Municipal road maintenance departments receive thousands of pothole and road damage reports across the city. Without spatial analysis, it's impossible to efficiently prioritize repairs, identify chronic problem areas, or optimize crew deployment routes.

## Solution
A PostGIS-powered road condition database that uses spatial clustering (ST_ClusterDBSCAN) and spatial joins to aggregate reports by location, calculate severity scores, and generate prioritized repair work orders.

## Sample Query (From Requirements)
```sql
-- Cluster road reports and calculate average severity per cluster
SELECT 
    ST_ClusterDBSCAN(geom, 0.01, 3) as cluster_id, 
    AVG(severity) as avg_severity
FROM road_reports 
GROUP BY cluster_id 
HAVING COUNT(*) > 5;
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     ROAD CONDITION AGGREGATOR                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │   Public    │    │   Field     │    │   Vehicle   │                 │
│  │   Reports   │───►│   Surveys   │───►│   Sensors   │                 │
│  │  (311 App)  │    │  (Crews)    │    │   (IoT)     │                 │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘                 │
│         │                  │                  │                         │
│         └──────────────────┼──────────────────┘                         │
│                            ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    PostgreSQL + PostGIS                          │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │   │
│  │  │road_reports │  │road_segments│  │repair_work_orders       │  │   │
│  │  │  (POINT)    │  │(LINESTRING) │  │  (clustered repairs)    │  │   │
│  │  └──────┬──────┘  └──────┬──────┘  └─────────────────────────┘  │   │
│  │         │                │                                       │   │
│  │         ▼                ▼                                       │   │
│  │  ┌─────────────────────────────────────────────────────────────┐│   │
│  │  │              SPATIAL ANALYSIS ENGINE                        ││   │
│  │  │  • ST_ClusterDBSCAN - Group nearby reports                  ││   │
│  │  │  • ST_DWithin - Find reports near road segments             ││   │
│  │  │  • ST_Buffer - Create repair zones                          ││   │
│  │  │  • ST_Intersects - Match reports to roads                   ││   │
│  │  │  • ST_Length - Calculate affected road length               ││   │
│  │  └─────────────────────────────────────────────────────────────┘│   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                            │                                            │
│                            ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    OUTPUT & INTEGRATION                          │   │
│  │  • Prioritized repair queue                                      │   │
│  │  • Crew dispatch routes                                          │   │
│  │  • GeoJSON for mapping                                           │   │
│  │  • Budget impact analysis                                        │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key PostGIS Functions

| Function | Purpose | Usage |
|----------|---------|-------|
| `ST_ClusterDBSCAN` | Density-based clustering | Group nearby reports into work zones |
| `ST_DWithin` | Distance-based filtering | Find reports within X meters of roads |
| `ST_Buffer` | Create buffer zones | Define repair work areas |
| `ST_Intersects` | Spatial intersection | Match reports to road segments |
| `ST_SnapToGrid` | Grid aggregation | Heat map generation |
| `ST_Length` | Line measurement | Calculate affected road length |
| `ST_Union` | Merge geometries | Combine clustered repair areas |
| `ST_Centroid` | Center point | Find cluster center for crew dispatch |

## Database Schema

### Core Tables
- **road_reports** - Citizen reports with point geometry and severity (1-10)
- **road_segments** - Road network with linestring geometry
- **report_clusters** - Pre-computed DBSCAN clusters
- **repair_work_orders** - Generated repair tasks with priority

### Reference Tables
- **damage_types** - Pothole, crack, sinkhole, etc.
- **severity_levels** - 1-10 scale definitions
- **road_classifications** - Highway, arterial, residential, etc.
- **districts** - Administrative boundaries
- **crews** - Repair crew assignments

## Project Structure

```
road_condition_aggregator/
├── README.md
├── .env.example
├── docs/
│   └── ARCHITECTURE.md
├── database/
│   ├── migrations/
│   │   ├── V001__initial_schema.sql
│   │   ├── V002__spatial_indexes.sql
│   │   ├── V003__triggers.sql
│   │   └── V004__spatial_views.sql
│   ├── seeds/
│   │   ├── 01_reference_data.sql
│   │   └── 02_sample_data.sql
│   └── functions/
│       └── analytics/
│           ├── clustering_functions.sql
│           └── priority_scoring.sql
├── scripts/
│   ├── reports/
│   │   ├── priority_queue.sql
│   │   ├── cluster_analysis.sql
│   │   └── district_summary.sql
│   └── run_report.ps1
└── tests/
    └── test_spatial_clustering.sql
```

## Quick Start

```powershell
# 1. Create database with PostGIS
psql -U postgres -c "CREATE DATABASE road_condition_db;"
psql -U postgres -d road_condition_db -c "CREATE EXTENSION postgis;"

# 2. Run migrations
psql -U postgres -d road_condition_db -f database/migrations/V001__initial_schema.sql
psql -U postgres -d road_condition_db -f database/migrations/V002__spatial_indexes.sql
psql -U postgres -d road_condition_db -f database/migrations/V003__triggers.sql
psql -U postgres -d road_condition_db -f database/migrations/V004__spatial_views.sql

# 3. Load reference and sample data
psql -U postgres -d road_condition_db -f database/seeds/01_reference_data.sql
psql -U postgres -d road_condition_db -f database/seeds/02_sample_data.sql

# 4. Load functions
psql -U postgres -d road_condition_db -f database/functions/analytics/clustering_functions.sql
psql -U postgres -d road_condition_db -f database/functions/analytics/priority_scoring.sql

# 5. Run tests
psql -U postgres -d road_condition_db -f tests/test_spatial_clustering.sql

# 6. Generate reports
.\scripts\run_report.ps1 -ReportType priority
```

## Sample Queries

### Cluster Reports by Location (User's Sample)
```sql
SELECT 
    ST_ClusterDBSCAN(geom, 0.01, 3) OVER () as cluster_id, 
    AVG(severity) as avg_severity,
    COUNT(*) as report_count
FROM road_reports 
GROUP BY cluster_id 
HAVING COUNT(*) > 5
ORDER BY avg_severity DESC;
```

### Prioritized Repair Queue
```sql
SELECT 
    cluster_id,
    ST_Centroid(ST_Collect(location::geometry)) as work_center,
    COUNT(*) as report_count,
    ROUND(AVG(severity), 1) as avg_severity,
    SUM(CASE WHEN damage_type = 'pothole' THEN 1 ELSE 0 END) as pothole_count,
    MAX(reported_at) as latest_report,
    -- Priority score: severity * report_density * road_importance
    ROUND(AVG(severity) * COUNT(*) * AVG(road_class_weight), 1) as priority_score
FROM clustered_reports cr
JOIN road_segments rs ON ST_DWithin(cr.location, rs.geom, 10)
GROUP BY cluster_id
ORDER BY priority_score DESC;
```

### Reports Near High-Traffic Roads
```sql
SELECT 
    rs.road_name,
    rs.traffic_class,
    COUNT(rr.report_id) as report_count,
    AVG(rr.severity) as avg_severity,
    ST_Length(rs.geom::geography) as road_length_m
FROM road_segments rs
JOIN road_reports rr ON ST_DWithin(rs.geom, rr.location::geometry, 15)
WHERE rs.traffic_class IN ('highway', 'arterial')
  AND rr.reported_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY rs.segment_id, rs.road_name, rs.traffic_class, rs.geom
HAVING COUNT(rr.report_id) >= 3
ORDER BY avg_severity DESC;
```

## Tech Stack
- **Database**: PostgreSQL 14+
- **Spatial Extension**: PostGIS 3.x
- **Key Concepts**: DBSCAN clustering, spatial joins, priority scoring
- **Scripting**: psql, PowerShell

## SQL Concepts Demonstrated
- `ST_ClusterDBSCAN` for density-based spatial clustering
- Spatial joins with `ST_DWithin` and `ST_Intersects`
- Window functions for cluster assignment
- Aggregate functions with `FILTER` clause
- Priority scoring algorithms
- GeoJSON export for visualization

## Learning Objectives
1. Apply DBSCAN clustering to real-world spatial data
2. Use spatial joins to correlate point and line geometries
3. Build priority scoring systems with multiple factors
4. Generate work orders from clustered reports
5. Optimize spatial queries with proper indexing
