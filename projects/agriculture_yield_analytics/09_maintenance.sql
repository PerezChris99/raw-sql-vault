-- ============================================================================
-- 🌾 AGRICULTURE YIELD ANALYTICS - MAINTENANCE & OPERATIONS
-- ============================================================================
-- File: 09_maintenance.sql
-- Purpose: Database maintenance, monitoring, backup, and operational scripts
-- Database: PostgreSQL 14+
-- Schedule: Configure via pg_cron or system cron
-- ============================================================================

SET search_path TO agri, public;

-- ============================================================================
-- SECTION 1: VACUUM & ANALYZE PROCEDURES
-- ============================================================================

-- 1.1 Comprehensive VACUUM ANALYZE for all agri tables
CREATE OR REPLACE PROCEDURE agri.maintenance_vacuum_all()
LANGUAGE plpgsql
AS $$
DECLARE
    v_table RECORD;
    v_start TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    RAISE NOTICE 'Starting full vacuum and analyze for agri schema...';
    v_start := clock_timestamp();
    
    FOR v_table IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'agri'
        ORDER BY tablename
    LOOP
        RAISE NOTICE 'Processing table: %', v_table.tablename;
        EXECUTE format('VACUUM ANALYZE agri.%I', v_table.tablename);
    END LOOP;
    
    v_duration := clock_timestamp() - v_start;
    RAISE NOTICE 'Full vacuum completed in %', v_duration;
    
    -- Log maintenance
    INSERT INTO agri.audit_log (table_name, operation, new_data, changed_by)
    VALUES ('maintenance', 'VACUUM_ALL', 
            jsonb_build_object('duration', v_duration::TEXT, 'completed_at', CURRENT_TIMESTAMP),
            'maintenance_job');
END;
$$;

-- 1.2 Targeted vacuum for high-activity tables
CREATE OR REPLACE PROCEDURE agri.maintenance_vacuum_hot_tables()
LANGUAGE plpgsql
AS $$
DECLARE
    v_tables TEXT[] := ARRAY['harvests', 'audit_log', 'weather_data', 'market_prices'];
    v_table TEXT;
BEGIN
    RAISE NOTICE 'Starting vacuum for high-activity tables...';
    
    FOREACH v_table IN ARRAY v_tables
    LOOP
        IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'agri' AND tablename = v_table) THEN
            RAISE NOTICE 'Vacuuming: %', v_table;
            EXECUTE format('VACUUM ANALYZE agri.%I', v_table);
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Hot table vacuum completed';
END;
$$;

-- 1.3 Analyze statistics for query optimizer
CREATE OR REPLACE PROCEDURE agri.maintenance_analyze_all()
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE 'Updating statistics for agri schema...';
    ANALYZE agri.regions;
    ANALYZE agri.districts;
    ANALYZE agri.sub_counties;
    ANALYZE agri.crops;
    ANALYZE agri.crop_varieties;
    ANALYZE agri.farmers;
    ANALYZE agri.farms;
    ANALYZE agri.farm_plots;
    ANALYZE agri.seasons;
    ANALYZE agri.harvests;
    ANALYZE agri.weather_data;
    ANALYZE agri.soil_data;
    ANALYZE agri.market_prices;
    RAISE NOTICE 'Statistics update completed';
END;
$$;

-- ============================================================================
-- SECTION 2: INDEX MAINTENANCE
-- ============================================================================

