# Deployment Guide

## Prerequisites

- PostgreSQL 14+ installed
- `psql` CLI or pgAdmin access
- Superuser or database admin privileges

## Environment Setup

### 1. Create Database

```sql
CREATE DATABASE surveillance_db
    WITH ENCODING = 'UTF8'
         LC_COLLATE = 'en_US.UTF-8'
         LC_CTYPE = 'en_US.UTF-8'
         TEMPLATE = template0;
```

### 2. Configure Connection

Set environment variables:

```powershell
$env:PGHOST = "localhost"
$env:PGPORT = "5432"
$env:PGDATABASE = "surveillance_db"
$env:PGUSER = "surveillance_admin"
$env:PGPASSWORD = "your_secure_password"
```

Or create a `.pgpass` file:
```
localhost:5432:surveillance_db:surveillance_admin:your_secure_password
```

## Deployment Options

### Option 1: Automated Deployment (Recommended)

```powershell
cd healthcare_outbreak_detector
.\scripts\deploy.ps1 -Database "surveillance_db" -CreateDb
```

### Option 2: Manual Migration

Run migrations in order:

```powershell
psql -d surveillance_db -f database/migrations/V001__extensions.sql
psql -d surveillance_db -f database/migrations/V002__schema_enums.sql
psql -d surveillance_db -f database/migrations/V003__schema_tables.sql
psql -d surveillance_db -f database/migrations/V004__schema_triggers.sql
psql -d surveillance_db -f database/migrations/V005__indexes.sql
```

Then load functions:
```powershell
# Analytics functions
Get-ChildItem database/functions/analytics/*.sql | ForEach-Object {
    psql -d surveillance_db -f $_.FullName
}

# API functions
Get-ChildItem database/functions/api/*.sql | ForEach-Object {
    psql -d surveillance_db -f $_.FullName
}

# Stored procedures
Get-ChildItem database/functions/procedures/*.sql | ForEach-Object {
    psql -d surveillance_db -f $_.FullName
}
```

### Option 3: Using Flyway

If using Flyway for migrations:

```yaml
# flyway.conf
flyway.url=jdbc:postgresql://localhost:5432/surveillance_db
flyway.user=surveillance_admin
flyway.password=${FLYWAY_PASSWORD}
flyway.schemas=surveillance
flyway.locations=filesystem:database/migrations
```

```bash
flyway migrate
```

## Post-Deployment

### 1. Load Seed Data

```powershell
psql -d surveillance_db -f database/seeds/01_regions.sql
psql -d surveillance_db -f database/seeds/02_districts.sql
psql -d surveillance_db -f database/seeds/03_disease_categories.sql
psql -d surveillance_db -f database/seeds/04_diseases.sql
psql -d surveillance_db -f database/seeds/05_health_facilities.sql
```

### 2. Create Application Roles

```sql
-- Read-only role
CREATE ROLE surveillance_readonly;
GRANT USAGE ON SCHEMA surveillance TO surveillance_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA surveillance TO surveillance_readonly;

-- Operator role (CRUD)
CREATE ROLE surveillance_operator;
GRANT USAGE ON SCHEMA surveillance TO surveillance_operator;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA surveillance TO surveillance_operator;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA surveillance TO surveillance_operator;

-- Admin role
CREATE ROLE surveillance_admin;
GRANT ALL PRIVILEGES ON SCHEMA surveillance TO surveillance_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA surveillance TO surveillance_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA surveillance TO surveillance_admin;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA surveillance TO surveillance_admin;
```

### 3. Create Application User

```sql
CREATE USER app_user WITH PASSWORD 'secure_password';
GRANT surveillance_operator TO app_user;

-- For API access
CREATE USER api_user WITH PASSWORD 'api_password';
GRANT surveillance_readonly TO api_user;
GRANT EXECUTE ON FUNCTION surveillance.api_get_dashboard() TO api_user;
GRANT EXECUTE ON FUNCTION surveillance.api_list_cases(VARCHAR, VARCHAR, VARCHAR, DATE, DATE, INTEGER, INTEGER) TO api_user;
-- ... grant other API functions
```

### 4. Verify Deployment

```sql
-- Health check
SELECT surveillance.health_check();

-- Verify table count
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'surveillance';

-- Verify function count
SELECT COUNT(*) FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'surveillance';

-- Test API
SELECT surveillance.api_get_dashboard();
```

## Scheduled Jobs

### Using pg_cron

```sql
-- Install extension
CREATE EXTENSION pg_cron;

-- Hourly: Alert generation
SELECT cron.schedule('generate-alerts', '0 * * * *', 
    'CALL surveillance.run_hourly_alert_check()');

-- Daily: Maintenance
SELECT cron.schedule('daily-maintenance', '0 2 * * *', 
    'CALL surveillance.run_daily_maintenance()');

-- Weekly: Archive old data
SELECT cron.schedule('weekly-maintenance', '0 3 * * 0', 
    'CALL surveillance.run_weekly_maintenance()');

-- Hourly: Refresh materialized views
SELECT cron.schedule('refresh-views', '30 * * * *', 
    'CALL surveillance.refresh_dashboard_views()');
```

### Using Windows Task Scheduler

Create scheduled task:
```powershell
$action = New-ScheduledTaskAction -Execute "psql" -Argument "-d surveillance_db -c 'CALL surveillance.run_daily_maintenance()'"
$trigger = New-ScheduledTaskTrigger -Daily -At 2am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Surveillance Daily Maintenance"
```

## Backup Strategy

### Daily Backup

```powershell
$date = Get-Date -Format "yyyyMMdd"
pg_dump -Fc surveillance_db > "backups/surveillance_db_$date.dump"
```

### Point-in-Time Recovery

Configure `postgresql.conf`:
```
wal_level = replica
archive_mode = on
archive_command = 'copy %p C:\\pg_archive\\%f'
```

## Rollback

### Using Rollback Script

```powershell
.\scripts\rollback.ps1 -Version "V003"
```

### Manual Rollback

Each migration has a corresponding down script:
```powershell
psql -d surveillance_db -f database/migrations/V005__indexes_down.sql
psql -d surveillance_db -f database/migrations/V004__schema_triggers_down.sql
# ... continue in reverse order
```

## Monitoring

### Connection Monitoring

```sql
SELECT surveillance.get_connection_stats();
```

### Performance Monitoring

```sql
-- Slow queries (requires pg_stat_statements)
SELECT surveillance.get_slow_queries(500);

-- Table bloat
SELECT * FROM surveillance.get_table_bloat();

-- Unused indexes
SELECT * FROM surveillance.get_unused_indexes();
```

### Health Dashboard

```sql
SELECT surveillance.health_check();
```

## Troubleshooting

### Common Issues

**Issue**: Extension not found
```sql
-- Solution: Install as superuser
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

**Issue**: Permission denied
```sql
-- Solution: Grant schema usage
GRANT USAGE ON SCHEMA surveillance TO your_user;
```

**Issue**: Connection pool exhausted
```sql
-- Check connections
SELECT state, COUNT(*) FROM pg_stat_activity GROUP BY state;
-- Terminate idle connections
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'idle' AND query_start < now() - interval '1 hour';
```

### Log Analysis

```sql
-- Recent errors in PostgreSQL log
-- Check: $PGDATA/log/postgresql-*.log

-- Audit trail
SELECT * FROM surveillance.audit_log 
ORDER BY changed_at DESC 
LIMIT 100;
```
