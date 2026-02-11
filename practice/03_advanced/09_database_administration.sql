-- ============================================================================
-- SQL DATABASE ADMINISTRATION ESSENTIALS
-- Module 20: Backup, Recovery, and Maintenance
-- Goal: Keep your database healthy, safe, and performing well
-- ============================================================================

-- ============================================================================
-- SECTION 1: SERVER AND DATABASE INFORMATION
-- ============================================================================

-- Server information
SELECT VERSION();
SELECT @@version;
SHOW VARIABLES LIKE 'version%';

-- Server status
SHOW STATUS;
SHOW GLOBAL STATUS;

-- Server configuration
SHOW VARIABLES;
SHOW VARIABLES LIKE 'max_connections';
SHOW VARIABLES LIKE 'innodb%';

-- Database information
SHOW DATABASES;
SELECT DATABASE();  -- Current database

-- Database size
SELECT 
    table_schema AS database_name,
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM information_schema.tables
GROUP BY table_schema
ORDER BY size_mb DESC;

-- Table information
SHOW TABLES;
SHOW TABLE STATUS;
DESCRIBE table_name;
SHOW CREATE TABLE table_name;

-- Table sizes
SELECT 
    table_name,
    table_rows,
    ROUND(data_length / 1024 / 1024, 2) AS data_mb,
    ROUND(index_length / 1024 / 1024, 2) AS index_mb,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS total_mb
FROM information_schema.tables
WHERE table_schema = DATABASE()
ORDER BY total_mb DESC;

-- ============================================================================
-- SECTION 2: BACKUP STRATEGIES
-- ============================================================================

/*
BACKUP TYPES:

1. Logical Backup (mysqldump)
   - SQL statements to recreate data
   - Portable across versions
   - Slower for large databases

2. Physical Backup
   - Copy actual data files
   - Very fast
   - Version/platform specific

3. Point-in-Time Recovery
   - Binary log replay
   - Recover to specific moment
   - Continuous protection
*/

-- Check binary log status
SHOW MASTER STATUS;
SHOW BINARY LOGS;
SHOW VARIABLES LIKE 'log_bin';

-- Mysqldump commands (run from command line, not SQL)
/*
# Full database backup
mysqldump -u root -p shop_db > shop_db_backup.sql

# Specific tables
mysqldump -u root -p shop_db orders customers > orders_customers.sql

# All databases
mysqldump -u root -p --all-databases > all_databases.sql

# With routines (procedures, functions)
mysqldump -u root -p --routines shop_db > shop_db_with_routines.sql

# Compressed backup
mysqldump -u root -p shop_db | gzip > shop_db_backup.sql.gz

# With consistent snapshot (InnoDB)
mysqldump -u root -p --single-transaction shop_db > shop_db_consistent.sql

# Structure only
mysqldump -u root -p --no-data shop_db > shop_db_structure.sql

# Data only
mysqldump -u root -p --no-create-info shop_db > shop_db_data.sql
*/

-- Lock tables for MyISAM backup
FLUSH TABLES WITH READ LOCK;
-- Perform backup here
UNLOCK TABLES;

-- Create backup of table within database
CREATE TABLE orders_backup AS SELECT * FROM orders;
CREATE TABLE orders_backup_20240101 AS SELECT * FROM orders WHERE order_date < '2024-01-01';

-- ============================================================================
-- SECTION 3: RESTORE AND RECOVERY
-- ============================================================================

/*
# Restore from mysqldump (command line)
mysql -u root -p shop_db < shop_db_backup.sql

# Create database first if needed
mysql -u root -p -e "CREATE DATABASE shop_db"
mysql -u root -p shop_db < shop_db_backup.sql

# Restore compressed backup
gunzip < shop_db_backup.sql.gz | mysql -u root -p shop_db

# Point-in-time recovery
mysqlbinlog --start-datetime="2024-01-15 10:00:00" \
            --stop-datetime="2024-01-15 12:00:00" \
            mysql-bin.000001 | mysql -u root -p shop_db
*/

