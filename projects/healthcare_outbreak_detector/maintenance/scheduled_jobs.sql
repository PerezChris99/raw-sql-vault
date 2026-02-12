-- ============================================================================
-- Maintenance: Scheduled Jobs
-- Purpose: Automated maintenance tasks for production
-- ============================================================================

SET search_path TO surveillance, public;

-- ============================================================================
-- MATERIALIZED VIEW REFRESH
-- Schedule: Dashboard every 15 min, hotspots hourly, trends nightly
-- ============================================================================

-- Refresh dashboard summary (call via pg_cron every 15 min)
CREATE OR REPLACE FUNCTION surveillance.job_refresh_dashboard()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY surveillance.mv_dashboard_summary;
    
    INSERT INTO surveillance.audit_log (table_name, action, new_data)
    VALUES ('mv_dashboard_summary', 'REFRESH', 
            jsonb_build_object('timestamp', CURRENT_TIMESTAMP));
END;
$$;

-- Refresh hotspots (call via pg_cron hourly)
CREATE OR REPLACE FUNCTION surveillance.job_refresh_hotspots()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY surveillance.mv_disease_hotspots;
    
    INSERT INTO surveillance.audit_log (table_name, action, new_data)
    VALUES ('mv_disease_hotspots', 'REFRESH', 
            jsonb_build_object('timestamp', CURRENT_TIMESTAMP));
END;
$$;

-- ============================================================================
-- DATA ARCHIVAL
-- Schedule: Monthly - archive cases older than 2 years
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.archive_old_cases(p_months_old INTEGER DEFAULT 24)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_archived_count INTEGER;
    v_cutoff_date DATE;
BEGIN
    v_cutoff_date := CURRENT_DATE - (p_months_old || ' months')::INTERVAL;
    
    -- Move old cases to archive table
    INSERT INTO surveillance.cases_archive 
    SELECT * FROM surveillance.cases 
    WHERE report_date < v_cutoff_date
      AND outcome IS NOT NULL;  -- Only archive closed cases
    
    GET DIAGNOSTICS v_archived_count = ROW_COUNT;
    
    -- Delete archived cases from main table
    DELETE FROM surveillance.cases 
    WHERE report_date < v_cutoff_date
      AND outcome IS NOT NULL;
    
    -- Log archival
    INSERT INTO surveillance.audit_log (table_name, action, new_data)
    VALUES ('cases', 'ARCHIVE', 
            jsonb_build_object(
                'archived_count', v_archived_count,
                'cutoff_date', v_cutoff_date,
                'executed_at', CURRENT_TIMESTAMP
            ));
    
    RETURN v_archived_count;
END;
$$;

-- ============================================================================
-- INDEX MAINTENANCE
-- Schedule: Weekly - rebuild bloated indexes
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.maintenance_reindex()
RETURNS TABLE(index_name TEXT, status TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_index RECORD;
BEGIN
    FOR v_index IN 
        SELECT schemaname, indexrelname
        FROM pg_catalog.pg_stat_user_indexes
        WHERE schemaname = 'surveillance'
    LOOP
        BEGIN
            EXECUTE format('REINDEX INDEX CONCURRENTLY %I.%I', 
                          v_index.schemaname, v_index.indexrelname);
            index_name := v_index.indexrelname;
            status := 'SUCCESS';
            RETURN NEXT;
        EXCEPTION WHEN OTHERS THEN
            index_name := v_index.indexrelname;
            status := 'FAILED: ' || SQLERRM;
            RETURN NEXT;
        END;
    END LOOP;
END;
$$;

-- ============================================================================
-- STATISTICS UPDATE
-- Schedule: Nightly - update table statistics
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.maintenance_analyze()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    ANALYZE surveillance.cases;
    ANALYZE surveillance.patients;
    ANALYZE surveillance.alerts;
    ANALYZE surveillance.specimens;
    ANALYZE surveillance.lab_results;
    ANALYZE surveillance.outbreaks;
    
    INSERT INTO surveillance.audit_log (table_name, action, new_data)
    VALUES ('ALL', 'ANALYZE', 
            jsonb_build_object('timestamp', CURRENT_TIMESTAMP));
END;
$$;

-- ============================================================================
-- PARTITION MAINTENANCE
-- Schedule: Monthly - create partitions for next month
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.create_monthly_partition(
    p_table_name TEXT,
    p_year INTEGER,
    p_month INTEGER
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_partition_name TEXT;
    v_start_date DATE;
    v_end_date DATE;
BEGIN
    v_partition_name := format('%s_y%sm%s', p_table_name, p_year, LPAD(p_month::TEXT, 2, '0'));
    v_start_date := make_date(p_year, p_month, 1);
    v_end_date := (v_start_date + INTERVAL '1 month')::DATE;
    
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS surveillance.%I PARTITION OF surveillance.%I 
         FOR VALUES FROM (%L) TO (%L)',
        v_partition_name, p_table_name, v_start_date, v_end_date
    );
    
    RETURN v_partition_name;
END;
$$;

-- ============================================================================
-- HEALTH CHECK
-- Purpose: System health monitoring
-- ============================================================================

CREATE OR REPLACE FUNCTION surveillance.health_check()
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'timestamp', CURRENT_TIMESTAMP,
        'database', current_database(),
        'schema_exists', EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'surveillance'),
        'table_counts', (
            SELECT jsonb_object_agg(table_name, row_count)
            FROM (
                SELECT 'cases' AS table_name, COUNT(*) AS row_count FROM surveillance.cases
                UNION ALL
                SELECT 'patients', COUNT(*) FROM surveillance.patients
                UNION ALL
                SELECT 'alerts', COUNT(*) FROM surveillance.alerts WHERE alert_status = 'active'
                UNION ALL
                SELECT 'outbreaks', COUNT(*) FROM surveillance.outbreaks WHERE status = 'active'
            ) counts
        ),
        'recent_activity', (
            SELECT jsonb_build_object(
                'cases_today', COUNT(*) FILTER (WHERE report_date = CURRENT_DATE),
                'cases_this_week', COUNT(*) FILTER (WHERE report_date >= CURRENT_DATE - 7)
            )
            FROM surveillance.cases
        ),
        'disk_usage_mb', (
            SELECT ROUND(pg_database_size(current_database()) / 1024.0 / 1024.0, 2)
        )
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION surveillance.job_refresh_dashboard IS 'Scheduled job: refresh dashboard every 15 minutes';
COMMENT ON FUNCTION surveillance.archive_old_cases IS 'Archive closed cases older than specified months';
COMMENT ON FUNCTION surveillance.health_check IS 'System health check returning JSON status';