-- 2.1 Reindex bloated indexes
CREATE OR REPLACE PROCEDURE agri.maintenance_reindex_bloated(
    p_bloat_threshold DECIMAL DEFAULT 30.0
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_idx RECORD;
    v_reindexed INTEGER := 0;
BEGIN
    RAISE NOTICE 'Identifying bloated indexes (threshold: %%)...', p_bloat_threshold;
    
    FOR v_idx IN 
        SELECT 
            schemaname,
            indexrelname,
            pg_relation_size(indexrelid) AS index_size,
            100 * (1 - pg_relation_size(indexrelid)::FLOAT / 
                   GREATEST(pg_table_size(indrelid), 1)) AS bloat_ratio
        FROM pg_stat_user_indexes
        WHERE schemaname = 'agri'
        AND pg_relation_size(indexrelid) > 1048576 -- > 1MB
        HAVING 100 * (1 - pg_relation_size(indexrelid)::FLOAT / 
                      GREATEST(pg_table_size(indrelid), 1)) > p_bloat_threshold
    LOOP
        RAISE NOTICE 'Reindexing % (bloat: %%)', v_idx.indexrelname, ROUND(v_idx.bloat_ratio::NUMERIC, 2);
        EXECUTE format('REINDEX INDEX CONCURRENTLY agri.%I', v_idx.indexrelname);
        v_reindexed := v_reindexed + 1;
    END LOOP;
    
    RAISE NOTICE 'Reindexed % bloated indexes', v_reindexed;
END;
$$;

-- 2.2 Check index effectiveness
CREATE OR REPLACE VIEW agri.v_index_effectiveness AS
SELECT 
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED'
        WHEN idx_scan < 10 THEN 'RARELY_USED'
        WHEN idx_scan < 100 THEN 'OCCASIONALLY_USED'
        ELSE 'FREQUENTLY_USED'
    END AS usage_classification
FROM pg_stat_user_indexes
WHERE schemaname = 'agri'
ORDER BY idx_scan DESC;

-- 2.3 Identify unused indexes
CREATE OR REPLACE VIEW agri.v_unused_indexes AS
SELECT 
    schemaname,
    relname AS table_name,
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan AS scans,
    idx_tup_read AS tuples_read
FROM pg_stat_user_indexes
WHERE schemaname = 'agri'
AND idx_scan = 0
AND indexrelname NOT LIKE '%_pkey'  -- Exclude primary keys
ORDER BY pg_relation_size(indexrelid) DESC;

-- ============================================================================
-- SECTION 3: MATERIALIZED VIEW MAINTENANCE
-- ============================================================================

-- 3.1 Refresh all materialized views
CREATE OR REPLACE PROCEDURE agri.maintenance_refresh_materialized_views(
    p_concurrent BOOLEAN DEFAULT TRUE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_mv RECORD;
    v_start TIMESTAMP;
    v_duration INTERVAL;
BEGIN
    RAISE NOTICE 'Refreshing materialized views...';
    v_start := clock_timestamp();
    
    FOR v_mv IN 
        SELECT matviewname 
        FROM pg_matviews 
        WHERE schemaname = 'agri'
        ORDER BY matviewname
    LOOP
        RAISE NOTICE 'Refreshing: %', v_mv.matviewname;
        
        IF p_concurrent THEN
            EXECUTE format('REFRESH MATERIALIZED VIEW CONCURRENTLY agri.%I', v_mv.matviewname);
        ELSE
            EXECUTE format('REFRESH MATERIALIZED VIEW agri.%I', v_mv.matviewname);
        END IF;
    END LOOP;
    
    v_duration := clock_timestamp() - v_start;
    RAISE NOTICE 'Materialized view refresh completed in %', v_duration;
    
    -- Log refresh
    INSERT INTO agri.audit_log (table_name, operation, new_data, changed_by)
    VALUES ('materialized_views', 'REFRESH_ALL', 
            jsonb_build_object('duration', v_duration::TEXT, 'concurrent', p_concurrent),
            'maintenance_job');
END;
$$;

-- 3.2 Check materialized view freshness
CREATE OR REPLACE VIEW agri.v_materialized_view_status AS
SELECT 
    schemaname,
    matviewname,
    pg_size_pretty(pg_relation_size(format('%I.%I', schemaname, matviewname)::regclass)) AS size,
    (
        SELECT MAX(changed_at)
        FROM agri.audit_log
        WHERE table_name = 'materialized_views'
        AND operation = 'REFRESH_ALL'
    ) AS last_refresh_time,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - (
        SELECT MAX(changed_at)
        FROM agri.audit_log
        WHERE table_name = 'materialized_views'
        AND operation = 'REFRESH_ALL'
    ))) / 3600 AS hours_since_refresh
