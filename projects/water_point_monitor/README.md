# Water Point Usage Monitor

**Project #8** - Predict borehole breakdowns using time-series analysis.

## Problem Statement

Rural water points (boreholes) often fail without warning, leaving communities without water access for days or weeks. By analyzing usage patterns over time, we can detect anomalies that predict impending failures.

## Solution

Time-series database with usage logs tracking pump activity, flow rates, and operational metrics. PostgreSQL with TimescaleDB extension enables efficient time-series queries with window functions for trend analysis.

## Technology Stack

- **PostgreSQL 14+** - Core database
- **TimescaleDB 2.x** - Time-series extension with hypertables
- **Window Functions** - LAG, LEAD, AVG OVER for trend analysis
- **Continuous Aggregates** - Pre-computed hourly/daily summaries

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     WATER POINT USAGE MONITOR                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────────────┐   │
│  │   Sensors   │───▶│  Usage Logs  │───▶│  TimescaleDB Hypertable │   │
│  │  (IoT/Manual)│    │  (Raw Data)  │    │  (Partitioned by Time)  │   │
│  └─────────────┘    └──────────────┘    └─────────────────────────┘   │
│                                                    │                    │
│                                                    ▼                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │              CONTINUOUS AGGREGATES                               │   │
│  │  ┌─────────────┐  ┌──────────────┐  ┌──────────────────┐       │   │
│  │  │   Hourly    │  │    Daily     │  │     Weekly       │       │   │
│  │  │  Summaries  │  │   Summaries  │  │    Summaries     │       │   │
│  │  └─────────────┘  └──────────────┘  └──────────────────┘       │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                    │                    │
│                                                    ▼                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                  ANOMALY DETECTION                               │   │
│  │  • Usage Drop Detection (LAG comparison)                        │   │
│  │  • Flow Rate Degradation                                        │   │
│  │  • Pressure Anomalies                                           │   │
│  │  • Pump Cycle Analysis                                          │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                    │                    │
│                                                    ▼                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                  PREDICTION & ALERTS                             │   │
│  │  • Breakdown Risk Score                                         │   │
│  │  • Maintenance Scheduling                                       │   │
│  │  • Community Notifications                                      │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Sample Query (User's Pattern)

```sql
-- Daily usage comparison with previous day
SELECT 
    borehole_id, 
    date,
    AVG(usage) as avg_daily, 
    LAG(AVG(usage)) OVER (
        PARTITION BY borehole_id 
        ORDER BY date
    ) as prev_day_avg
FROM usage_logs 
GROUP BY borehole_id, date;
```

## TimescaleDB Features Used

| Feature | Purpose |
|---------|---------|
| `create_hypertable()` | Convert usage_logs to time-partitioned table |
| `time_bucket()` | Aggregate data into time intervals |
| `continuous_aggregate` | Pre-compute hourly/daily summaries |
| `add_retention_policy()` | Auto-delete old raw data |
| `add_compression_policy()` | Compress historical data |
| Window Functions | `LAG()`, `LEAD()`, rolling averages |

## Breakdown Indicators

| Indicator | Detection Method | Risk Weight |
|-----------|-----------------|-------------|
| **Usage Drop** | >30% decrease vs 7-day average | High (40%) |
| **Flow Degradation** | Declining L/min over 3+ days | High (30%) |
| **Pump Cycling** | Frequent on/off within hour | Medium (15%) |
| **Pressure Anomaly** | Outside normal range | Medium (10%) |
| **Runtime Increase** | Pump running longer for same output | Low (5%) |

## Quick Start

```powershell
# 1. Install TimescaleDB extension
# (Download from timescale.com or use Docker)

# 2. Create database and enable extension
psql -c "CREATE DATABASE water_monitor_db;"
psql -d water_monitor_db -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"

# 3. Run migrations
psql -d water_monitor_db -f database/migrations/V001__initial_schema.sql
psql -d water_monitor_db -f database/migrations/V002__hypertables.sql
psql -d water_monitor_db -f database/migrations/V003__continuous_aggs.sql
psql -d water_monitor_db -f database/migrations/V004__views.sql

# 4. Load sample data
psql -d water_monitor_db -f database/seeds/01_reference_data.sql
psql -d water_monitor_db -f database/seeds/02_sample_logs.sql

# 5. Run prediction report
.\scripts\run_report.ps1 -Report breakdown
```

## Project Structure

```
water_point_monitor/
├── README.md
├── .env.example
├── docs/
│   └── ARCHITECTURE.md
├── database/
│   ├── migrations/
│   │   ├── V001__initial_schema.sql
│   │   ├── V002__hypertables.sql
│   │   ├── V003__continuous_aggs.sql
│   │   └── V004__views.sql
│   ├── seeds/
│   │   ├── 01_reference_data.sql
│   │   └── 02_sample_logs.sql
│   └── functions/
│       ├── anomaly_detection.sql
│       └── breakdown_prediction.sql
├── scripts/
│   ├── run_report.ps1
│   └── reports/
│       ├── breakdown_risk.sql
│       ├── usage_trends.sql
│       └── maintenance_schedule.sql
└── tests/
    └── test_timeseries.sql
```

## Key Reports

1. **Breakdown Risk** - Boreholes ranked by failure probability
2. **Usage Trends** - Daily/weekly patterns with anomaly flags
3. **Maintenance Schedule** - Proactive maintenance recommendations

## Learning Objectives

- TimescaleDB hypertables and time partitioning
- Continuous aggregates for efficient queries
- Window functions (LAG, LEAD) for time comparison
- Rolling averages and moving calculations
- Anomaly detection with standard deviation
- Retention and compression policies
