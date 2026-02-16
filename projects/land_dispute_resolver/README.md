# 🏞️ Land Dispute Resolver Query

> **Project #14** - Detect overlapping land claims using PostGIS spatial intersections

## Problem Statement

Land disputes are common in Uganda due to:
- Multiple claims on the same parcels
- Inaccurate boundary surveys
- Unclear historical ownership
- No systematic overlap detection

## Solution

SQL-based land claim verification using **PostGIS ST_Intersects** to:
- Detect overlapping parcel boundaries
- Calculate overlap areas
- Identify potentially conflicting owners
- Generate dispute resolution reports

## Sample Query (User Requirement)

```sql
SELECT p1.owner, p2.owner 
FROM parcels p1, parcels p2 
WHERE ST_Intersects(p1.geom, p2.geom) 
  AND p1.id != p2.id;
```

## Key SQL Features

| Feature | Usage |
|---------|-------|
| `ST_Intersects` | Detect overlapping polygons |
| `ST_Intersection` | Get overlap geometry |
| `ST_Area` | Calculate overlap area |
| `ST_Within` | Check containment |
| `ST_Buffer` | Create boundary tolerance zones |
| Self-join | Compare parcels against each other |

## Database Schema

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   districts     │     │    parcels      │     │    disputes     │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ district_id(PK) │────<│ parcel_id (PK)  │────<│ dispute_id (PK) │
│ district_name   │     │ district_id(FK) │     │ parcel1_id (FK) │
│ boundary (geom) │     │ plot_number     │     │ parcel2_id (FK) │
└─────────────────┘     │ owner_name      │     │ overlap_area    │
                        │ boundary (geom) │     │ status          │
                        │ area_sqm        │     │ filed_date      │
                        │ title_number    │     └─────────────────┘
                        │ registered_date │
                        └─────────────────┘
```

## Tech Stack

- **Database**: PostgreSQL 14+ with PostGIS
- **Key Feature**: Spatial intersection queries
- **Extensions**: PostGIS

---

*Raw SQL Vault - Project #14*
