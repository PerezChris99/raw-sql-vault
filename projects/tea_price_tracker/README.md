# 🍵 Tea Farmer Price Tracker

> **Project #13** - Track tea prices and detect exploitation using percentile analysis

## Problem Statement

Tea farmers in Uganda face price exploitation:
- Middlemen offer below-market prices
- No visibility into fair price benchmarks
- Difficulty comparing prices across grades
- Seasonal price manipulation

## Solution

SQL-based price analysis using **PERCENTILE_CONT** to:
- Calculate median prices by tea grade
- Identify below-median price offers
- Track price trends over time
- Flag potential exploitation

## Sample Query (User Requirement)

```sql
SELECT 
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price) 
        OVER (PARTITION BY grade) as median_price 
FROM sales;
```

## Key SQL Features

| Feature | Usage |
|---------|-------|
| `PERCENTILE_CONT(0.5)` | Calculate median price |
| `PERCENTILE_CONT(0.25/0.75)` | Quartile analysis |
| `WITHIN GROUP (ORDER BY)` | Ordered-set aggregate |
| `PARTITION BY grade` | Per-grade statistics |
| `LAG()/LEAD()` | Price trend comparison |

## Database Schema

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   tea_grades    │     │    farmers      │     │     sales       │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ grade_id (PK)   │────<│ farmer_id (PK)  │────<│ sale_id (PK)    │
│ grade_name      │     │ farmer_name     │     │ farmer_id (FK)  │
│ description     │     │ district        │     │ grade_id (FK)   │
│ base_price      │     │ cooperative     │     │ buyer_id (FK)   │
└─────────────────┘     │ acreage         │     │ quantity_kg     │
                        └─────────────────┘     │ price_per_kg    │
                               │                │ sale_date       │
                        ┌─────────────────┐     └─────────────────┘
                        │     buyers      │
                        ├─────────────────┤
                        │ buyer_id (PK)   │
                        │ buyer_name      │
                        │ buyer_type      │
                        │ license_number  │
                        └─────────────────┘
```

## Tech Stack

- **Database**: PostgreSQL 14+
- **Key Feature**: PERCENTILE_CONT ordered-set aggregate
- **Runner**: PowerShell + psql

---

*Raw SQL Vault - Project #13*
