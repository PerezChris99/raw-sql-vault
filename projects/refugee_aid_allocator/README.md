# 🏕️ Refugee Aid Allocator

> **Project #9** - Optimize aid distributions by need priority using RANK() window functions

## Problem Statement

Refugee camps receive limited resources that must be distributed fairly based on need. Manual allocation leads to:
- Inconsistent prioritization
- Delays in critical aid delivery
- Inequitable distribution across camps
- Difficulty tracking allocation history

## Solution

A SQL-based allocation system using **window functions** (RANK, DENSE_RANK, ROW_NUMBER) to:
- Score and prioritize refugees by need level
- Allocate resources fairly across camps
- Track distribution history and gaps
- Generate priority queues for field workers

## Sample Query (User Requirement)

```sql
SELECT 
    refugee_id, 
    RANK() OVER (ORDER BY need_score DESC) as priority 
FROM needs 
WHERE camp = 'Bidibidi';
```

## Key SQL Features

| Feature | Usage |
|---------|-------|
| `RANK()` | Priority ranking with gaps for ties |
| `DENSE_RANK()` | Priority ranking without gaps |
| `ROW_NUMBER()` | Unique sequential ordering |
| `NTILE(n)` | Divide into priority buckets |
| `PARTITION BY` | Rank within camps/categories |
| `SUM() OVER` | Running totals for allocation tracking |

## Database Schema

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│     camps       │     │    refugees     │     │  aid_categories │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ camp_id (PK)    │────<│ refugee_id (PK) │     │ category_id (PK)│
│ camp_name       │     │ camp_id (FK)    │     │ category_name   │
│ location        │     │ household_id    │     │ unit_of_measure │
│ capacity        │     │ name            │     │ priority_weight │
│ current_pop     │     │ age             │     └─────────────────┘
│ established     │     │ gender          │              │
└─────────────────┘     │ arrival_date    │              │
                        │ vulnerability   │              │
                        └─────────────────┘              │
                               │                         │
                               │                         │
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   households    │     │     needs       │     │   allocations   │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ household_id(PK)│────<│ need_id (PK)    │     │ allocation_id   │
│ head_refugee_id │     │ refugee_id (FK) │     │ need_id (FK)    │
│ size            │     │ category_id(FK) │>────│ quantity        │
│ special_needs   │     │ urgency_level   │     │ allocated_date  │
│ registration    │     │ need_score      │     │ distributed     │
└─────────────────┘     │ assessed_date   │     │ distribution_dt │
                        │ status          │     └─────────────────┘
                        └─────────────────┘
                               │
                        ┌─────────────────┐
                        │  aid_inventory  │
                        ├─────────────────┤
                        │ inventory_id    │
                        │ camp_id (FK)    │
                        │ category_id(FK) │
                        │ quantity_avail  │
                        │ last_restock    │
                        └─────────────────┘
```

## Need Score Calculation

```
Need Score = (Urgency × 0.35) + (Vulnerability × 0.25) + 
             (Household Size × 0.20) + (Days Waiting × 0.15) + 
             (Category Priority × 0.05)
```

### Urgency Levels
| Level | Score | Description |
|-------|-------|-------------|
| Critical | 100 | Life-threatening, immediate need |
| High | 75 | Severe hardship, urgent |
| Medium | 50 | Significant need |
| Low | 25 | Standard need |

### Vulnerability Factors
- Unaccompanied minors: +30
- Elderly (65+): +20
- Pregnant/nursing: +25
- Disabled: +25
- Single parent: +15
- Chronic illness: +20

## Project Structure

```
refugee_aid_allocator/
├── README.md
├── docs/
│   └── ARCHITECTURE.md
├── database/
│   ├── migrations/
│   │   ├── V001__initial_schema.sql
│   │   └── V002__views_and_indexes.sql
│   ├── seeds/
│   │   ├── 01_reference_data.sql
│   │   └── 02_sample_refugees.sql
│   └── functions/
│       ├── need_scoring.sql
│       └── allocation_engine.sql
├── scripts/
│   ├── reports/
│   │   ├── priority_queue.sql
│   │   ├── camp_summary.sql
│   │   └── allocation_gaps.sql
│   └── run_report.ps1
└── .env.example
```

## Tech Stack

- **Database**: PostgreSQL 14+ (also compatible with MySQL/SQL Server)
- **Key Extensions**: None required (pure SQL window functions)
- **Runner**: PowerShell + psql

## Quick Start

```powershell
# Setup database
.\scripts\run_report.ps1 setup

# Generate priority queue
.\scripts\run_report.ps1 priority

# View camp summary
.\scripts\run_report.ps1 camps

# Check allocation gaps
.\scripts\run_report.ps1 gaps
```

---

## 🔌 Backend Integration (Production)

This system is designed for **plug-and-play** integration with any backend framework.

### Environment Setup

```bash
# .env file
DB_HOST=localhost
DB_PORT=6432          # PgBouncer port (or 5432 direct)
DB_NAME=refugee_aid
DB_USER=app_service
DB_PASSWORD=your_secure_password
DB_SSL=true
DB_POOL_MAX=20
```

### Node.js Integration

```javascript
// Install: npm install pg
const { createConnector } = require('../../_infrastructure/connectors/nodejs/pg-connector');

