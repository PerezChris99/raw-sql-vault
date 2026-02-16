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

## Reports

1. **Priority Queue** - Ranked list of refugees awaiting aid
2. **Camp Summary** - Resource status by camp
3. **Allocation Gaps** - Unfulfilled needs analysis
4. **Distribution History** - Tracking deliveries

---

*Raw SQL Vault - Project #9*