-- Restore from backup table
TRUNCATE TABLE orders;
INSERT INTO orders SELECT * FROM orders_backup;

-- Copy table structure
CREATE TABLE orders_new LIKE orders;
INSERT INTO orders_new SELECT * FROM orders;

-- ============================================================================
-- SECTION 4: TABLE MAINTENANCE
-- ============================================================================

-- Check table for errors
CHECK TABLE orders;
CHECK TABLE orders, customers, products;
CHECK TABLE orders EXTENDED;  -- More thorough check

-- Repair table (MyISAM)
REPAIR TABLE my_isam_table;
REPAIR TABLE my_isam_table QUICK;  -- Faster, less thorough

-- Optimize table (reclaim space, defragment)
OPTIMIZE TABLE orders;  -- For InnoDB, same as ALTER TABLE ... ENGINE=InnoDB

-- Analyze table (update index statistics)
ANALYZE TABLE orders;
ANALYZE TABLE orders, customers, products;

-- Combined maintenance
CHECK TABLE orders;
ANALYZE TABLE orders;
OPTIMIZE TABLE orders;

-- ============================================================================
-- SECTION 5: INDEX MAINTENANCE
-- ============================================================================

-- View all indexes
SHOW INDEX FROM orders;

-- View index usage (Performance Schema)
SELECT 
    object_schema,
    object_name,
    index_name,
    count_star AS times_used
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE object_schema = DATABASE()
ORDER BY times_used DESC;

-- Find unused indexes
SELECT 
    s.table_schema,
    s.table_name,
    s.index_name,
    s.column_name
FROM information_schema.statistics s
LEFT JOIN performance_schema.table_io_waits_summary_by_index_usage u
    ON s.table_schema = u.object_schema
    AND s.table_name = u.object_name
    AND s.index_name = u.index_name
WHERE u.count_star IS NULL OR u.count_star = 0
    AND s.table_schema = DATABASE();

-- Find duplicate indexes
SELECT 
    table_name,
    GROUP_CONCAT(index_name) AS duplicate_indexes,
    GROUP_CONCAT(column_name ORDER BY seq_in_index) AS columns
FROM information_schema.statistics
WHERE table_schema = DATABASE()
GROUP BY table_name, column_name
HAVING COUNT(DISTINCT index_name) > 1;

-- Rebuild index
ALTER TABLE orders DROP INDEX old_index, ADD INDEX new_index (column_name);

-- ============================================================================
-- SECTION 6: MONITORING QUERIES AND PERFORMANCE
-- ============================================================================

-- Current running queries
SHOW PROCESSLIST;
SHOW FULL PROCESSLIST;

-- Better process view
SELECT 
    id,
    user,
    host,
    db,
    command,
    time,
    state,
    LEFT(info, 100) AS query
FROM information_schema.processlist
WHERE command != 'Sleep'
ORDER BY time DESC;

-- Kill long-running query
KILL 12345;  -- Replace with process ID
KILL QUERY 12345;  -- Kill only the query, not connection

-- Query performance (Performance Schema)
SELECT 
    digest_text,
    count_star AS exec_count,
    ROUND(avg_timer_wait / 1000000000, 2) AS avg_ms,
    ROUND(sum_timer_wait / 1000000000, 2) AS total_ms,
    ROUND(sum_rows_examined / count_star) AS avg_rows_examined
FROM performance_schema.events_statements_summary_by_digest
WHERE schema_name = DATABASE()
ORDER BY sum_timer_wait DESC
LIMIT 10;

-- Table I/O statistics
SELECT 
    object_name AS table_name,
    count_read,
    count_write,
    count_fetch,
    count_insert,
    count_update,
    count_delete
FROM performance_schema.table_io_waits_summary_by_table
WHERE object_schema = DATABASE()
ORDER BY (count_read + count_write) DESC;

-- ============================================================================
-- SECTION 7: STORAGE ENGINE MANAGEMENT
-- ============================================================================

-- Show available storage engines
SHOW ENGINES;

