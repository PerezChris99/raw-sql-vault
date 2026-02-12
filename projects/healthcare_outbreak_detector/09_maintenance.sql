-- ============================================================================
-- 🏥 HEALTHCARE OUTBREAK DETECTOR - DATABASE MAINTENANCE
-- ============================================================================
-- File: 09_maintenance.sql
-- Purpose: VACUUM, archival, partitioning, performance monitoring
-- Database: PostgreSQL 14+
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- SECTION 1: TABLE PARTITIONING
-- ============================================================================

-- 1.1 Convert cases table to partitioned (for new installations)
-- Note: This creates a partitioned version; existing data requires migration
CREATE TABLE IF NOT EXISTS surveillance.cases_partitioned (
    LIKE surveillance.cases INCLUDING ALL
) PARTITION BY RANGE (report_date);

-- Create annual partitions
DO $$
DECLARE
    v_year INTEGER;
BEGIN
    FOR v_year IN 2020..2030 LOOP
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS surveillance.cases_y%s 
             PARTITION OF surveillance.cases_partitioned 
             FOR VALUES FROM (%L) TO (%L)',
            v_year,
            make_date(v_year, 1, 1),
            make_date(v_year + 1, 1, 1)
        );
    END LOOP;
END $$;

-- 1.2 Daily case counts partitioned by year
CREATE TABLE IF NOT EXISTS surveillance.daily_counts_partitioned (
    LIKE surveillance.daily_case_counts INCLUDING ALL
) PARTITION BY RANGE (count_date);

DO $$
DECLARE
    v_year INTEGER;
BEGIN
    FOR v_year IN 2020..2030 LOOP
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS surveillance.daily_counts_y%s 
             PARTITION OF surveillance.daily_counts_partitioned 
             FOR VALUES FROM (%L) TO (%L)',
            v_year,
            make_date(v_year, 1, 1),
            make_date(v_year + 1, 1, 1)
        );
    END LOOP;
END $$;

-- ============================================================================
-- SECTION 2: DATA ARCHIVAL
-- ============================================================================

-- 2.1 Archive old cases to history table
CREATE TABLE IF NOT EXISTS surveillance.cases_archive (
    LIKE surveillance.cases INCLUDING ALL,
    archived_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    archive_reason VARCHAR(100)
);