FROM pg_matviews
WHERE schemaname = 'agri';

-- ============================================================================
-- SECTION 4: TABLE STATISTICS & HEALTH
-- ============================================================================

-- 4.1 Comprehensive table statistics view
CREATE OR REPLACE VIEW agri.v_table_statistics AS
SELECT 
    relname AS table_name,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_row_pct,
    pg_size_pretty(pg_table_size(relid)) AS table_size,
    pg_size_pretty(pg_indexes_size(relid)) AS index_size,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    vacuum_count + autovacuum_count AS total_vacuums,
    analyze_count + autoanalyze_count AS total_analyzes
FROM pg_stat_user_tables
WHERE schemaname = 'agri'
ORDER BY pg_total_relation_size(relid) DESC;

-- 4.2 Table bloat estimation
CREATE OR REPLACE VIEW agri.v_table_bloat AS
SELECT
    schemaname || '.' || relname AS table_name,
    pg_size_pretty(pg_table_size(relid)) AS table_size,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    CASE 
        WHEN n_dead_tup > n_live_tup * 0.2 THEN 'HIGH_BLOAT'
        WHEN n_dead_tup > n_live_tup * 0.1 THEN 'MODERATE_BLOAT'
        ELSE 'NORMAL'
    END AS bloat_status,
    CASE 
        WHEN last_autovacuum IS NULL THEN 'NEVER'
        WHEN last_autovacuum < CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 'OVERDUE'
        ELSE 'RECENT'
    END AS vacuum_status,
    last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname = 'agri'
ORDER BY n_dead_tup DESC;