-- Check table storage engine
SELECT 
    table_name,
    engine,
    table_rows,
    ROUND(data_length / 1024 / 1024, 2) AS data_mb
FROM information_schema.tables
WHERE table_schema = DATABASE();

-- Change storage engine
ALTER TABLE myisam_table ENGINE = InnoDB;

-- InnoDB status
SHOW ENGINE INNODB STATUS;

-- InnoDB buffer pool statistics
SHOW STATUS LIKE 'Innodb_buffer_pool%';

-- Calculate buffer pool hit ratio
SELECT 
    (1 - (
        (SELECT variable_value FROM performance_schema.global_status WHERE variable_name = 'Innodb_buffer_pool_reads') /
        (SELECT variable_value FROM performance_schema.global_status WHERE variable_name = 'Innodb_buffer_pool_read_requests')
    )) * 100 AS buffer_pool_hit_ratio;

-- ============================================================================
-- SECTION 8: ROUTINE MAINTENANCE PROCEDURES
-- ============================================================================

DELIMITER //

-- Procedure: Daily maintenance
CREATE PROCEDURE daily_maintenance()
BEGIN
    DECLARE v_table VARCHAR(100);
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    
    DECLARE table_cursor CURSOR FOR
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = DATABASE() AND engine = 'InnoDB';
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    
    -- Log start
    INSERT INTO maintenance_log (task, status, started_at)
    VALUES ('daily_maintenance', 'started', NOW());
    
    -- Analyze all tables
    OPEN table_cursor;
    table_loop: LOOP
        FETCH table_cursor INTO v_table;
        IF v_done THEN LEAVE table_loop; END IF;
        
        SET @sql = CONCAT('ANALYZE TABLE ', v_table);
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;
    END LOOP;
    CLOSE table_cursor;
    
    -- Log completion
    UPDATE maintenance_log 
    SET status = 'completed', completed_at = NOW()
    WHERE task = 'daily_maintenance' 
      AND completed_at IS NULL;
END //

-- Procedure: Archive old data
CREATE PROCEDURE archive_old_orders(IN p_days_old INT)
BEGIN
    DECLARE v_cutoff_date DATE;
    DECLARE v_rows_archived INT DEFAULT 0;
    
    SET v_cutoff_date = DATE_SUB(CURDATE(), INTERVAL p_days_old DAY);
    
    START TRANSACTION;
    
    -- Copy to archive
    INSERT INTO orders_archive
    SELECT * FROM orders WHERE order_date < v_cutoff_date;
    
    SET v_rows_archived = ROW_COUNT();
    
    -- Delete from main table
    DELETE FROM orders WHERE order_date < v_cutoff_date;
    
    COMMIT;
    
    -- Log
    INSERT INTO maintenance_log (task, status, details, started_at, completed_at)
    VALUES (
        'archive_old_orders', 
        'completed',
        CONCAT('Archived ', v_rows_archived, ' orders older than ', v_cutoff_date),
        NOW(),
        NOW()
    );
END //

-- Procedure: Purge old logs
CREATE PROCEDURE purge_old_logs(IN p_days_retention INT)
BEGIN
    DELETE FROM audit_log WHERE event_time < DATE_SUB(NOW(), INTERVAL p_days_retention DAY);
    DELETE FROM maintenance_log WHERE started_at < DATE_SUB(NOW(), INTERVAL p_days_retention DAY);
END //

DELIMITER ;

-- Create maintenance log table
CREATE TABLE maintenance_log (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    task VARCHAR(100),
    status VARCHAR(50),
    details TEXT,
    started_at TIMESTAMP,
    completed_at TIMESTAMP
);

-- ============================================================================
-- SECTION 9: SCHEDULED EVENTS
-- ============================================================================

-- Enable event scheduler
SET GLOBAL event_scheduler = ON;
SHOW VARIABLES LIKE 'event_scheduler';

-- Create scheduled maintenance
CREATE EVENT daily_maintenance_event
ON SCHEDULE EVERY 1 DAY
STARTS '2024-01-01 02:00:00'
DO CALL daily_maintenance();

