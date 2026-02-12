# Power Outage Pattern Analyzer

**Project #6** in the Raw SQL Vault - PostgreSQL/PostGIS geospatial analytics for identifying grid failure hotspots.

## Problem Statement

Utility companies need to identify patterns in power outages to:
- Locate infrastructure weak points requiring upgrades
- Predict future failures based on geographic clustering
- Optimize maintenance crew deployment
- Reduce customer impact through proactive intervention

## Solution

An Incidents Database with comprehensive geospatial aggregates using PostGIS functions for spatial clustering, proximity analysis, and hotspot detection.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      POWER OUTAGE PATTERN ANALYZER                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   Outage    │───▶│    Grid     │───▶│  Geospatial │───▶│   Pattern   │  │
│  │   Reports   │    │  Infrastructure  │   Analysis  │    │  Detection  │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│         │                 │                   │                  │          │
│         ▼                 ▼                   ▼                  ▼          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    PostGIS GEOSPATIAL ENGINE                        │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │   │
│  │  │ST_Cluster│ │ST_Within │ │ST_DWithin│ │ST_Buffer │ │ST_Centroid  │   │
│  │  │  KMeans  │ │ Distance │ │ Proximity│ │  Zones   │ │  Points  │  │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘  │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │   │
│  │  │ST_Contains│ ST_Intersect│ ST_Area  │ │ST_ConvexHull │ ST_Union │  │   │
│  │  │  Region  │ │ Overlap  │ │ Calculate│ │  Boundary│ │ Combine  │  │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       ANALYTICS OUTPUTS                             │   │
│  │  • Hotspot Maps       • Cluster Analysis    • Infrastructure Risk  │   │
│  │  • Proximity Reports  • Service Area Stats  • Maintenance Priority │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key SQL Features Demonstrated

### PostGIS Spatial Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `ST_ClusterKMeans` | K-means clustering | `ST_ClusterKMeans(geom, 5) OVER ()` |
| `ST_ClusterDBSCAN` | Density-based clustering | `ST_ClusterDBSCAN(geom, eps, minpoints) OVER ()` |
| `ST_DWithin` | Proximity search | `ST_DWithin(a.geom, b.geom, 1000)` |
| `ST_Buffer` | Create buffer zones | `ST_Buffer(geom, 500)` |
| `ST_Centroid` | Calculate center point | `ST_Centroid(ST_Collect(geom))` |
| `ST_ConvexHull` | Bounding polygon | `ST_ConvexHull(ST_Collect(geom))` |
| `ST_Contains` | Containment test | `ST_Contains(district.geom, outage.geom)` |
| `ST_Intersects` | Intersection test | `ST_Intersects(line.geom, polygon.geom)` |
| `ST_Distance` | Calculate distance | `ST_Distance(a.geom, b.geom)` |
| `ST_Area` | Calculate area | `ST_Area(geom::geography)` |
| `ST_Transform` | Coordinate transformation | `ST_Transform(geom, 4326)` |

### Sample Queries

**Core Query - District Clustering (from requirements):**
```sql
SELECT 
    district,
    COUNT(*) as outages,
    ST_ClusterKMeans(geom, 5) OVER () as cluster
FROM outages
GROUP BY district;
```

**Hotspot Detection with DBSCAN:**
```sql
SELECT 
    ST_ClusterDBSCAN(location, eps := 500, minpoints := 5) OVER () as cluster_id,
    COUNT(*) as outage_count,
    ST_Centroid(ST_Collect(location)) as cluster_center,
    AVG(duration_minutes) as avg_duration
FROM outages
WHERE occurred_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY cluster_id
HAVING COUNT(*) >= 5;
```

**Infrastructure Risk Analysis:**
```sql
SELECT 
    t.transformer_id,
    t.location,
    COUNT(o.outage_id) as outages_nearby,
    AVG(o.customers_affected) as avg_customers_impacted,
    ST_Buffer(t.location, 500) as risk_zone
FROM transformers t
LEFT JOIN outages o ON ST_DWithin(t.location, o.location, 500)
WHERE o.occurred_at >= CURRENT_DATE - INTERVAL '1 year'
GROUP BY t.transformer_id, t.location
HAVING COUNT(o.outage_id) >= 3
ORDER BY outages_nearby DESC;
```

**Service Area Coverage:**
```sql
SELECT 
    d.district_name,
    ST_Area(d.boundary::geography) / 1000000 as area_sq_km,
    COUNT(o.outage_id) as total_outages,
    COUNT(o.outage_id) / (ST_Area(d.boundary::geography) / 1000000) as outages_per_sq_km
FROM districts d
LEFT JOIN outages o ON ST_Contains(d.boundary, o.location)
GROUP BY d.district_id, d.district_name, d.boundary;
```

## Tech Stack

- **Database**: PostgreSQL 14+ with PostGIS 3.x
- **Extensions**: postgis, postgis_topology, postgis_raster
- **Coordinate Systems**: WGS 84 (EPSG:4326) for storage, local projections for calculations
- **Visualization**: GeoJSON export for mapping tools

## Project Structure

```
power_outage_analyzer/
├── README.md
├── docs/
│   └── ARCHITECTURE.md
├── database/
│   ├── migrations/
│   │   ├── V001__schema_setup.sql
│   │   ├── V002__indexes.sql
│   │   ├── V003__triggers.sql
│   │   └── V004__views.sql
│   ├── seeds/
│   │   ├── 01_reference_data.sql
│   │   └── 02_sample_data.sql
│   └── functions/
│       └── analytics/
│           ├── clustering_functions.sql
│           └── hotspot_analysis.sql
├── scripts/
│   ├── analysis/
│   │   ├── hotspot_detection.sql
│   │   ├── infrastructure_risk.sql
│   │   └── service_area_analysis.sql
│   └── deploy.ps1
├── tests/
│   └── test_geospatial_analytics.sql
└── .env.example
```

## Quick Start

1. **Install PostGIS Extension**:
```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
```

2. **Create Database**:
```bash
createdb power_outage_analyzer
psql -d power_outage_analyzer -c "CREATE EXTENSION postgis;"
```

3. **Run Migrations**:
```bash
psql -d power_outage_analyzer -f database/migrations/V001__schema_setup.sql
psql -d power_outage_analyzer -f database/migrations/V002__indexes.sql
psql -d power_outage_analyzer -f database/migrations/V003__triggers.sql
psql -d power_outage_analyzer -f database/migrations/V004__views.sql
```

4. **Load Seed Data**:
```bash
psql -d power_outage_analyzer -f database/seeds/01_reference_data.sql
psql -d power_outage_analyzer -f database/seeds/02_sample_data.sql
```

5. **Run Analysis**:
```bash
psql -d power_outage_analyzer -f scripts/analysis/hotspot_detection.sql
```

## Analysis Types

| Analysis | Description | Output |
|----------|-------------|--------|
| Hotspot Detection | K-means/DBSCAN clustering of outages | Cluster centers & boundaries |
| Infrastructure Risk | Equipment near frequent outages | Risk scores by transformer/line |
| Service Area | District-level statistics | Outage density maps |
| Temporal Patterns | Time-based geographic analysis | Peak hour/season hotspots |
| Network Topology | Power line intersection analysis | Vulnerable connection points |

## Coordinate Reference Systems

- **Storage**: EPSG:4326 (WGS 84) - Standard lat/lng
- **Area Calculations**: Geography type or local UTM projection
- **Distance**: Meters (using geography or ST_Transform)

## License

MIT License - Part of the Raw SQL Vault learning project.
