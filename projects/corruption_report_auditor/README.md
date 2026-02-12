# Corruption Report Auditor

**Project #5** in the Raw SQL Vault - PostgreSQL temporal analytics for tracking and analyzing corruption complaints.

## Problem Statement

Government agencies and oversight bodies need to verify unresolved complaints trends, identify patterns in corruption reports, and ensure timely resolution of cases. Manual tracking fails to catch systemic issues or aging complaints that require escalation.

## Solution

A Reports Database with comprehensive temporal analytics using PostgreSQL's powerful date/time functions, FILTER clause for conditional aggregation, and automated psql scripts for scheduled reporting.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      CORRUPTION REPORT AUDITOR                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   Reports   │───▶│   Cases     │───▶│ Resolutions │───▶│   Audits    │  │
│  │   Intake    │    │  Tracking   │    │  Workflow   │    │   & Logs    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│         │                 │                   │                  │          │
│         ▼                 ▼                   ▼                  ▼          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    TEMPORAL ANALYTICS ENGINE                        │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │   │
│  │  │  FILTER  │ │ INTERVAL │ │DATE_TRUNC│ │  AGE()   │ │ EXTRACT  │  │   │
│  │  │  Clause  │ │ Ranges   │ │ Bucketing│ │ Duration │ │  Parts   │  │   │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                       PSQL REPORT SCRIPTS                           │   │
│  │  • Daily Aging Report    • Monthly Trends    • Quarterly Audits    │   │
│  │  • Weekly Resolution     • Category Analysis • Annual Statistics   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Key SQL Features Demonstrated

### Temporal Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `FILTER` | Conditional aggregation | `COUNT(*) FILTER (WHERE status='unresolved')` |
| `INTERVAL` | Date arithmetic | `CURRENT_DATE - INTERVAL '1 year'` |
| `DATE_TRUNC` | Period bucketing | `DATE_TRUNC('month', reported_date)` |
| `AGE()` | Duration calculation | `AGE(CURRENT_DATE, reported_date)` |
| `EXTRACT` | Date part extraction | `EXTRACT(YEAR FROM reported_date)` |
| `generate_series` | Date range generation | Time series with gaps filled |
| `OVERLAPS` | Period intersection | Concurrent case detection |

### Sample Queries

**Core Query - Unresolved by Category:**
```sql
SELECT 
    category,
    COUNT(*) FILTER (WHERE status = 'unresolved') as open_cases,
    COUNT(*) FILTER (WHERE status = 'resolved') as closed_cases,
    COUNT(*) FILTER (WHERE status = 'escalated') as escalated_cases
FROM reports 
WHERE reported_date > CURRENT_DATE - INTERVAL '1 year'
GROUP BY category;
```

**Aging Analysis:**
```sql
SELECT 
    CASE 
        WHEN AGE(CURRENT_DATE, reported_date) < INTERVAL '30 days' THEN '0-30 days'
        WHEN AGE(CURRENT_DATE, reported_date) < INTERVAL '90 days' THEN '31-90 days'
        WHEN AGE(CURRENT_DATE, reported_date) < INTERVAL '180 days' THEN '91-180 days'
        ELSE 'Over 180 days'
    END as age_bucket,
    COUNT(*) as case_count
FROM reports
WHERE status = 'unresolved'
GROUP BY 1
ORDER BY MIN(AGE(CURRENT_DATE, reported_date));
```

**Monthly Trends with Gap Filling:**
```sql
SELECT 
    gs.month,
    COALESCE(r.new_reports, 0) as new_reports,
    COALESCE(r.resolved, 0) as resolved
FROM generate_series(
    DATE_TRUNC('month', CURRENT_DATE - INTERVAL '12 months'),
    DATE_TRUNC('month', CURRENT_DATE),
    INTERVAL '1 month'
) as gs(month)
LEFT JOIN (
    SELECT 
        DATE_TRUNC('month', reported_date) as month,
        COUNT(*) as new_reports,
        COUNT(*) FILTER (WHERE status = 'resolved') as resolved
    FROM reports
    GROUP BY 1
) r ON gs.month = r.month
ORDER BY gs.month;
```

## Tech Stack

- **Database**: PostgreSQL 14+ (temporal functions, FILTER clause)
- **Scripting**: psql with variables and formatting
- **Scheduling**: cron/Task Scheduler compatible scripts
- **Output**: CSV, HTML, formatted console reports

## Project Structure

```
corruption_report_auditor/
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
│       └── analytics/
│           ├── temporal_analytics.sql
│           └── trend_analysis.sql
├── scripts/
│   ├── reports/
│   │   ├── daily_aging_report.sql
│   │   ├── weekly_resolution_summary.sql
│   │   ├── monthly_category_trends.sql
│   │   └── quarterly_audit_report.sql
│   ├── run_report.ps1
│   └── schedule_reports.ps1
├── tests/
│   └── test_temporal_analytics.sql
└── .env.example
```

## Quick Start

1. **Create Database**:
```bash
createdb corruption_auditor
```

2. **Run Migrations**:
```bash
psql -d corruption_auditor -f database/migrations/V001__schema_setup.sql
psql -d corruption_auditor -f database/migrations/V002__indexes.sql
psql -d corruption_auditor -f database/migrations/V003__triggers.sql
psql -d corruption_auditor -f database/migrations/V004__views.sql
```

3. **Load Seed Data**:
```bash
psql -d corruption_auditor -f database/seeds/01_reference_data.sql
psql -d corruption_auditor -f database/seeds/02_sample_data.sql
```

4. **Install Functions**:
```bash
psql -d corruption_auditor -f database/functions/analytics/temporal_analytics.sql
psql -d corruption_auditor -f database/functions/analytics/trend_analysis.sql
```

5. **Run Reports**:
```powershell
.\scripts\run_report.ps1 -Report daily_aging
.\scripts\run_report.ps1 -Report monthly_trends -Format csv
```

## Report Types

| Report | Frequency | Description |
|--------|-----------|-------------|
| Aging Report | Daily | Cases grouped by age buckets |
| Resolution Summary | Weekly | Resolution rates by department |
| Category Trends | Monthly | New vs resolved by category |
| Quarterly Audit | Quarterly | Comprehensive compliance review |
| Annual Statistics | Yearly | Year-over-year comparisons |

## License

MIT License - Part of the Raw SQL Vault learning project.