-- Archive old orders weekly
CREATE EVENT weekly_archive_event
ON SCHEDULE EVERY 1 WEEK
STARTS '2024-01-07 03:00:00'
DO CALL archive_old_orders(365);

-- Purge logs monthly
CREATE EVENT monthly_log_purge
ON SCHEDULE EVERY 1 MONTH
STARTS '2024-02-01 04:00:00'
DO CALL purge_old_logs(90);

-- View events
SHOW EVENTS;

-- Alter event
ALTER EVENT daily_maintenance_event DISABLE;
ALTER EVENT daily_maintenance_event ENABLE;

-- Drop event
DROP EVENT IF EXISTS old_event;

-- ============================================================================
-- SECTION 10: HEALTH CHECK QUERIES
-- ============================================================================

-- Comprehensive health check
DELIMITER //

CREATE PROCEDURE health_check()
BEGIN
    -- Database size
    SELECT 'Database Size' AS check_type;
    SELECT 
        table_schema AS db_name,
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS size_mb
    FROM information_schema.tables
    WHERE table_schema = DATABASE();
    
    -- Table sizes
    SELECT 'Table Sizes (Top 10)' AS check_type;
    SELECT 
        table_name,
        table_rows,
        ROUND(data_length / 1024 / 1024, 2) AS data_mb,
        ROUND(index_length / 1024 / 1024, 2) AS index_mb
    FROM information_schema.tables
    WHERE table_schema = DATABASE()
    ORDER BY data_length DESC
    LIMIT 10;
    
    -- Connection status
    SELECT 'Connection Status' AS check_type;
    SELECT 
        (SELECT variable_value FROM performance_schema.global_status 
         WHERE variable_name = 'Threads_connected') AS current_connections,
        (SELECT variable_value FROM performance_schema.global_variables 
         WHERE variable_name = 'max_connections') AS max_connections;
    
    -- InnoDB buffer pool
    SELECT 'Buffer Pool Status' AS check_type;
    SELECT 
        ROUND((SELECT variable_value FROM performance_schema.global_status 
               WHERE variable_name = 'Innodb_buffer_pool_pages_data') * 16 / 1024, 2) AS data_cached_mb,
        ROUND((SELECT variable_value FROM performance_schema.global_variables 
               WHERE variable_name = 'innodb_buffer_pool_size') / 1024 / 1024, 2) AS pool_size_mb;
    
    -- Slow queries
    SELECT 'Slow Query Count' AS check_type;
    SELECT variable_value AS slow_queries
    FROM performance_schema.global_status
    WHERE variable_name = 'Slow_queries';
    
    -- Uptime
    SELECT 'Server Uptime' AS check_type;
    SELECT 
        variable_value AS uptime_seconds,
        CONCAT(
            FLOOR(variable_value / 86400), ' days ',
            FLOOR((variable_value % 86400) / 3600), ' hours'
        ) AS uptime_formatted
    FROM performance_schema.global_status
    WHERE variable_name = 'Uptime';
END //

DELIMITER ;

-- Run health check
CALL health_check();

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Backup and restore
a) Create a full backup script with compression
b) Create incremental backup using binary logs
c) Practice point-in-time recovery
d) Create backup verification procedure

EXERCISE 2: Table maintenance
a) Create maintenance procedure for all tables
b) Identify and fix table fragmentation
c) Rebuild indexes on large tables
d) Create statistics update schedule

EXERCISE 3: Monitoring
a) Create dashboard queries for key metrics
b) Set up slow query alerts
c) Monitor table growth over time
d) Track query performance trends

EXERCISE 4: Automation
a) Create daily maintenance event
b) Create weekly backup event
c) Create monthly archive event
d) Create alert procedure for issues

EXERCISE 5: Recovery scenarios
a) Recover from accidental DELETE
b) Recover from table corruption
c) Recover from disk failure (planning)
d) Test full disaster recovery process

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

