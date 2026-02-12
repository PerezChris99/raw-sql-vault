# Corruption Report Auditor - Architecture

## System Design

### Entity Relationship Diagram

```
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│   departments   │       │   categories    │       │    statuses     │
├─────────────────┤       ├─────────────────┤       ├─────────────────┤
│ PK department_id│       │ PK category_id  │       │ PK status_id    │
│    name         │       │    name         │       │    name         │
│    code         │       │    description  │       │    is_terminal  │
│    parent_id FK │       │    severity_lvl │       │    sla_days     │
└────────┬────────┘       └────────┬────────┘       └────────┬────────┘
         │                         │                         │
         │    ┌────────────────────┼─────────────────────────┘
         │    │                    │
         ▼    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                              reports                                 │
├─────────────────────────────────────────────────────────────────────┤
│ PK report_id (UUID)                                                 │
│ FK department_id → departments                                      │
│ FK category_id → categories                                         │
│ FK status_id → statuses                                             │
│    report_number (UNIQUE)                                           │
│    reported_date (TIMESTAMPTZ)                                      │
│    incident_date (DATE)                                             │
│    description (TEXT)                                               │
│    complainant_type                                                 │
│    is_anonymous (BOOLEAN)                                           │
│    priority (1-5)                                                   │
│    estimated_amount (NUMERIC)                                       │
│    assigned_to                                                      │
│    last_activity_date                                               │
│    resolution_date                                                  │
│    resolution_notes                                                 │
│    created_at, updated_at                                           │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ status_history  │    │  case_actions   │    │   escalations   │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ PK history_id   │    │ PK action_id    │    │ PK escalation_id│
│ FK report_id    │    │ FK report_id    │    │ FK report_id    │
│ FK old_status   │    │ FK action_type  │    │    escalated_to │
│ FK new_status   │    │    performed_by │    │    reason       │
│    changed_at   │    │    action_date  │    │    escalated_at │
│    changed_by   │    │    notes        │    │    resolved_at  │
│    reason       │    │    time_spent   │    │    outcome      │
└─────────────────┘    └─────────────────┘    └─────────────────┘

┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  action_types   │    │    officers     │    │  audit_log      │
├─────────────────┤    ├─────────────────┤    ├─────────────────┤
│ PK action_type_id    │ PK officer_id   │    │ PK log_id       │
│    name         │    │ FK department_id│    │    table_name   │
│    description  │    │    name         │    │    record_id    │
│    requires_note│    │    badge_number │    │    operation    │
└─────────────────┘    │    rank         │    │    old_values   │
                       │    email        │    │    new_values   │
                       │    is_active    │    │    performed_at │
                       └─────────────────┘    │    performed_by │
                                              └─────────────────┘
```

## Temporal Analytics Strategy

### 1. FILTER Clause for Conditional Aggregation

PostgreSQL's FILTER clause enables efficient conditional counting in a single pass:

```sql
-- Instead of multiple queries or CASE statements:
SELECT 
    department_id,
    COUNT(*) as total_cases,
    COUNT(*) FILTER (WHERE status = 'unresolved') as open_cases,
    COUNT(*) FILTER (WHERE status = 'resolved') as closed_cases,
    COUNT(*) FILTER (WHERE status = 'escalated') as escalated_cases,
    COUNT(*) FILTER (WHERE priority = 1) as critical_cases,
    COUNT(*) FILTER (
        WHERE status = 'unresolved' 
        AND reported_date < CURRENT_DATE - INTERVAL '90 days'
    ) as aging_cases
FROM reports
GROUP BY department_id;
```

### 2. Date Interval Calculations