-- 4.3 Row count summary
CREATE OR REPLACE FUNCTION agri.get_table_row_counts()
RETURNS TABLE(
    table_name TEXT,
    row_count BIGINT,
    last_updated TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_table RECORD;
    v_count BIGINT;
BEGIN
    FOR v_table IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'agri'
        AND tablename NOT LIKE '%_partitioned'
        ORDER BY tablename
    LOOP
        EXECUTE format('SELECT COUNT(*) FROM agri.%I', v_table.tablename) INTO v_count;
        table_name := v_table.tablename;
        row_count := v_count;
        last_updated := CURRENT_TIMESTAMP;
        RETURN NEXT;
    END LOOP;
END;
$$;

-- ============================================================================
-- SECTION 5: DATA QUALITY CHECKS
-- ============================================================================

-- 5.1 Data integrity check procedure
CREATE OR REPLACE FUNCTION agri.check_data_integrity()
RETURNS TABLE(
    check_name TEXT,
    status TEXT,
    details TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    -- Check: Orphan harvests (no farmer)
    check_name := 'Orphan Harvests (No Farmer)';
    SELECT CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Found ' || COUNT(*) || ' orphan records'
    INTO status, details
    FROM agri.harvests h
    WHERE NOT EXISTS (SELECT 1 FROM agri.farmers f WHERE f.farmer_id = h.farmer_id);
    RETURN NEXT;
    
    -- Check: Harvests with invalid dates
    check_name := 'Invalid Harvest Dates';
    SELECT CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Found ' || COUNT(*) || ' records with harvest_date before planting_date'
    INTO status, details
    FROM agri.harvests
    WHERE harvest_date < planting_date;
    RETURN NEXT;
    
    -- Check: Negative yields
    check_name := 'Negative Yields';
    SELECT CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Found ' || COUNT(*) || ' records with negative yield'
    INTO status, details
    FROM agri.harvests
    WHERE total_yield_kg < 0;
    RETURN NEXT;
    
    -- Check: Zero area harvests
    check_name := 'Zero Area Harvests';
    SELECT CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END,
           'Found ' || COUNT(*) || ' records with zero area'
    INTO status, details
    FROM agri.harvests
    WHERE area_harvested_hectares = 0;
    RETURN NEXT;
    
    -- Check: Future harvest dates
    check_name := 'Future Harvest Dates';
    SELECT CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'WARN' END,
           'Found ' || COUNT(*) || ' records with future dates'
    INTO status, details
    FROM agri.harvests
    WHERE harvest_date > CURRENT_DATE + INTERVAL '30 days';
    RETURN NEXT;
    
    -- Check: Duplicate farmer codes
    check_name := 'Duplicate Farmer Codes';
    SELECT CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Found ' || COUNT(*) || ' duplicate codes'
    INTO status, details
    FROM (
        SELECT farmer_code, COUNT(*) 
        FROM agri.farmers 
        GROUP BY farmer_code 
        HAVING COUNT(*) > 1
    ) t;
    RETURN NEXT;
    
    -- Check: Districts without region
    check_name := 'Orphan Districts';
    SELECT CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END,
           'Found ' || COUNT(*) || ' districts without region'
    INTO status, details
    FROM agri.districts d
    WHERE NOT EXISTS (SELECT 1 FROM agri.regions r WHERE r.region_id = d.region_id);
    RETURN NEXT;
END;
$$;

-- 5.2 Data completeness check
CREATE OR REPLACE FUNCTION agri.check_data_completeness()
RETURNS TABLE(
    table_name TEXT,
    column_name TEXT,
    null_count BIGINT,
    total_count BIGINT,
    null_pct DECIMAL(5,2)
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    -- Harvests: Check critical columns
    FOR table_name, column_name, null_count, total_count, null_pct IN
        SELECT 'harvests' AS tn, 'quality_grade' AS cn,
               COUNT(*) FILTER (WHERE quality_grade IS NULL),
               COUNT(*),
               ROUND(100.0 * COUNT(*) FILTER (WHERE quality_grade IS NULL) / NULLIF(COUNT(*), 0), 2)
        FROM agri.harvests
        UNION ALL
        SELECT 'harvests', 'sale_price_per_kg',
               COUNT(*) FILTER (WHERE sale_price_per_kg IS NULL),
               COUNT(*),
               ROUND(100.0 * COUNT(*) FILTER (WHERE sale_price_per_kg IS NULL) / NULLIF(COUNT(*), 0), 2)
        FROM agri.harvests
        UNION ALL
        SELECT 'farmers', 'phone_primary',
               COUNT(*) FILTER (WHERE phone_primary IS NULL),
               COUNT(*),
               ROUND(100.0 * COUNT(*) FILTER (WHERE phone_primary IS NULL) / NULLIF(COUNT(*), 0), 2)
        FROM agri.farmers
        UNION ALL
        SELECT 'farms', 'total_area_hectares',
               COUNT(*) FILTER (WHERE total_area_hectares IS NULL),
               COUNT(*),
               ROUND(100.0 * COUNT(*) FILTER (WHERE total_area_hectares IS NULL) / NULLIF(COUNT(*), 0), 2)
        FROM agri.farms
    LOOP
        RETURN NEXT;
    END LOOP;
END;
$$;

-- ============================================================================
-- SECTION 6: AUDIT LOG MANAGEMENT
-- ============================================================================

-- 6.1 Archive old audit logs
CREATE OR REPLACE PROCEDURE agri.maintenance_archive_audit_logs(
    p_days_to_keep INTEGER DEFAULT 90
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_archived_count BIGINT;
    v_cutoff_date TIMESTAMP WITH TIME ZONE;
BEGIN
    v_cutoff_date := CURRENT_TIMESTAMP - (p_days_to_keep || ' days')::INTERVAL;
    
    RAISE NOTICE 'Archiving audit logs older than %', v_cutoff_date;
    
    -- Create archive table if not exists
    CREATE TABLE IF NOT EXISTS agri.audit_log_archive (LIKE agri.audit_log INCLUDING ALL);
    
    -- Move old records to archive
    WITH archived AS (
        DELETE FROM agri.audit_log
        WHERE changed_at < v_cutoff_date
        RETURNING *
    )
    INSERT INTO agri.audit_log_archive
    SELECT * FROM archived;
    
    GET DIAGNOSTICS v_archived_count = ROW_COUNT;
    
    RAISE NOTICE 'Archived % audit log records', v_archived_count;
    
    -- Vacuum the table
    VACUUM agri.audit_log;
END;
$$;

-- 6.2 Audit log statistics
CREATE OR REPLACE VIEW agri.v_audit_log_stats AS
SELECT 
    table_name,
    operation,
    DATE(changed_at) AS log_date,
    COUNT(*) AS operation_count
FROM agri.audit_log
WHERE changed_at > CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY table_name, operation, DATE(changed_at)
ORDER BY DATE(changed_at) DESC, table_name;

-- ============================================================================
-- SECTION 7: CONNECTION & PERFORMANCE MONITORING
-- ============================================================================

-- 7.1 Current connections view
CREATE OR REPLACE VIEW agri.v_current_connections AS
SELECT 
    pid,
    usename AS username,
    application_name,
    client_addr,
    backend_start,
    state,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - query_start))::INTEGER AS query_seconds,
    LEFT(query, 100) AS query_preview
FROM pg_stat_activity
WHERE datname = current_database()
AND pid <> pg_backend_pid()
ORDER BY query_start;

-- 7.2 Long-running queries view
CREATE OR REPLACE VIEW agri.v_long_running_queries AS
SELECT 
    pid,
    usename,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - query_start))::INTEGER AS duration_seconds,
    state,
    query
