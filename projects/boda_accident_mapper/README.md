# 🏍️ Boda Accident Hotspot Mapper

> **Project #11** - Cluster motorcycle accident fatalities for safety analysis using NTILE and PostGIS

## Problem Statement

Boda-boda (motorcycle taxi) accidents are a leading cause of injury in Uganda:
- No systematic analysis of accident hotspots
- Limited data-driven traffic safety interventions
- Difficulty prioritizing safety infrastructure investments

## Solution

SQL-based accident analysis using **NTILE()** for risk quartiles and **PostGIS** for spatial clustering to:
- Identify high-risk districts and intersections
- Classify areas into risk quartiles
- Map accident clusters geographically
- Guide safety interventions

## Sample Query (User Requirement)

```sql
SELECT 
    district, 
    COUNT(*) as accidents, 
    NTILE(4) OVER (ORDER BY COUNT(*)) as risk_quartile 
FROM accidents 
GROUP BY district;
```

## Key SQL Features

| Feature | Usage |
|---------|-------|
| `NTILE(n)` | Divide districts into risk quartiles |
| `PERCENT_RANK()` | Risk percentile calculation |
| `ST_ClusterDBSCAN` | Spatial clustering of accident points |
| `ST_Buffer` | Create safety zones around hotspots |
| `ST_Contains` | Find accidents within areas |
| Window Functions | Running totals, ranking |

## Database Schema

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   districts     │     │   accidents     │     │  road_segments  │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ district_id(PK) │────<│ accident_id(PK) │     │ segment_id (PK) │
│ district_name   │     │ district_id(FK) │     │ road_name       │
│ region          │     │ location (geom) │     │ geom (LINESTR)  │
│ population      │     │ accident_date   │     │ speed_limit     │
│ boda_registered │     │ severity        │     └─────────────────┘
└─────────────────┘     │ fatalities      │
                        │ injuries        │
                        │ cause           │
                        └─────────────────┘
```

## Tech Stack

- **Database**: PostgreSQL 14+ with PostGIS
- **Key Feature**: NTILE() window function, spatial clustering
- **Extensions**: PostGIS

---

*Raw SQL Vault - Project #11*