```sql
-- Flexible date ranges using INTERVAL
WHERE reported_date > CURRENT_DATE - INTERVAL '1 year'
WHERE reported_date BETWEEN 
    DATE_TRUNC('quarter', CURRENT_DATE) - INTERVAL '1 quarter'
    AND DATE_TRUNC('quarter', CURRENT_DATE)

-- Age calculation for case aging
SELECT 
    report_id,
    AGE(CURRENT_TIMESTAMP, reported_date) as case_age,
    EXTRACT(EPOCH FROM AGE(CURRENT_TIMESTAMP, reported_date))/86400 as days_open
FROM reports
WHERE status_id NOT IN (SELECT status_id FROM statuses WHERE is_terminal);
```

### 3. Time Bucketing with DATE_TRUNC

```sql
-- Aggregate by time periods
SELECT 
    DATE_TRUNC('month', reported_date) as month,
    COUNT(*) as new_reports,
    SUM(estimated_amount) as total_amount_reported
FROM reports
GROUP BY DATE_TRUNC('month', reported_date)
ORDER BY month;

-- Weekly resolution rates
SELECT 
    DATE_TRUNC('week', resolution_date) as week,
    COUNT(*) as resolved_count,
    AVG(EXTRACT(EPOCH FROM (resolution_date - reported_date))/86400) as avg_days_to_resolve
FROM reports
WHERE resolution_date IS NOT NULL
GROUP BY DATE_TRUNC('week', resolution_date);
```

### 4. Gap-Filling with generate_series

```sql
-- Complete time series even when no data exists
SELECT 
    gs.date::DATE as report_date,
    COALESCE(r.count, 0) as reports_filed
FROM generate_series(
    CURRENT_DATE - INTERVAL '30 days',
    CURRENT_DATE,
    INTERVAL '1 day'
) as gs(date)
LEFT JOIN (
    SELECT DATE_TRUNC('day', reported_date) as day, COUNT(*) as count
    FROM reports
    GROUP BY 1
) r ON gs.date = r.day
ORDER BY gs.date;
```

### 5. Period Overlap Detection

```sql
-- Find concurrent escalations (multiple cases escalated same day)
SELECT 
    e1.report_id as report_1,
    e2.report_id as report_2,
    e1.escalated_at::DATE as escalation_date
FROM escalations e1
JOIN escalations e2 ON e1.escalation_id < e2.escalation_id
WHERE (e1.escalated_at::DATE, e1.escalated_at::DATE) 
    OVERLAPS (e2.escalated_at::DATE, e2.escalated_at::DATE);
```

## psql Script Patterns

### Variable Substitution

```sql
-- In psql scripts, use :variable_name
\set start_date '2025-01-01'
\set end_date '2025-12-31'

SELECT * FROM reports
WHERE reported_date BETWEEN :'start_date' AND :'end_date';
```

### Output Formatting

```sql
-- Set output format for CSV export
\pset format csv
\pset tuples_only on
\o /path/to/output.csv

SELECT * FROM vw_aging_report;

\o
\pset format aligned
\pset tuples_only off
```

### Conditional Logic in Scripts

```sql
-- Using DO blocks for procedural logic
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM reports
    WHERE status = 'unresolved'
    AND AGE(CURRENT_DATE, reported_date) > INTERVAL '180 days';
    
    IF v_count > 0 THEN
        RAISE NOTICE 'ALERT: % cases over 180 days old!', v_count;
    END IF;
END $$;
```

## Key Views

### Aging Report View
```sql
CREATE VIEW vw_aging_report AS
SELECT 
    d.name as department,
    c.name as category,
    COUNT(*) FILTER (WHERE AGE(CURRENT_DATE, r.reported_date) < INTERVAL '30 days') as "0-30 days",
    COUNT(*) FILTER (WHERE AGE(CURRENT_DATE, r.reported_date) >= INTERVAL '30 days' 
                      AND AGE(CURRENT_DATE, r.reported_date) < INTERVAL '90 days') as "31-90 days",
    COUNT(*) FILTER (WHERE AGE(CURRENT_DATE, r.reported_date) >= INTERVAL '90 days' 
                      AND AGE(CURRENT_DATE, r.reported_date) < INTERVAL '180 days') as "91-180 days",
    COUNT(*) FILTER (WHERE AGE(CURRENT_DATE, r.reported_date) >= INTERVAL '180 days') as "180+ days"
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN categories c ON r.category_id = c.category_id
WHERE r.status_id NOT IN (SELECT status_id FROM statuses WHERE is_terminal)
GROUP BY d.name, c.name;
```