const db = createConnector('refugee_aid');

// Get priority queue (parameterized - SQL injection safe)
async function getPriorityQueue(campId, limit = 50) {
    return await db.query(
        `SELECT r.refugee_id, r.name, n.need_score,
                RANK() OVER (ORDER BY n.need_score DESC) as priority
         FROM refugees r
         JOIN needs n ON r.refugee_id = n.refugee_id
         WHERE r.camp_id = $1 AND n.status = 'pending'
         ORDER BY priority
         LIMIT $2`,
        [campId, limit],
        { tenantId: 'org-123', userId: 'system' }  // For RLS
    );
}

// Allocate aid (transaction)
async function allocateAid(needId, quantity, userId) {
    return await db.transaction(async (client) => {
        // Check availability
        const need = await client.query(
            'SELECT * FROM needs WHERE need_id = $1 FOR UPDATE', [needId]
        );
        
        // Create allocation
        await client.query(
            `INSERT INTO allocations (need_id, quantity, allocated_by)
             VALUES ($1, $2, $3)`,
            [needId, quantity, userId]
        );
        
        // Update need status
        await client.query(
            'UPDATE needs SET status = $1 WHERE need_id = $2',
            ['allocated', needId]
        );
        
        return { success: true };
    }, { userId });
}
```

### Python Integration

```python
# Install: pip install psycopg2-binary
from _infrastructure.connectors.python.pg_connector import PostgresConnector

db = PostgresConnector.create('refugee_aid')

# Get priority queue
def get_priority_queue(camp_id: int, limit: int = 50):
    return db.query(
        """SELECT r.refugee_id, r.name, n.need_score,
                  RANK() OVER (ORDER BY n.need_score DESC) as priority
           FROM refugees r
           JOIN needs n ON r.refugee_id = n.refugee_id
           WHERE r.camp_id = %s AND n.status = 'pending'
           ORDER BY priority
           LIMIT %s""",
        [camp_id, limit],
        context={'tenant_id': 'org-123', 'user_id': 'system'}
    )

# Allocate aid (transaction)
def allocate_aid(need_id: int, quantity: int, user_id: str):
    with db.transaction(context={'user_id': user_id}) as cursor:
        cursor.execute('SELECT * FROM needs WHERE need_id = %s FOR UPDATE', [need_id])
        cursor.execute(
            'INSERT INTO allocations (need_id, quantity, allocated_by) VALUES (%s, %s, %s)',
            [need_id, quantity, user_id]
        )
        cursor.execute('UPDATE needs SET status = %s WHERE need_id = %s', ['allocated', need_id])
    return {'success': True}
```

### REST API Example (Express.js)

```javascript
const express = require('express');
const { createConnector } = require('../../_infrastructure/connectors/nodejs/pg-connector');

const app = express();
const db = createConnector('refugee_aid');

// GET /api/camps/:campId/priority-queue
app.get('/api/camps/:campId/priority-queue', async (req, res) => {
    try {
        const queue = await db.query(
            `SELECT r.refugee_id, r.name, n.need_score,
                    RANK() OVER (ORDER BY n.need_score DESC) as priority
             FROM refugees r
             JOIN needs n ON r.refugee_id = n.refugee_id
             WHERE r.camp_id = $1 AND n.status = 'pending'
             ORDER BY priority LIMIT 100`,
            [req.params.campId],
            { tenantId: req.headers['x-tenant-id'], userId: req.user?.id }
        );
        res.json(queue);
    } catch (error) {
        res.status(500).json({ error: 'Database error' });
    }
});

// Health check
app.get('/health', async (req, res) => {
    const health = await db.healthCheck();
    res.status(health.healthy ? 200 : 503).json(health);
});
```

### Security Features (Built-in)

| Feature | Description |
|---------|-------------|
| **SQL Injection Prevention** | All queries use parameterization (`$1, $2` or `%s`) |
| **Row-Level Security** | Set `tenantId`/`userId` context for automatic data isolation |
| **Rate Limiting** | 100 requests/minute per user (configurable) |
| **Connection Pooling** | Via PgBouncer (6432) or native pool |
| **Audit Logging** | All writes logged to `audit.activity_log` |
| **Retry Logic** | Automatic retry on transient failures |

### Applying Production Security

```sql
-- Run these once after schema creation
\i ../../_infrastructure/security/00_audit_infrastructure.sql
\i ../../_infrastructure/security/01_rbac_roles.sql
\i ../../_infrastructure/security/02_row_level_security.sql
\i ../../_infrastructure/security/03_input_sanitization.sql
\i ../../_infrastructure/security/04_rate_limiting.sql

-- Enable auditing on tables
SELECT audit.enable_auditing('public', 'refugees');
SELECT audit.enable_auditing('public', 'needs');
SELECT audit.enable_auditing('public', 'allocations');

-- Grant permissions to application role
SELECT security.grant_standard_permissions('public');
```

---

## Reports

1. **Priority Queue** - Ranked list of refugees awaiting aid
2. **Camp Summary** - Resource status by camp
3. **Allocation Gaps** - Unfulfilled needs analysis
4. **Distribution History** - Tracking deliveries

---

*Raw SQL Vault - Project #9*
