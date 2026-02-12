# Education Dropout Forecaster

> **Project 4** | Raw SQL Vault  
> Predict and analyze student dropout patterns using PostgreSQL window functions

## Problem Statement

Educational institutions struggle to identify at-risk students before they drop out. This system analyzes dropout patterns by school, district, and demographic factors using advanced window functions to rank schools and calculate rolling dropout rates.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     EDUCATION DROPOUT FORECASTER                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────────┐   │
│  │   Django     │     │  PostgreSQL  │     │   Window Functions   │   │
│  │   raw()      │────▶│   Database   │◀────│   & Analytics        │   │
│  │   Queries    │     │              │     │                      │   │
│  └──────────────┘     └──────────────┘     └──────────────────────┘   │
│         │                    │                       │                 │
│         ▼                    ▼                       ▼                 │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────────────┐   │
│  │  Services    │     │   Students   │     │  ROW_NUMBER()        │   │
│  │  Layer       │     │   Schools    │     │  RANK() / DENSE_RANK │   │
│  │              │     │   Districts  │     │  LAG() / LEAD()      │   │
│  └──────────────┘     │   Events     │     │  SUM() OVER()        │   │
│                       └──────────────┘     │  AVG() OVER()        │   │
│                                            │  NTILE()             │   │
│                                            └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Core Query (Per Specification)

```sql
SELECT 
    school,
    COUNT(*) AS dropouts,
    ROW_NUMBER() OVER (
        PARTITION BY district 
        ORDER BY COUNT(*) DESC
    ) AS rank
FROM students
WHERE status = 'dropped'
GROUP BY school, district;
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Database | PostgreSQL 14+ |
| Backend | Django 4.x with raw() |
| Analytics | Window Functions |
| Migrations | Django migrations + raw SQL |

## Folder Structure

```
education_dropout_forecaster/
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
│       ├── analytics/
│       │   └── dropout_analytics.sql
│       └── forecasting/
│           └── risk_scoring.sql
├── dropout_forecaster/          # Django project
│   ├── manage.py
│   ├── config/
│   │   ├── settings.py
│   │   └── urls.py
│   ├── analytics/               # Django app
│   │   ├── models.py
│   │   ├── services.py
│   │   ├── views.py
│   │   └── urls.py
│   └── requirements.txt
├── scripts/
│   └── deploy.ps1
└── tests/
    └── test_analytics.sql
```

## Key Features

### 1. Window Functions for Ranking
```sql
-- Rank schools by dropout count within each district
ROW_NUMBER() OVER (PARTITION BY district_id ORDER BY dropout_count DESC)
RANK() OVER (PARTITION BY district_id ORDER BY dropout_rate DESC)
DENSE_RANK() OVER (ORDER BY total_dropouts DESC)
```

### 2. Rolling Rates with LAG/LEAD
```sql
-- Compare to previous period
LAG(dropout_count, 1) OVER (ORDER BY academic_year)
LEAD(dropout_count, 1) OVER (ORDER BY academic_year)
```

### 3. Running Totals
```sql
-- Cumulative dropouts over time
SUM(dropout_count) OVER (ORDER BY event_date ROWS UNBOUNDED PRECEDING)
```

### 4. Percentile Analysis
```sql
-- Quartile distribution of schools
NTILE(4) OVER (ORDER BY dropout_rate) AS quartile
```

## Quick Start

### 1. Database Setup
```powershell
.\scripts\deploy.ps1 -action deploy
```

### 2. Django Setup
```bash
cd dropout_forecaster
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

### 3. Run Analytics
```python
from analytics.services import DropoutAnalytics

# Get schools ranked by dropout rate
analytics = DropoutAnalytics()
ranked_schools = analytics.get_school_rankings(district_id=1)

# Get at-risk students
at_risk = analytics.get_at_risk_students(school_id=5)
```

## Sample Queries

### Schools Ranked by Dropouts (Core Query)
```sql
SELECT 
    s.school_name,
    d.district_name,
    COUNT(*) AS total_dropouts,
    ROUND(COUNT(*) * 100.0 / school_enrollment, 2) AS dropout_rate,
    ROW_NUMBER() OVER (
        PARTITION BY d.district_id 
        ORDER BY COUNT(*) DESC
    ) AS district_rank,
    RANK() OVER (ORDER BY COUNT(*) DESC) AS overall_rank
FROM students st
JOIN schools s ON st.school_id = s.school_id
JOIN districts d ON s.district_id = d.district_id
WHERE st.status = 'dropped'
GROUP BY s.school_id, s.school_name, d.district_id, d.district_name, school_enrollment
ORDER BY d.district_name, district_rank;
```

### Year-over-Year Comparison
```sql
SELECT 
    academic_year,
    school_id,
    dropout_count,
    LAG(dropout_count) OVER (
        PARTITION BY school_id ORDER BY academic_year
    ) AS prev_year_dropouts,
    dropout_count - LAG(dropout_count) OVER (
        PARTITION BY school_id ORDER BY academic_year
    ) AS change_from_prev_year
FROM annual_dropout_stats;
```

### Risk Scoring with Percentiles
```sql
SELECT 
    student_id,
    school_id,
    risk_score,
    NTILE(10) OVER (ORDER BY risk_score DESC) AS risk_decile,
    PERCENT_RANK() OVER (ORDER BY risk_score) AS percentile
FROM student_risk_scores
WHERE risk_score > 0;
```

## Dropout Reasons Tracked

| Code | Reason | Risk Weight |
|------|--------|-------------|
| ACD | Academic Failure | 0.8 |
| FIN | Financial Issues | 0.7 |
| FAM | Family Circumstances | 0.6 |
| HLT | Health Problems | 0.5 |
| REL | Relocation | 0.3 |
| BHV | Behavioral Issues | 0.7 |
| ATT | Attendance Problems | 0.9 |
| SOC | Social Issues | 0.5 |

## Risk Factors Analyzed

- Attendance rate < 80%
- GPA below 2.0
- Multiple disciplinary incidents
- Free/reduced lunch eligibility
- Previous grade retention
- English language learner status
- Special education needs
- Single-parent household

## Window Functions Reference

| Function | Use Case |
|----------|----------|
| `ROW_NUMBER()` | Unique ranking within partition |
| `RANK()` | Ranking with gaps for ties |
| `DENSE_RANK()` | Ranking without gaps |
| `NTILE(n)` | Divide into n equal groups |
| `LAG(col, n)` | Value from n rows before |
| `LEAD(col, n)` | Value from n rows after |
| `FIRST_VALUE()` | First value in window |
| `LAST_VALUE()` | Last value in window |
| `SUM() OVER()` | Running/cumulative sum |
| `AVG() OVER()` | Running/moving average |
| `PERCENT_RANK()` | Relative rank as percentage |

## License

MIT License - Part of Raw SQL Vault educational project