### Month-over-Month Comparison
```sql
CREATE VIEW vw_mom_comparison AS
WITH monthly_stats AS (
    SELECT 
        DATE_TRUNC('month', reported_date) as month,
        COUNT(*) as new_reports,
        COUNT(*) FILTER (WHERE status_id IN (
            SELECT status_id FROM statuses WHERE is_terminal
        )) as resolved
    FROM reports
    WHERE reported_date >= DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '13 months'
    GROUP BY 1
)
SELECT 
    month,
    new_reports,
    resolved,
    LAG(new_reports) OVER (ORDER BY month) as prev_month_new,
    ROUND(100.0 * (new_reports - LAG(new_reports) OVER (ORDER BY month)) / 
        NULLIF(LAG(new_reports) OVER (ORDER BY month), 0), 2) as pct_change
FROM monthly_stats
ORDER BY month;
```

## Performance Considerations

### Indexing Strategy

```sql
-- Temporal query optimization
CREATE INDEX idx_reports_reported_date ON reports(reported_date);
CREATE INDEX idx_reports_status_date ON reports(status_id, reported_date);

-- Partial indexes for common filters
CREATE INDEX idx_reports_unresolved ON reports(reported_date) 
    WHERE status_id NOT IN (SELECT status_id FROM statuses WHERE is_terminal);

-- BRIN index for large time-series data
CREATE INDEX idx_reports_reported_date_brin ON reports 
    USING BRIN(reported_date) WITH (pages_per_range = 32);
```

### Materialized Views for Heavy Reports

```sql
-- Refresh nightly for dashboard queries
CREATE MATERIALIZED VIEW mv_department_monthly_stats AS
SELECT 
    d.department_id,
    d.name as department_name,
    DATE_TRUNC('month', r.reported_date) as month,
    COUNT(*) as total_reports,
    COUNT(*) FILTER (WHERE s.is_terminal) as resolved,
    AVG(EXTRACT(EPOCH FROM (r.resolution_date - r.reported_date))/86400) 
        FILTER (WHERE r.resolution_date IS NOT NULL) as avg_resolution_days
FROM reports r
JOIN departments d ON r.department_id = d.department_id
JOIN statuses s ON r.status_id = s.status_id
GROUP BY d.department_id, d.name, DATE_TRUNC('month', r.reported_date);

CREATE UNIQUE INDEX ON mv_department_monthly_stats(department_id, month);
```

## Security Model

```sql
-- Row-level security for department isolation
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY reports_department_policy ON reports
    FOR ALL
    TO analyst
    USING (department_id = current_setting('app.current_department_id')::UUID);

-- Audit logging trigger
CREATE OR REPLACE FUNCTION fn_audit_changes()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log(table_name, record_id, operation, old_values, new_values, performed_at)
    VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.report_id, OLD.report_id),
        TG_OP,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD) END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW) END,
        CURRENT_TIMESTAMP
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
```

## Report Scheduling

### Cron Schedule (Linux)
```bash
# Daily aging report at 6 AM
0 6 * * * psql -d corruption_auditor -f /path/to/daily_aging_report.sql

# Weekly summary every Monday at 7 AM
0 7 * * 1 psql -d corruption_auditor -f /path/to/weekly_resolution_summary.sql

# Monthly trends on 1st of month at 8 AM
0 8 1 * * psql -d corruption_auditor -f /path/to/monthly_category_trends.sql
```

### Windows Task Scheduler (PowerShell)
```powershell
# See scripts/schedule_reports.ps1 for automated setup
```
