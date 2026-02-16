# 🗑️ Waste Collection Optimizer

> **Project #10** - Optimize waste collection routes using CTEs and aggregations

## Problem Statement

Kampala's waste collection is inefficient due to:
- No real-time visibility into bin fill levels
- Fixed routes ignoring actual needs
- Wasted fuel on empty bins
- Overflow in high-traffic areas

## Solution

SQL-based route optimization using **Common Table Expressions (CTEs)** to:
- Identify full bins requiring urgent collection
- Prioritize routes by bin urgency
- Calculate optimal collection sequences
- Track collection efficiency metrics

## Sample Query (User Requirement)

```sql
WITH full_bins AS (
    SELECT * FROM bins WHERE level > 80
)
SELECT route_id, COUNT(*) as urgent 
FROM full_bins 
GROUP BY route_id 
ORDER BY COUNT(*) DESC;
```

## Key SQL Features

| Feature | Usage |
|---------|-------|
| `WITH ... AS` | Define reusable CTEs |
| `WITH RECURSIVE` | Calculate route sequences |
| Multiple CTEs | Chain data transformations |
| Aggregation | Route-level statistics |
| Window Functions | Running totals for capacity |

## Database Schema

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     zones       │     │     routes      │     │      bins       │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ zone_id (PK)    │────<│ route_id (PK)   │────<│ bin_id (PK)     │
│ zone_name       │     │ zone_id (FK)    │     │ route_id (FK)   │
│ area_sqkm       │     │ route_name      │     │ location        │
│ population      │     │ distance_km     │     │ capacity_liters │
└─────────────────┘     │ truck_id (FK)   │     │ current_level   │
                        │ schedule_days   │     │ last_emptied    │
                        └─────────────────┘     │ latitude        │
                               │                │ longitude       │
                               │                └─────────────────┘
                        ┌─────────────────┐            │
                        │    trucks       │     ┌─────────────────┐
                        ├─────────────────┤     │  collections    │
                        │ truck_id (PK)   │     ├─────────────────┤
                        │ plate_number    │     │ collection_id   │
                        │ capacity_kg     │     │ bin_id (FK)     │
                        │ status          │     │ collected_at    │
                        └─────────────────┘     │ level_before    │
                                                │ weight_kg       │
                                                └─────────────────┘
```

## Tech Stack

- **Database**: PostgreSQL 14+
- **Key Feature**: CTEs (WITH clause)
- **Runner**: PowerShell + psql

---

*Raw SQL Vault - Project #10*
