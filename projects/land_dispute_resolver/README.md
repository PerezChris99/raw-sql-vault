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

## 🔌 Backend Integration

### Environment Variables
```bash
DB_HOST=localhost
DB_PORT=6432
DB_NAME=land_disputes
DB_USER=app_service
DB_PASSWORD=your_secure_password
```

### Node.js Example
```javascript
const { createConnector } = require('../../_infrastructure/connectors/nodejs/pg-connector');
const db = createConnector('land_disputes');

// Find overlapping parcels
const overlaps = await db.query(`
    SELECT p1.owner_name as owner_1, p2.owner_name as owner_2,
           p1.plot_number, p2.plot_number,
           ST_Area(ST_Intersection(p1.boundary, p2.boundary)) as overlap_area
    FROM parcels p1, parcels p2
    WHERE ST_Intersects(p1.boundary, p2.boundary)
      AND p1.parcel_id < p2.parcel_id`,
    []
);
```

### Python Example
```python
from _infrastructure.connectors.python.pg_connector import PostgresConnector
db = PostgresConnector.create('land_disputes')

overlaps = db.query("SELECT * FROM vw_overlapping_parcels WHERE overlap_percentage > 5")
```

### Security Setup
```sql
\i ../../_infrastructure/security/00_audit_infrastructure.sql
SELECT audit.enable_auditing('public', 'parcels');
SELECT audit.enable_auditing('public', 'disputes');
```

---

*Raw SQL Vault - Project #14*
