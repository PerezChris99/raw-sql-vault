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

## 🔌 Backend Integration

### Environment Variables
```bash
DB_HOST=localhost
DB_PORT=6432
DB_NAME=fishery_quota
DB_USER=app_service
DB_PASSWORD=your_secure_password
```

### Node.js Example
```javascript
const { createConnector } = require('../../_infrastructure/connectors/nodejs/pg-connector');
const db = createConnector('fishery_quota');

// Get quota usage with rolling window
const quotaStatus = await db.query(`
    SELECT fisher_id, catch_date, catch_weight,
           SUM(catch_weight) OVER (
               PARTITION BY fisher_id, species_id
               ORDER BY catch_date
               ROWS 30 PRECEDING
           ) as rolling_quota_used
    FROM catches c
    WHERE fisher_id = $1`,
    [fisherId]
);
```

### Python Example
```python
from _infrastructure.connectors.python.pg_connector import PostgresConnector
db = PostgresConnector.create('fishery_quota')

violations = db.query("SELECT * FROM vw_rolling_quota WHERE quota_exceeded = true")
```

### Security Setup
```sql
\i ../../_infrastructure/security/00_audit_infrastructure.sql
SELECT audit.enable_auditing('public', 'catches');
```

---

*Raw SQL Vault - Project #12*
