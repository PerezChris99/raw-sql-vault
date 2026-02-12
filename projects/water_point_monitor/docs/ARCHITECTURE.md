# Water Point Usage Monitor - Architecture

## System Overview

This document details the technical architecture for predicting borehole breakdowns using TimescaleDB time-series analysis.

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ENTITY RELATIONSHIPS                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────┐         ┌─────────────────────┐                      │
│  │    regions       │         │   borehole_types    │                      │
│  ├──────────────────┤         ├─────────────────────┤                      │
│  │ PK region_id     │         │ PK type_id          │                      │
│  │    name          │         │    name             │                      │
│  │    country       │         │    depth_range      │                      │
│  │    climate_zone  │         │    typical_yield    │                      │
│  └────────┬─────────┘         └──────────┬──────────┘                      │
│           │                              │                                  │
│           │ 1:N                          │ 1:N                              │
│           ▼                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │                         boreholes                                │       │
│  ├─────────────────────────────────────────────────────────────────┤       │
│  │ PK borehole_id UUID                                             │       │
│  │ FK region_id, type_id                                           │       │
│  │    name, code, location (lat/long)                              │       │
│  │    depth_m, yield_lpm, static_water_level_m                     │       │
│  │    installation_date, last_maintenance, status                  │       │
│  │    population_served, pump_type, power_source                   │       │
│  └──────────────────────────────┬──────────────────────────────────┘       │
│                                 │                                           │
│                                 │ 1:N (millions of rows)                    │
│                                 ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │                    usage_logs (HYPERTABLE)                       │       │
│  ├─────────────────────────────────────────────────────────────────┤       │
│  │    logged_at TIMESTAMPTZ (time column)                          │       │
│  │ FK borehole_id                                                  │       │
│  │    usage_liters, flow_rate_lpm                                  │       │
│  │    pump_runtime_sec, pump_cycles                                │       │
│  │    pressure_bar, voltage, temperature_c                         │       │
│  │    source (sensor/manual)                                       │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                 │                                           │
│                                 ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────┐       │
│  │                CONTINUOUS AGGREGATES                             │       │
│  ├─────────────────────────────────────────────────────────────────┤       │
│  │  • usage_hourly_agg - Hourly summaries per borehole            │       │
│  │  • usage_daily_agg - Daily summaries per borehole              │       │
│  │  • usage_weekly_agg - Weekly summaries per borehole            │       │
│  └─────────────────────────────────────────────────────────────────┘       │
│                                                                             │
│  ┌──────────────────┐         ┌─────────────────────┐                      │
│  │ maintenance_logs │         │  breakdown_alerts   │                      │
│  ├──────────────────┤         ├─────────────────────┤                      │
│  │ FK borehole_id   │         │ FK borehole_id      │                      │
│  │    scheduled_date│         │    detected_at      │                      │
│  │    completed_date│         │    alert_type       │                      │
│  │    work_type     │         │    risk_score       │                      │
│  │    findings      │         │    indicators       │                      │
│  │    parts_replaced│         │    acknowledged     │                      │
│  └──────────────────┘         └─────────────────────┘                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## TimescaleDB Configuration

### Hypertable Setup

```sql
-- Convert usage_logs to hypertable
SELECT create_hypertable(
    'usage_logs',
    'logged_at',
    chunk_time_interval => INTERVAL '1 day',  -- Daily chunks
    if_not_exists => TRUE
);
```

### Chunk Parameters

| Setting | Value | Rationale |
|---------|-------|-----------|
| `chunk_time_interval` | 1 day | Balances query performance and compression |
| Compression | After 7 days | Keep recent data uncompressed |
| Retention | 365 days | 1 year of raw data |

### Compression Policy

```sql
-- Enable compression after 7 days
ALTER TABLE usage_logs SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'borehole_id'
);

SELECT add_compression_policy('usage_logs', INTERVAL '7 days');
```

### Retention Policy

```sql
-- Remove raw data older than 1 year
SELECT add_retention_policy('usage_logs', INTERVAL '365 days');
```

## Time-Series Analysis Strategy

### User Sample Query Pattern

```sql
SELECT 
    borehole_id, 
    date,
    AVG(usage) as avg_daily, 
    LAG(AVG(usage)) OVER (
        PARTITION BY borehole_id 
        ORDER BY date
    ) as prev_day_avg
FROM logs 
GROUP BY borehole_id, date;
```

### Extended Analysis

```sql
-- Usage trend with moving average and standard deviation
SELECT 
    borehole_id,
    time_bucket('1 day', logged_at) as date,
    AVG(usage_liters) as avg_daily,
    LAG(AVG(usage_liters)) OVER w as prev_day,
    AVG(AVG(usage_liters)) OVER (
        PARTITION BY borehole_id 
        ORDER BY time_bucket('1 day', logged_at)
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as rolling_7day_avg,
    STDDEV(AVG(usage_liters)) OVER (
        PARTITION BY borehole_id 
        ORDER BY time_bucket('1 day', logged_at)
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) as rolling_30day_stddev
FROM usage_logs
GROUP BY borehole_id, time_bucket('1 day', logged_at)
WINDOW w AS (PARTITION BY borehole_id ORDER BY time_bucket('1 day', logged_at));
```

