# 🐟 Fishery Quota Compliance Checker

> **Project #12** - Monitor overfishing violations using rolling window sums

## Problem Statement

Overfishing threatens Lake Victoria's ecosystem:
- Fishers exceed monthly catch quotas
- No real-time quota tracking
- Violations discovered too late
- Difficulty enforcing sustainable limits

## Solution

SQL-based quota monitoring using **rolling window sums** to:
- Track cumulative catches in real-time
- Alert when approaching quota limits
- Identify repeat violators
- Generate compliance reports

## Sample Query (User Requirement)

```sql
SELECT 
    fisher_id, 
    SUM(catch_weight) OVER (
        PARTITION BY month 
        ORDER BY date 
        ROWS 30 PRECEDING
    ) as quota_used 
FROM catches;
```

## Key SQL Features

| Feature | Usage |
|---------|-------|
| `SUM() OVER` | Rolling cumulative catch totals |
| `ROWS n PRECEDING` | 30-day rolling window |
| `PARTITION BY` | Per-fisher, per-month calculations |
| `LAG()` | Compare to previous catch records |
| `CASE` expressions | Quota violation flags |

## Database Schema

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   fish_species  │     │     fishers     │     │    catches      │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ species_id (PK) │     │ fisher_id (PK)  │────<│ catch_id (PK)   │
│ species_name    │>────│ license_number  │     │ fisher_id (FK)  │
│ quota_per_kg    │     │ boat_name       │     │ species_id (FK) │
│ min_size_cm     │     │ landing_site    │     │ catch_date      │
└─────────────────┘     │ license_expiry  │     │ catch_weight    │
                        └─────────────────┘     │ fish_count      │
                                                │ landing_site    │
                        ┌─────────────────┐     └─────────────────┘
                        │  monthly_quotas │
                        ├─────────────────┤
                        │ quota_id (PK)   │
                        │ species_id (FK) │
                        │ month           │
                        │ quota_kg        │
                        └─────────────────┘
```

## Tech Stack

- **Database**: PostgreSQL 14+
- **Key Feature**: Rolling window functions
- **Runner**: PowerShell + psql

---

*Raw SQL Vault - Project #12*