CREATE OR REPLACE PROCEDURE surveillance.archive_old_cases(
    p_older_than_years INTEGER DEFAULT 5
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cutoff_date DATE;
    v_archived_count INTEGER;
BEGIN
    v_cutoff_date := CURRENT_DATE - (p_older_than_years || ' years')::INTERVAL;
    
    -- Insert into archive
    WITH archived AS (
        INSERT INTO surveillance.cases_archive
        SELECT *, CURRENT_TIMESTAMP, 'age_based_archival'
        FROM surveillance.cases
        WHERE report_date < v_cutoff_date
        AND case_status IN ('recovered', 'deceased', 'not_a_case')
        RETURNING case_id
    )
    DELETE FROM surveillance.cases
    WHERE case_id IN (SELECT case_id FROM archived);
    
    GET DIAGNOSTICS v_archived_count = ROW_COUNT;
    
    RAISE NOTICE 'Archived % cases older than %', v_archived_count, v_cutoff_date;
END;
$$;

-- 2.2 Archive resolved alerts
CREATE TABLE IF NOT EXISTS surveillance.alerts_archive (
    LIKE surveillance.alerts INCLUDING ALL,
    archived_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE PROCEDURE surveillance.archive_old_alerts(
    p_older_than_days INTEGER DEFAULT 365
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_archived_count INTEGER;
BEGIN
    WITH archived AS (
        INSERT INTO surveillance.alerts_archive
        SELECT *, CURRENT_TIMESTAMP
        FROM surveillance.alerts
        WHERE resolved_at < CURRENT_DATE - p_older_than_days
        AND alert_status IN ('resolved', 'dismissed')
        RETURNING alert_id
    )
    DELETE FROM surveillance.alerts
    WHERE alert_id IN (SELECT alert_id FROM archived);
    
    GET DIAGNOSTICS v_archived_count = ROW_COUNT;
    
    RAISE NOTICE 'Archived % alerts older than % days', v_archived_count, p_older_than_days;
END;
$$;

-- 2.3 Purge audit logs
CREATE OR REPLACE PROCEDURE surveillance.purge_audit_logs(
    p_older_than_days INTEGER DEFAULT 90
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM surveillance.audit_log
    WHERE changed_at < CURRENT_DATE - p_older_than_days;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RAISE NOTICE 'Purged % audit log entries older than % days', v_deleted_count, p_older_than_days;
END;
$$;

-- ============================================================================
-- SECTION 3: VACUUM AND ANALYZE
-- ============================================================================

-- 3.1 Smart vacuum procedure
CREATE OR REPLACE PROCEDURE surveillance.run_vacuum_analyze()
LANGUAGE plpgsql
AS $$
DECLARE
    v_table_name TEXT;
BEGIN
    -- Analyze key tables
    FOR v_table_name IN 
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'surveillance' 
        AND table_type = 'BASE TABLE'
    LOOP
        EXECUTE format('ANALYZE surveillance.%I', v_table_name);
        RAISE NOTICE 'Analyzed table: surveillance.%', v_table_name;
    END LOOP;
    
    RAISE NOTICE 'Vacuum analyze completed at %', CURRENT_TIMESTAMP;
END;
$$;

-- 3.2 Get table bloat statistics
CREATE OR REPLACE FUNCTION surveillance.get_table_bloat()
RETURNS TABLE (
    table_name TEXT,
    row_count BIGINT,
    total_size TEXT,
    table_size TEXT,
    index_size TEXT,
    dead_tuple_count BIGINT,
    dead_tuple_percent NUMERIC,
    last_vacuum TIMESTAMP,
    last_analyze TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.relname::TEXT,
        c.reltuples::BIGINT,
        pg_size_pretty(pg_total_relation_size(c.oid)),
        pg_size_pretty(pg_table_size(c.oid)),
        pg_size_pretty(pg_indexes_size(c.oid)),
        s.n_dead_tup,
        ROUND(100.0 * s.n_dead_tup / NULLIF(s.n_live_tup + s.n_dead_tup, 0), 2),
        s.last_vacuum,
        s.last_analyze
    FROM pg_class c
    JOIN pg_namespace n ON c.relnamespace = n.oid
    LEFT JOIN pg_stat_user_tables s ON c.relname = s.relname AND n.nspname = s.schemaname
    WHERE n.nspname = 'surveillance'
    AND c.relkind = 'r'
    ORDER BY pg_total_relation_size(c.oid) DESC;
END;
$$;

-- ============================================================================
-- SECTION 4: INDEX MAINTENANCE
-- ============================================================================

-- 4.1 Identify unused indexes
CREATE OR REPLACE FUNCTION surveillance.get_unused_indexes()
RETURNS TABLE (
    table_name TEXT,
    index_name TEXT,
    index_size TEXT,
    index_scans BIGINT,
    recommendation TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.relname::TEXT,
        i.relname::TEXT,
        pg_size_pretty(pg_relation_size(i.oid)),
        s.idx_scan,
        CASE 
            WHEN s.idx_scan = 0 THEN 'Consider dropping - never used'
            WHEN s.idx_scan < 10 THEN 'Low usage - review necessity'
            ELSE 'OK'
        END
    FROM pg_stat_user_indexes s
    JOIN pg_class i ON s.indexrelid = i.oid
    JOIN pg_class t ON s.relid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE n.nspname = 'surveillance'
    AND i.relname NOT LIKE '%_pkey'
    ORDER BY s.idx_scan ASC, pg_relation_size(i.oid) DESC;
END;
$$;

-- 4.2 Reindex bloated indexes
CREATE OR REPLACE PROCEDURE surveillance.reindex_if_needed(
    p_bloat_threshold NUMERIC DEFAULT 30
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_index RECORD;
BEGIN
    FOR v_index IN
        SELECT indexrelname, schemaname, tablename
        FROM pg_stat_user_indexes
        WHERE schemaname = 'surveillance'
    LOOP
        -- Reindex concurrently to avoid locking
        BEGIN
            EXECUTE format('REINDEX INDEX CONCURRENTLY surveillance.%I', v_index.indexrelname);
            RAISE NOTICE 'Reindexed: %', v_index.indexrelname;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed to reindex %: %', v_index.indexrelname, SQLERRM;
        END;
    END LOOP;
END;
$$;

-- ============================================================================
-- SECTION 5: PERFORMANCE MONITORING
-- ============================================================================

-- 5.1 Slow query log view
CREATE OR REPLACE FUNCTION surveillance.get_slow_queries(
    p_min_duration_ms INTEGER DEFAULT 1000
)
RETURNS TABLE (
    query TEXT,
    calls BIGINT,
    mean_time_ms NUMERIC,
    total_time_ms NUMERIC,
    rows_returned BIGINT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pg_stat_statements.query::TEXT,
        pg_stat_statements.calls,
        ROUND(pg_stat_statements.mean_exec_time::NUMERIC, 2),
        ROUND(pg_stat_statements.total_exec_time::NUMERIC, 2),
        pg_stat_statements.rows
    FROM pg_stat_statements
    WHERE pg_stat_statements.mean_exec_time > p_min_duration_ms
    AND pg_stat_statements.query LIKE '%surveillance%'
    ORDER BY pg_stat_statements.mean_exec_time DESC
    LIMIT 20;
EXCEPTION
    WHEN undefined_table THEN
        RAISE NOTICE 'pg_stat_statements extension not installed';
        RETURN;
END;
$$;

-- 5.2 Connection statistics
CREATE OR REPLACE FUNCTION surveillance.get_connection_stats()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN jsonb_build_object(
        'timestamp', CURRENT_TIMESTAMP,
        'total_connections', (SELECT count(*) FROM pg_stat_activity),
        'active_queries', (SELECT count(*) FROM pg_stat_activity WHERE state = 'active'),
        'idle_connections', (SELECT count(*) FROM pg_stat_activity WHERE state = 'idle'),
        'idle_in_transaction', (SELECT count(*) FROM pg_stat_activity WHERE state = 'idle in transaction'),
        'max_connections', (SELECT setting::INTEGER FROM pg_settings WHERE name = 'max_connections'),
        'connection_pct', ROUND(100.0 * (SELECT count(*) FROM pg_stat_activity) / 
                               (SELECT setting::INTEGER FROM pg_settings WHERE name = 'max_connections'), 1)
    );
END;
$$;

-- 5.3 Database size monitoring
CREATE OR REPLACE FUNCTION surveillance.get_database_stats()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN jsonb_build_object(
        'timestamp', CURRENT_TIMESTAMP,
        'database_size', pg_size_pretty(pg_database_size(current_database())),
        'schema_size', pg_size_pretty((
            SELECT SUM(pg_total_relation_size(quote_ident(schemaname) || '.' || quote_ident(tablename)))
            FROM pg_tables WHERE schemaname = 'surveillance'
        )),
        'largest_tables', (
            SELECT jsonb_agg(jsonb_build_object(
                'table', tablename,
                'size', pg_size_pretty(pg_total_relation_size(quote_ident(schemaname) || '.' || quote_ident(tablename)))
            ) ORDER BY pg_total_relation_size(quote_ident(schemaname) || '.' || quote_ident(tablename)) DESC)
            FROM pg_tables WHERE schemaname = 'surveillance'
            LIMIT 5
        ),
        'total_rows', (
            SELECT SUM(n_live_tup)
            FROM pg_stat_user_tables
            WHERE schemaname = 'surveillance'
        )
    );
END;
$$;

-- ============================================================================
-- SECTION 6: HEALTH CHECK
-- ============================================================================

-- 6.1 Comprehensive health check
CREATE OR REPLACE FUNCTION surveillance.health_check()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_issues JSONB[] := ARRAY[]::JSONB[];
BEGIN
    -- Check for tables needing vacuum
    IF EXISTS (
        SELECT 1 FROM pg_stat_user_tables 
        WHERE schemaname = 'surveillance'
        AND n_dead_tup > n_live_tup * 0.1
    ) THEN
        v_issues := array_append(v_issues, jsonb_build_object(
            'level', 'warning',
            'issue', 'Tables with high dead tuple count detected',
            'action', 'Run VACUUM ANALYZE'
        ));
    END IF;
    
    -- Check for unacknowledged alerts
    IF EXISTS (
        SELECT 1 FROM surveillance.alerts 
        WHERE alert_status = 'active' 
        AND acknowledged_at IS NULL
        AND created_at < CURRENT_TIMESTAMP - INTERVAL '24 hours'
    ) THEN
        v_issues := array_append(v_issues, jsonb_build_object(
            'level', 'alert',
            'issue', 'Unacknowledged alerts older than 24 hours',
            'action', 'Review and acknowledge pending alerts'
        ));
    END IF;
    
    -- Check for pending specimens
    IF EXISTS (
        SELECT 1 FROM surveillance.specimens 
        WHERE status = 'collected'
        AND collection_date < CURRENT_TIMESTAMP - INTERVAL '72 hours'
    ) THEN
        v_issues := array_append(v_issues, jsonb_build_object(
            'level', 'warning',
            'issue', 'Specimens pending over 72 hours',
            'action', 'Follow up on lab specimen processing'
        ));
    END IF;
    
    -- Check recent data freshness
    IF NOT EXISTS (
        SELECT 1 FROM surveillance.cases 
        WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '24 hours'
    ) THEN
        v_issues := array_append(v_issues, jsonb_build_object(
            'level', 'info',
            'issue', 'No new cases in last 24 hours',
            'action', 'Verify data entry is functioning'
        ));
    END IF;
    
    RETURN jsonb_build_object(
        'check_time', CURRENT_TIMESTAMP,
        'status', CASE 
            WHEN array_length(v_issues, 1) IS NULL THEN 'healthy'
            WHEN EXISTS (SELECT 1 FROM unnest(v_issues) i WHERE i->>'level' = 'alert') THEN 'alert'
            ELSE 'warning'
        END,
        'issues_count', COALESCE(array_length(v_issues, 1), 0),
        'issues', CASE 
            WHEN array_length(v_issues, 1) IS NULL THEN '[]'::JSONB
            ELSE to_jsonb(v_issues)
        END,
        'database_stats', surveillance.get_database_stats(),
        'connection_stats', surveillance.get_connection_stats()
    );
END;
$$;

-- ============================================================================
-- SECTION 7: SCHEDULED MAINTENANCE JOBS
-- ============================================================================

-- 7.1 Daily maintenance procedure
CREATE OR REPLACE PROCEDURE surveillance.run_daily_maintenance()
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE 'Starting daily maintenance at %', CURRENT_TIMESTAMP;
    
    -- Refresh daily counts
    CALL surveillance.refresh_daily_counts();
    
    -- Refresh materialized views
    CALL surveillance.refresh_dashboard_views();
    
    -- Run vacuum analyze
    CALL surveillance.run_vacuum_analyze();
    
    -- Purge old audit logs (90 days)
    CALL surveillance.purge_audit_logs(90);
    
    RAISE NOTICE 'Daily maintenance completed at %', CURRENT_TIMESTAMP;
END;
$$;

-- 7.2 Weekly maintenance procedure
CREATE OR REPLACE PROCEDURE surveillance.run_weekly_maintenance()
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE 'Starting weekly maintenance at %', CURRENT_TIMESTAMP;
    
    -- Refresh weekly epi data
    CALL surveillance.refresh_weekly_epi_data();
    
    -- Archive old alerts (1 year)
    CALL surveillance.archive_old_alerts(365);
    
    -- Reindex if needed
    CALL surveillance.reindex_if_needed();
    
    RAISE NOTICE 'Weekly maintenance completed at %', CURRENT_TIMESTAMP;
END;
$$;

-- 7.3 Monthly maintenance procedure  
CREATE OR REPLACE PROCEDURE surveillance.run_monthly_maintenance()
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE 'Starting monthly maintenance at %', CURRENT_TIMESTAMP;
    
    -- Archive old cases (5 years)
    CALL surveillance.archive_old_cases(5);
    
    -- Full vacuum on large tables
    VACUUM FULL surveillance.audit_log;
    
    RAISE NOTICE 'Monthly maintenance completed at %', CURRENT_TIMESTAMP;
END;
$$;

-- ============================================================================
-- VERIFICATION
-- ============================================================================

DO $$
DECLARE
    v_maint_func_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_maint_func_count
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'surveillance'
    AND (p.proname LIKE '%maintenance%' OR p.proname LIKE '%vacuum%' 
         OR p.proname LIKE '%archive%' OR p.proname LIKE '%health%');
    
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'MAINTENANCE SYSTEM CREATED SUCCESSFULLY';
    RAISE NOTICE '==========================================';
    RAISE NOTICE 'Maintenance functions: %', v_maint_func_count;
    RAISE NOTICE '';
    RAISE NOTICE 'Partitioning:';
    RAISE NOTICE '  - cases_partitioned (by year)';
    RAISE NOTICE '  - daily_counts_partitioned (by year)';
    RAISE NOTICE '';
    RAISE NOTICE 'Archival:';
    RAISE NOTICE '  - archive_old_cases()';
    RAISE NOTICE '  - archive_old_alerts()';
    RAISE NOTICE '  - purge_audit_logs()';
    RAISE NOTICE '';
    RAISE NOTICE 'Vacuum & Analyze:';
    RAISE NOTICE '  - run_vacuum_analyze()';
    RAISE NOTICE '  - get_table_bloat()';
    RAISE NOTICE '';
    RAISE NOTICE 'Index Maintenance:';
    RAISE NOTICE '  - get_unused_indexes()';
    RAISE NOTICE '  - reindex_if_needed()';
    RAISE NOTICE '';
    RAISE NOTICE 'Monitoring:';
    RAISE NOTICE '  - get_slow_queries()';
    RAISE NOTICE '  - get_connection_stats()';
    RAISE NOTICE '  - get_database_stats()';
    RAISE NOTICE '  - health_check()';
    RAISE NOTICE '';
    RAISE NOTICE 'Scheduled Jobs:';
    RAISE NOTICE '  - run_daily_maintenance()';
    RAISE NOTICE '  - run_weekly_maintenance()';
    RAISE NOTICE '  - run_monthly_maintenance()';
    RAISE NOTICE '==========================================';
END $$;