FROM pg_stat_activity
WHERE datname = current_database()
AND state != 'idle'
AND query_start < CURRENT_TIMESTAMP - INTERVAL '30 seconds'
ORDER BY query_start;

-- 7.3 Cache hit ratio
CREATE OR REPLACE VIEW agri.v_cache_performance AS
SELECT 
    'Buffer Cache' AS cache_type,
    ROUND(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS hit_ratio_pct
FROM pg_stat_database
WHERE datname = current_database()
UNION ALL
SELECT 
    'Index Cache',
    ROUND(100.0 * idx_blks_hit / NULLIF(idx_blks_hit + idx_blks_read, 0), 2)
FROM pg_statio_user_tables
WHERE schemaname = 'agri';

-- ============================================================================
-- SECTION 8: SCHEDULED MAINTENANCE JOBS
-- ============================================================================

/*
CRON SCHEDULE RECOMMENDATIONS (using pg_cron extension):
========================================================

-- Enable pg_cron extension (requires superuser)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Daily: Refresh materialized views (2 AM)
SELECT cron.schedule('refresh-mvs', '0 2 * * *', 
    'CALL agri.maintenance_refresh_materialized_views(TRUE)');

-- Weekly: Vacuum hot tables (Sunday 3 AM)
SELECT cron.schedule('vacuum-hot', '0 3 * * 0', 
    'CALL agri.maintenance_vacuum_hot_tables()');

-- Monthly: Full vacuum (1st of month, 4 AM)
SELECT cron.schedule('vacuum-full', '0 4 1 * *', 
    'CALL agri.maintenance_vacuum_all()');

-- Monthly: Archive audit logs (1st of month, 5 AM)
SELECT cron.schedule('archive-audit', '0 5 1 * *', 
    'CALL agri.maintenance_archive_audit_logs(90)');

-- Quarterly: Reindex bloated indexes (1st of Jan/Apr/Jul/Oct, 6 AM)
SELECT cron.schedule('reindex', '0 6 1 1,4,7,10 *', 
    'CALL agri.maintenance_reindex_bloated(30)');

-- View scheduled jobs:
SELECT * FROM cron.job;

-- Unschedule a job:
SELECT cron.unschedule('job-name');
*/

-- 8.1 Manual maintenance runner
CREATE OR REPLACE PROCEDURE agri.run_maintenance_suite(
    p_vacuum BOOLEAN DEFAULT TRUE,
    p_analyze BOOLEAN DEFAULT TRUE,
    p_refresh_mvs BOOLEAN DEFAULT TRUE,
    p_check_integrity BOOLEAN DEFAULT TRUE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_start TIMESTAMP;
    v_results JSONB := '{}';
BEGIN
    v_start := clock_timestamp();
    RAISE NOTICE '======================================';
    RAISE NOTICE 'MAINTENANCE SUITE STARTING';
    RAISE NOTICE '======================================';
    
    IF p_vacuum THEN
        RAISE NOTICE '[1/4] Running vacuum...';
        CALL agri.maintenance_vacuum_hot_tables();
        v_results := v_results || '{"vacuum": "completed"}'::JSONB;
    END IF;
    
    IF p_analyze THEN
        RAISE NOTICE '[2/4] Running analyze...';
        CALL agri.maintenance_analyze_all();
        v_results := v_results || '{"analyze": "completed"}'::JSONB;
    END IF;
    
    IF p_refresh_mvs THEN
        RAISE NOTICE '[3/4] Refreshing materialized views...';
        CALL agri.maintenance_refresh_materialized_views(TRUE);
        v_results := v_results || '{"mvs": "refreshed"}'::JSONB;
    END IF;
    
    IF p_check_integrity THEN
        RAISE NOTICE '[4/4] Running integrity checks...';
        -- Log results
        INSERT INTO agri.audit_log (table_name, operation, new_data, changed_by)
        SELECT 
            'maintenance',
            'INTEGRITY_CHECK',
            jsonb_agg(jsonb_build_object('check', check_name, 'status', status, 'details', details)),
            'maintenance_job'
        FROM agri.check_data_integrity();
        v_results := v_results || '{"integrity": "checked"}'::JSONB;
    END IF;
    
    RAISE NOTICE '======================================';
    RAISE NOTICE 'MAINTENANCE COMPLETE';
    RAISE NOTICE 'Duration: %', clock_timestamp() - v_start;
    RAISE NOTICE '======================================';
    
    -- Final log
    INSERT INTO agri.audit_log (table_name, operation, new_data, changed_by)
    VALUES ('maintenance', 'SUITE_COMPLETE', 
            v_results || jsonb_build_object('duration', (clock_timestamp() - v_start)::TEXT),
            'maintenance_job');
END;
$$;

-- ============================================================================
-- SECTION 9: BACKUP HELPERS
-- ============================================================================

-- 9.1 Generate backup commands
CREATE OR REPLACE FUNCTION agri.generate_backup_commands(
    p_backup_dir TEXT DEFAULT '/var/backups/agri'
)
RETURNS TABLE(
    backup_type TEXT,
    command TEXT
)
LANGUAGE sql
STABLE
AS $$
    -- Full schema backup
    SELECT 
        'Schema Only',
        format('pg_dump -h localhost -U postgres -d your_database -n agri --schema-only -f %s/agri_schema_%s.sql', 
               p_backup_dir, TO_CHAR(CURRENT_DATE, 'YYYYMMDD'))
    UNION ALL
    -- Full data backup
    SELECT 
        'Full Data',
        format('pg_dump -h localhost -U postgres -d your_database -n agri -F c -f %s/agri_full_%s.dump', 
               p_backup_dir, TO_CHAR(CURRENT_DATE, 'YYYYMMDD'))
    UNION ALL
    -- Harvests only (large table)
    SELECT
        'Harvests Table',
        format('pg_dump -h localhost -U postgres -d your_database -t agri.harvests -F c -f %s/harvests_%s.dump', 
               p_backup_dir, TO_CHAR(CURRENT_DATE, 'YYYYMMDD'))
    UNION ALL
    -- Lookup tables
    SELECT
        'Lookup Tables',
        format('pg_dump -h localhost -U postgres -d your_database -t agri.regions -t agri.districts -t agri.crops -F c -f %s/lookups_%s.dump', 
               p_backup_dir, TO_CHAR(CURRENT_DATE, 'YYYYMMDD'));
$$;

-- 9.2 Table size for backup planning
CREATE OR REPLACE VIEW agri.v_backup_planning AS
SELECT 
    'agri' AS schema_name,
    relname AS table_name,
    pg_size_pretty(pg_table_size(relid)) AS data_size,
    pg_size_pretty(pg_indexes_size(relid)) AS index_size,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    n_live_tup AS row_count,
    CASE 
        WHEN pg_total_relation_size(relid) > 1073741824 THEN 'LARGE' -- > 1GB
        WHEN pg_total_relation_size(relid) > 104857600 THEN 'MEDIUM' -- > 100MB
        ELSE 'SMALL'
    END AS size_category
FROM pg_stat_user_tables
WHERE schemaname = 'agri'
ORDER BY pg_total_relation_size(relid) DESC;

-- ============================================================================
-- SECTION 10: DISASTER RECOVERY PROCEDURES
-- ============================================================================

-- 10.1 Quick health check
CREATE OR REPLACE FUNCTION agri.quick_health_check()
RETURNS TABLE(
    component TEXT,
    status TEXT,
    value TEXT
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    -- Database connectivity
    component := 'Database Connection';
    status := 'OK';
    value := current_database();
    RETURN NEXT;
    
    -- Schema exists
    component := 'Agri Schema';
    SELECT CASE WHEN EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'agri') THEN 'OK' ELSE 'FAIL' END,
           'Schema present'
    INTO status, value;
    RETURN NEXT;
    
    -- Core tables exist
    component := 'Core Tables';
    SELECT 
        CASE WHEN COUNT(*) >= 10 THEN 'OK' ELSE 'WARN' END,
        COUNT(*) || ' tables found'
    INTO status, value
    FROM pg_tables WHERE schemaname = 'agri';
    RETURN NEXT;
    
    -- Recent data
    component := 'Recent Harvests';
    SELECT 
        CASE WHEN MAX(created_at) > CURRENT_TIMESTAMP - INTERVAL '7 days' THEN 'OK' ELSE 'WARN' END,
        COALESCE('Last harvest: ' || MAX(created_at)::TEXT, 'No data')
    INTO status, value
    FROM agri.harvests;
    RETURN NEXT;
    
    -- Disk space (approximate via table size)
    component := 'Total Data Size';
    status := 'INFO';
    SELECT pg_size_pretty(SUM(pg_total_relation_size(relid)))
    INTO value
    FROM pg_stat_user_tables
    WHERE schemaname = 'agri';
    RETURN NEXT;
    
    -- Connection count
    component := 'Active Connections';
    SELECT 
        CASE WHEN COUNT(*) > 50 THEN 'WARN' ELSE 'OK' END,
        COUNT(*) || ' connections'
    INTO status, value
    FROM pg_stat_activity
    WHERE datname = current_database();
    RETURN NEXT;
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_proc_count INTEGER;
    v_view_count INTEGER;
    v_func_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_proc_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'agri' AND p.proname LIKE 'maintenance_%';
    
    SELECT COUNT(*) INTO v_view_count
    FROM pg_views
    WHERE schemaname = 'agri' AND viewname LIKE 'v_%';
    
    SELECT COUNT(*) INTO v_func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'agri' 
    AND (p.proname LIKE 'check_%' OR p.proname LIKE 'get_%' OR p.proname LIKE 'generate_%');
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'MAINTENANCE SCRIPTS INSTALLED SUCCESSFULLY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Maintenance procedures: %', v_proc_count;
    RAISE NOTICE 'Monitoring views: %', v_view_count;
    RAISE NOTICE 'Utility functions: %', v_func_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Key Procedures:';
    RAISE NOTICE '  - maintenance_vacuum_all()';
    RAISE NOTICE '  - maintenance_vacuum_hot_tables()';
    RAISE NOTICE '  - maintenance_analyze_all()';
    RAISE NOTICE '  - maintenance_reindex_bloated(threshold)';
    RAISE NOTICE '  - maintenance_refresh_materialized_views()';
    RAISE NOTICE '  - maintenance_archive_audit_logs(days)';
    RAISE NOTICE '  - run_maintenance_suite(options...)';
    RAISE NOTICE '';
    RAISE NOTICE 'Health Check:';
    RAISE NOTICE '  SELECT * FROM agri.quick_health_check();';
    RAISE NOTICE '';
    RAISE NOTICE 'Data Quality:';
    RAISE NOTICE '  SELECT * FROM agri.check_data_integrity();';
    RAISE NOTICE '  SELECT * FROM agri.check_data_completeness();';
    RAISE NOTICE '==========================================';
END $$;