## Anomaly Detection Algorithm

### Detection Indicators

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    BREAKDOWN INDICATOR WEIGHTS                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Usage Drop                ████████████████████░░░░░░░░░░░░  40%       │
│  (>30% below 7-day avg)                                                │
│                                                                         │
│  Flow Degradation          ████████████████░░░░░░░░░░░░░░░░  30%       │
│  (declining L/min trend)                                               │
│                                                                         │
│  Pump Cycling              ██████████░░░░░░░░░░░░░░░░░░░░░░  15%       │
│  (>10 cycles/hour)                                                     │
│                                                                         │
│  Pressure Anomaly          ██████░░░░░░░░░░░░░░░░░░░░░░░░░░  10%       │
│  (outside normal range)                                                │
│                                                                         │
│  Runtime Increase          ████░░░░░░░░░░░░░░░░░░░░░░░░░░░░   5%       │
│  (>20% more pump time)                                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Risk Score Calculation

```sql
-- Breakdown Risk Score (0-100)
risk_score = 
    (usage_drop_indicator   * 40) +  -- Binary 0/1
    (flow_degradation       * 30) +  -- 0 to 1 scale
    (cycling_anomaly        * 15) +  -- Binary 0/1
    (pressure_anomaly       * 10) +  -- Binary 0/1
    (runtime_increase       * 5);    -- 0 to 1 scale
```

### Threshold Configuration

| Indicator | Normal | Warning | Critical |
|-----------|--------|---------|----------|
| Daily Usage | Within 2σ | 2-3σ below | >3σ below |
| Flow Rate | >80% of rated | 60-80% | <60% |
| Pump Cycles/hr | <5 | 5-10 | >10 |
| Pressure | 2-4 bar | 1.5-2 or 4-5 | <1.5 or >5 |
| Runtime % | <90% | 90-95% | >95% |

## Continuous Aggregates

### Hourly Aggregate

```sql
CREATE MATERIALIZED VIEW usage_hourly_agg
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', logged_at) AS bucket,
    borehole_id,
    AVG(usage_liters) as avg_usage,
    SUM(usage_liters) as total_usage,
    AVG(flow_rate_lpm) as avg_flow_rate,
    SUM(pump_runtime_sec) as total_runtime,
    SUM(pump_cycles) as total_cycles,
    AVG(pressure_bar) as avg_pressure,
    COUNT(*) as reading_count
FROM usage_logs
GROUP BY bucket, borehole_id
WITH NO DATA;
```

### Daily Aggregate

```sql
CREATE MATERIALIZED VIEW usage_daily_agg
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', logged_at) AS bucket,
    borehole_id,
    AVG(usage_liters) as avg_usage,
    SUM(usage_liters) as total_usage,
    MIN(flow_rate_lpm) as min_flow_rate,
    AVG(flow_rate_lpm) as avg_flow_rate,
    MAX(flow_rate_lpm) as max_flow_rate,
    SUM(pump_runtime_sec) / 3600.0 as runtime_hours,
    SUM(pump_cycles) as total_cycles,
    AVG(pressure_bar) as avg_pressure,
    MIN(pressure_bar) as min_pressure,
    MAX(pressure_bar) as max_pressure
FROM usage_logs
GROUP BY bucket, borehole_id
WITH NO DATA;
```

## Query Optimization

### Index Strategy

1. **Time-based queries**: Automatic chunk exclusion by TimescaleDB
2. **Borehole lookups**: B-tree index on borehole_id
3. **Combined queries**: Composite index (borehole_id, logged_at DESC)

### Performance Considerations

- Use `time_bucket()` instead of `date_trunc()` for TimescaleDB optimization
- Query continuous aggregates for historical analysis
- Use raw hypertable only for recent data (<7 days)
- Leverage chunk exclusion with time range predicates

## Alert System

### Alert Levels

| Level | Risk Score | Action |
|-------|------------|--------|
| Info | 20-39 | Monitor, no action |
| Warning | 40-59 | Schedule inspection |
| Critical | 60-79 | Priority maintenance |
| Emergency | 80-100 | Immediate dispatch |

### Alert Flow

```
Raw Data → Continuous Agg → Anomaly Detection → Risk Score → Alert Generation
                                                      │
                                                      ▼
                                        ┌─────────────────────────┐
                                        │   breakdown_alerts      │
                                        │   - detected_at         │
                                        │   - risk_score          │
                                        │   - indicators (JSONB)  │
                                        └─────────────────────────┘
```

## Data Volume Estimates

| Scenario | Boreholes | Readings/Day | Daily Rows | Annual Storage |
|----------|-----------|--------------|------------|----------------|
| Small | 50 | 288 (5min) | 14,400 | ~50 MB |
| Medium | 500 | 288 | 144,000 | ~500 MB |
| Large | 5,000 | 288 | 1,440,000 | ~5 GB |

With compression (10:1 ratio), storage needs reduce by 90% after 7 days.
