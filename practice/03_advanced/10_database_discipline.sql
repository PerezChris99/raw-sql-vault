-- ============================================================================
-- DATABASE DISCIPLINE: THE PROFESSIONAL'S GUIDE
-- Module 21: When to Touch (and NOT Touch) Production Systems
-- Goal: Master the unwritten rules that separate juniors from seniors
-- ============================================================================

/*
 ⚠️  THIS IS THE MOST IMPORTANT LESSON IN THIS VAULT! ⚠️

 The difference between a junior and senior developer is not just SQL knowledge.
 It's knowing WHEN and HOW to apply that knowledge without breaking things.

 This lesson will teach you the discipline that keeps systems running,
 prevents data loss, and keeps you employed.
*/

-- ============================================================================
-- SECTION 1: THE PRODUCTION MINDSET
-- ============================================================================

/*
BEFORE TOUCHING ANYTHING, ASK YOURSELF:

1. Is this a production environment?
   - Production = Real users, real money, real consequences
   - Development = Safe to experiment
   - Staging = Almost production, be careful

2. What could go wrong?
   - Data loss?
   - System downtime?
   - Performance degradation?
   - Broken application features?

3. Can I reverse this if it fails?
   - Can I ROLLBACK?
   - Do I have a backup?
   - Is there a recovery plan?

4. Who needs to know?
   - DBA team?
   - Development team?
   - Management?
   - Users (for scheduled maintenance)?

5. When is the right time?
   - During low traffic?
   - After a backup?
   - During a maintenance window?

GOLDEN RULE: If you're nervous about running it, that's your instinct telling
you to stop and get a second opinion.
*/

-- ============================================================================
-- SECTION 2: ENVIRONMENTS - KNOW WHERE YOU ARE
-- ============================================================================

/*
ENVIRONMENT TYPES:

┌─────────────────────────────────────────────────────────────────────────┐
│  DEVELOPMENT (DEV)                                                       │
├─────────────────────────────────────────────────────────────────────────┤
│  - Your local machine or shared dev server                              │
│  - SAFE to experiment                                                   │
│  - SAFE to break things                                                 │
│  - Data is fake/test data                                               │
│  - Can DROP tables, truncate, rebuild freely                            │
│  - Run whatever queries you want                                        │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  STAGING / QA / UAT                                                      │
├─────────────────────────────────────────────────────────────────────────┤
│  - Mirrors production setup                                             │
│  - May have production-like data (anonymized)                           │
│  - BE CAREFUL - changes might affect testers                            │
│  - Test migrations here BEFORE production                               │
│  - Get approval before major changes                                    │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  PRODUCTION (PROD)                                                       │
├─────────────────────────────────────────────────────────────────────────┤
│  - REAL DATA. REAL USERS. REAL MONEY.                                   │
│  - NEVER experiment here                                                │
│  - ALWAYS have a backup before changes                                  │
│  - ALWAYS test in staging first                                         │
│  - ALWAYS have a rollback plan                                          │
│  - ALWAYS get approval for schema changes                               │
│  - Run changes during maintenance windows                               │
│  - Mistakes here can end careers                                        │
└─────────────────────────────────────────────────────────────────────────┘

ALWAYS VERIFY YOUR ENVIRONMENT:
*/

-- Check which database you're connected to
SELECT DATABASE() AS current_database;
SELECT @@hostname AS server_name;
SHOW VARIABLES LIKE 'hostname';

-- Many companies use naming conventions:
-- shop_dev, shop_staging, shop_prod
-- Look for clues: Is there real data? Recent timestamps? Many records?

-- Count records to gauge if this is production
SELECT 
    (SELECT COUNT(*) FROM customers) AS customer_count,
    (SELECT COUNT(*) FROM orders) AS order_count,
    (SELECT MAX(created_at) FROM orders) AS latest_order;

-- ============================================================================
-- SECTION 3: WHEN TO TOUCH TABLES AND ROWS
-- ============================================================================

/*
████████╗ █████╗ ██████╗ ██╗     ███████╗███████╗
╚══██╔══╝██╔══██╗██╔══██╗██║     ██╔════╝██╔════╝
   ██║   ███████║██████╔╝██║     █████╗  ███████╗
   ██║   ██╔══██║██╔══██╗██║     ██╔══╝  ╚════██║
   ██║   ██║  ██║██████╔╝███████╗███████╗███████║
   ╚═╝   ╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝╚══════╝

TABLE-LEVEL OPERATIONS RISK MATRIX:
*/

-- ============================================================================
-- 3.1: SELECT OPERATIONS (Generally Safe)
-- ============================================================================

/*
✅ SAFE TO RUN ANYTIME:
- SELECT queries with proper LIMIT
- Read-only reporting queries
- Data lookups

⚠️ CAREFUL WITH:
- Large table scans (no WHERE clause)
- Complex JOINs on huge tables
- Queries without LIMIT on large result sets
- These can cause performance issues!
*/

-- ✅ Safe: Limited query
SELECT * FROM orders WHERE customer_id = 5 LIMIT 100;

-- ⚠️ Dangerous in production: Full table scan on huge table
-- SELECT * FROM orders; -- DON'T do this on millions of rows!

-- ✅ Safe: Specific lookup
SELECT customer_name, email FROM customers WHERE customer_id = 123;

-- ⚠️ Dangerous: Unoptimized query that locks tables
-- SELECT * FROM orders o 
-- JOIN order_items oi ON o.order_id = oi.order_id
-- JOIN products p ON oi.product_id = p.product_id;
-- Could lock tables for minutes on large datasets!

-- ALWAYS add LIMIT when exploring data:
SELECT * FROM large_table LIMIT 10;  -- Check structure first
SELECT COUNT(*) FROM large_table;    -- Know what you're dealing with

-- ============================================================================
-- 3.2: INSERT OPERATIONS
-- ============================================================================

/*
✅ WHEN IT'S OK TO INSERT:
- Normal application operations
- Loading test data in dev
- Bulk imports during maintenance windows
- After verifying data integrity

⚠️ WHEN TO BE CAREFUL:
- Bulk inserts (use batches, not one giant INSERT)
- Inserts that might violate constraints
- Inserts during peak hours

❌ NEVER INSERT:
- Without understanding the table's constraints and triggers
- Test data into production tables
- Data that hasn't been validated
*/

-- ✅ Safe: Single record insert
INSERT INTO customers (customer_name, email) VALUES ('Test User', 'test@email.com');

-- ⚠️ Bulk insert - do in batches, not millions at once!
-- Bad: INSERT INTO logs SELECT * FROM old_logs; (millions of rows)
-- Good: Insert in batches of 1000-10000

-- Batch insert pattern:
DELIMITER //
CREATE PROCEDURE batch_insert_safe()
BEGIN
    DECLARE batch_size INT DEFAULT 1000;
    DECLARE done INT DEFAULT 0;
    
    WHILE done = 0 DO
        INSERT INTO target_table
        SELECT * FROM source_table
        WHERE processed = 0
        LIMIT batch_size;
        
        SET done = ROW_COUNT() = 0;
        
        -- Brief pause to let system breathe
        DO SLEEP(0.1);
    END WHILE;
END //
DELIMITER ;

-- ============================================================================
-- 3.3: UPDATE OPERATIONS
-- ============================================================================

/*
██╗   ██╗██████╗ ██████╗  █████╗ ████████╗███████╗
██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝
██║   ██║██████╔╝██║  ██║███████║   ██║   █████╗  
██║   ██║██╔═══╝ ██║  ██║██╔══██║   ██║   ██╔══╝  
╚██████╔╝██║     ██████╔╝██║  ██║   ██║   ███████╗
 ╚═════╝ ╚═╝     ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝

⚠️ UPDATES ARE THE #1 CAUSE OF DATA DISASTERS!

THE UPDATE SAFETY CHECKLIST:
*/

-- ❌ NEVER run UPDATE without WHERE clause!
-- UPDATE customers SET status = 'inactive'; -- Affects ALL rows!

-- ✅ ALWAYS have a specific WHERE clause
UPDATE customers SET status = 'inactive' WHERE customer_id = 123;

-- BEFORE ANY UPDATE IN PRODUCTION:

-- Step 1: Write your WHERE clause as a SELECT first
SELECT customer_id, customer_name, status 
FROM customers 
WHERE customer_id = 123;

-- Step 2: Verify the SELECT returns ONLY the rows you want to change
-- If it returns 1 row, you'll update 1 row
-- If it returns 1000 rows, YOU'RE ABOUT TO CHANGE 1000 ROWS!

-- Step 3: BACKUP the rows you're about to change
CREATE TABLE customers_backup_20240115 AS
SELECT * FROM customers WHERE customer_id = 123;

-- Step 4: Run the UPDATE in a transaction
START TRANSACTION;
UPDATE customers SET status = 'inactive' WHERE customer_id = 123;
-- CHECK: Did it affect the expected number of rows?
-- If yes: COMMIT;
-- If no: ROLLBACK;

-- Step 5: Verify the change
SELECT * FROM customers WHERE customer_id = 123;

/*
THE "RUN AS SELECT FIRST" RULE:

Instead of:  UPDATE customers SET status = 'X' WHERE district = 'Kampala'

First run:   SELECT customer_id, status FROM customers WHERE district = 'Kampala'

See how many rows? Is that what you expected?
Only then run the UPDATE.
*/

-- ============================================================================
-- 3.4: DELETE OPERATIONS
-- ============================================================================

/*
██████╗ ███████╗██╗     ███████╗████████╗███████╗
██╔══██╗██╔════╝██║     ██╔════╝╚══██╔══╝██╔════╝
██║  ██║█████╗  ██║     █████╗     ██║   █████╗  
██║  ██║██╔══╝  ██║     ██╔══╝     ██║   ██╔══╝  
██████╔╝███████╗███████╗███████╗   ██║   ███████╗
╚═════╝ ╚══════╝╚══════╝╚══════╝   ╚═╝   ╚══════╝

🚨 DELETE IS PERMANENT! There is no undo button. 🚨

PRODUCTION DELETE RULES:
*/

-- ❌ NEVER EVER in production:
-- DELETE FROM customers; -- Deletes ALL customers!
-- TRUNCATE TABLE orders; -- Faster delete of ALL rows!
-- DROP TABLE products;   -- Table is GONE!

-- ✅ ALWAYS:
-- 1. Have a backup
-- 2. Use specific WHERE clause
-- 3. Run as SELECT first
-- 4. Use transaction
-- 5. Verify before commit

-- SAFE DELETE PATTERN:

-- Step 1: Identify what you're deleting
SELECT * FROM orders WHERE order_date < '2020-01-01' AND status = 'cancelled';
-- Returns 847 rows. Is that what you expected?

-- Step 2: Create backup
CREATE TABLE orders_deleted_backup AS
SELECT * FROM orders WHERE order_date < '2020-01-01' AND status = 'cancelled';

-- Step 3: Delete in transaction
START TRANSACTION;
DELETE FROM orders WHERE order_date < '2020-01-01' AND status = 'cancelled';
-- Query OK, 847 rows affected. Matches our SELECT? Yes!

-- Step 4: Verify
SELECT COUNT(*) FROM orders WHERE order_date < '2020-01-01' AND status = 'cancelled';
-- Should be 0

-- Step 5: If all good
COMMIT;
-- If something's wrong
-- ROLLBACK;

/*
SOFT DELETE PATTERN (Preferred in production):

Instead of deleting data, mark it as deleted.
This allows recovery and maintains audit trail.
*/

-- Add soft delete column
ALTER TABLE orders ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE orders ADD COLUMN deleted_at TIMESTAMP NULL;

-- "Delete" by marking
UPDATE orders 
SET is_deleted = TRUE, deleted_at = NOW() 
WHERE order_id = 12345;

-- Your application queries now filter:
SELECT * FROM orders WHERE is_deleted = FALSE;

-- Create view for convenience
CREATE VIEW active_orders AS
SELECT * FROM orders WHERE is_deleted = FALSE;

-- ============================================================================
-- SECTION 4: TABLE STRUCTURE CHANGES (DDL OPERATIONS)
-- ============================================================================

/*
⚠️ DDL = Data Definition Language (CREATE, ALTER, DROP)

DDL OPERATIONS CAN:
- Lock entire tables
- Cause application errors
- Break foreign key relationships
- Require application code changes
- Takes long time on large tables

BEFORE ANY DDL IN PRODUCTION, ASK:
1. Does the application depend on this structure?
2. Will this lock the table? For how long?
3. Do other tables reference this one?
4. Is there a maintenance window?
5. Has this been tested in staging?
6. Does the team know about this change?
*/

-- ============================================================================
-- 4.1: ADD COLUMN (Usually Safe-ish)
-- ============================================================================

/*
Adding a column is generally safer but still needs care:
- With DEFAULT: May need to update all existing rows (slow!)
- Without DEFAULT: NULL values, may break NOT NULL assumptions
- On large tables: Can take hours and lock the table
*/

-- ✅ Safe pattern: Add nullable column without default
ALTER TABLE customers ADD COLUMN loyalty_points INT NULL;
-- Fast, no data update needed

-- ⚠️ Slower: Add column with default
ALTER TABLE customers ADD COLUMN loyalty_points INT DEFAULT 0;
-- MySQL 8.0+ is instant, older versions update all rows!

-- ⚠️ Check table size first!
SELECT 
    table_name,
    table_rows,
    ROUND(data_length / 1024 / 1024, 2) AS data_mb
FROM information_schema.tables
WHERE table_name = 'customers';
-- 50 million rows? This ALTER could take hours!

-- ONLINE DDL (MySQL 5.6+): Allows reads during ALTER
ALTER TABLE customers ADD COLUMN new_col INT, ALGORITHM=INPLACE, LOCK=NONE;

-- ============================================================================
-- 4.2: MODIFY/CHANGE COLUMN (Dangerous!)
-- ============================================================================

/*
CHANGING COLUMN TYPES CAN:
- Truncate data (longer string to shorter)
- Lose precision (DECIMAL to INT)
- Fail entirely (incompatible types)
- Lock tables for long time
- Break application code

❌ Never do this without extensive testing!
*/

-- ⚠️ Dangerous: Changing data type
-- ALTER TABLE products MODIFY price INT; -- Loses decimal places!

-- ✅ Safe pattern: Create new column, migrate, then drop old
-- Step 1: Add new column
ALTER TABLE products ADD COLUMN price_new DECIMAL(15,2);

-- Step 2: Copy data
UPDATE products SET price_new = price;

-- Step 3: Verify data copied correctly
SELECT COUNT(*) FROM products WHERE price != price_new;

-- Step 4: Drop old column (during maintenance window)
ALTER TABLE products DROP COLUMN price;

-- Step 5: Rename new column
ALTER TABLE products CHANGE price_new price DECIMAL(15,2);

-- ============================================================================
-- 4.3: DROP COLUMN (Irreversible!)
-- ============================================================================

/*
❌ DROPPING A COLUMN DESTROYS DATA FOREVER!

BEFORE DROPPING A COLUMN:
1. Confirm no application code uses it
2. Confirm no reports depend on it
3. Backup the column data
4. Have team approval
*/

-- Step 1: Find all references (in application code, stored procedures, views)
-- grep -r "column_name" ./src/
-- Search your codebase!

-- Step 2: Check views that use this column
SELECT 
    table_name AS view_name,
    view_definition
FROM information_schema.views
WHERE table_schema = DATABASE()
AND view_definition LIKE '%column_name%';

-- Step 3: Check stored procedures
SELECT 
    routine_name,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = DATABASE()
AND routine_definition LIKE '%column_name%';

-- Step 4: Backup the column
CREATE TABLE customers_old_column_backup AS
SELECT customer_id, old_column_name FROM customers;

-- Step 5: Drop (in maintenance window, with approval)
ALTER TABLE customers DROP COLUMN old_column_name;

-- ============================================================================
-- 4.4: DROP TABLE (Point of No Return!)
-- ============================================================================

/*
🚨 DROP TABLE = TABLE IS GONE FOREVER 🚨

NEVER DROP A TABLE IN PRODUCTION UNLESS:
1. You have a complete backup
2. The table is confirmed unused
3. You have manager/team approval
4. You're in a maintenance window
5. You have a recovery plan ready

BETTER ALTERNATIVE: Rename instead of drop
*/

-- ✅ Instead of dropping, rename and keep for a while
RENAME TABLE old_table TO old_table_deprecated_20240115;

-- After 30-90 days with no issues, then drop
DROP TABLE old_table_deprecated_20240115;

-- ============================================================================
-- SECTION 5: MIGRATIONS - THE PROFESSIONAL WAY
-- ============================================================================

/*
██╗  ██╗██╗ ██████╗ ██████╗  █████╗ ████████╗██╗ ██████╗ ███╗   ██╗███████╗
███╗ ███║██║██╔════╝ ██╔══██╗██╔══██╗╚══██╔══╝██║██╔═══██╗████╗  ██║██╔════╝
████████║██║██║  ███╗██████╔╝███████║   ██║   ██║██║   ██║██╔██╗ ██║███████╗
██╔═██╔═╝██║██║   ██║██╔══██╗██╔══██║   ██║   ██║██║   ██║██║╚██╗██║╚════██║
██║  ██║ ██║╚██████╔╝██║  ██║██║  ██║   ██║   ██║╚██████╔╝██║ ╚████║███████║
╚═╝  ╚═╝ ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚══════╝

WHAT ARE MIGRATIONS?
Controlled, versioned database schema changes.
*/

-- ============================================================================
-- 5.1: When to Create a Migration
-- ============================================================================

/*
✅ CREATE A MIGRATION WHEN:
- Adding a new table
- Adding new columns
- Changing column types
- Adding/removing indexes
- Adding/removing constraints
- Any DDL operation

❌ DON'T CREATE A MIGRATION FOR:
- One-time data fixes (use data scripts)
- Temporary tables
- Development-only changes
- Debugging/testing
*/

-- Example migration file structure (conceptual):
/*
-- Migration: 20240115_001_add_customer_loyalty
-- Author: Chris Perez
-- Description: Add loyalty program columns to customers table
-- Rollback: See rollback section below

-- UP (Apply migration)
ALTER TABLE customers ADD COLUMN loyalty_tier VARCHAR(20) DEFAULT 'bronze';
ALTER TABLE customers ADD COLUMN loyalty_points INT DEFAULT 0;
CREATE INDEX idx_loyalty_tier ON customers(loyalty_tier);

-- DOWN (Rollback migration)
DROP INDEX idx_loyalty_tier ON customers;
ALTER TABLE customers DROP COLUMN loyalty_points;
ALTER TABLE customers DROP COLUMN loyalty_tier;
*/

-- ============================================================================
-- 5.2: Migration Best Practices
-- ============================================================================

/*
1. ONE CHANGE PER MIGRATION
   Bad:  Add 5 columns + 3 indexes + 2 foreign keys in one migration
   Good: Separate migration for each logical change

2. ALWAYS HAVE A ROLLBACK PLAN
   Every UP should have a corresponding DOWN

3. TEST MIGRATIONS ON A COPY OF PRODUCTION DATA
   Staging with production-like data catches issues

4. MAKE MIGRATIONS IDEMPOTENT WHEN POSSIBLE
   Running twice shouldn't break anything

5. NEVER MODIFY A DEPLOYED MIGRATION
   Create a new migration to fix issues

6. COORDINATE WITH TEAM
   Don't surprise other developers
*/

-- Idempotent migration example:
-- Check if column exists before adding
SET @column_exists = (
    SELECT COUNT(*) FROM information_schema.columns 
    WHERE table_schema = DATABASE() 
    AND table_name = 'customers' 
    AND column_name = 'loyalty_points'
);

SET @sql = IF(@column_exists = 0, 
    'ALTER TABLE customers ADD COLUMN loyalty_points INT DEFAULT 0',
    'SELECT "Column already exists"'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ============================================================================
-- 5.3: When NOT to Run Migrations
-- ============================================================================

/*
❌ DO NOT RUN MIGRATIONS:
- During peak business hours
- Without a backup
- Without testing in staging
- When you're unsure of the impact
- When there's no rollback plan
- When the database is under heavy load
- When you're tired or rushed
- On Friday afternoon (never deploy on Fridays!)

✅ BEST TIME FOR MIGRATIONS:
- During maintenance windows
- Early morning (low traffic)
- After a fresh backup
- When DBA/team is available
- When you've tested thoroughly
*/

-- ============================================================================
-- SECTION 6: WHAT CAN CRASH A SYSTEM
-- ============================================================================

/*
YOUR SYSTEM CAN CRASH WHEN:

1. TABLE LOCKS DURING TRANSACTIONS
   - Long-running transactions holding locks
   - DDL operations locking large tables
   - Deadlocks between concurrent operations
*/

-- This can lock the entire orders table for hours:
-- ALTER TABLE orders ADD COLUMN temp_col VARCHAR(100);
-- If orders has 50 million rows, this takes time AND locks the table!

/*
2. FOREIGN KEY CASCADE DISASTERS
*/

-- This can delete half your database!
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) 
        ON DELETE CASCADE  -- Deleting a customer deletes ALL their orders!
);

-- Accidental customer deletion:
-- DELETE FROM customers WHERE customer_id = 1;
-- This now deletes hundreds of orders too!

/*
3. UNFILTERED UPDATES/DELETES
*/

-- Classic disasters:
-- UPDATE accounts SET balance = 0;  -- All accounts now have 0 balance!
-- DELETE FROM orders;               -- All orders gone!

/*
4. RESOURCE EXHAUSTION
*/

-- Query that crashes due to memory:
-- SELECT * FROM massive_table t1 
-- CROSS JOIN massive_table t2;  -- Cartesian product = billions of rows!

-- Transaction that never commits (holds locks forever):
-- START TRANSACTION;
-- UPDATE accounts SET balance = balance + 100 WHERE account_id = 1;
-- ... developer forgets to COMMIT and goes home ...
-- All other operations on this row are now blocked!

/*
5. INDEX OPERATIONS ON LARGE TABLES
*/

-- Creating index on 100 million row table:
-- CREATE INDEX idx_name ON huge_table(column);
-- This can lock the table for hours!

/*
6. STORED PROCEDURE INFINITE LOOPS
*/

DELIMITER //
CREATE PROCEDURE disaster_loop()
BEGIN
    DECLARE i INT DEFAULT 0;
    WHILE TRUE DO  -- No exit condition!
        INSERT INTO logs (message) VALUES ('This never stops');
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

-- ============================================================================
-- SECTION 7: THE PERMISSION MODEL
-- ============================================================================

/*
WHO SHOULD HAVE WHAT ACCESS?

┌─────────────────────────────────────────────────────────────────────────┐
│  ROLE             │  PERMISSIONS                                        │
├─────────────────────────────────────────────────────────────────────────┤
│  Application      │  SELECT, INSERT, UPDATE, DELETE on specific tables  │
│  (Service Account)│  EXECUTE on allowed procedures                      │
│                   │  NO DDL permissions!                                 │
├─────────────────────────────────────────────────────────────────────────┤
│  Developer        │  Same as Application                                │
│  (Production)     │  Read-only preferred                                │
│                   │  NO DDL permissions!                                │
├─────────────────────────────────────────────────────────────────────────┤
│  Developer        │  ALL PRIVILEGES                                     │
│  (Development)    │  Can experiment freely                              │
├─────────────────────────────────────────────────────────────────────────┤
│  DBA / DevOps     │  ALL PRIVILEGES (production)                        │
│                   │  Runs migrations                                    │
│                   │  Handles emergencies                                │
├─────────────────────────────────────────────────────────────────────────┤
│  Read-only User   │  SELECT only                                        │
│  (Analysts)       │  Cannot modify anything                             │
└─────────────────────────────────────────────────────────────────────────┘
*/

-- Create appropriate roles
CREATE ROLE 'app_role', 'readonly_role', 'admin_role';

-- Application role: No DDL
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_db.* TO 'app_role';

-- Read-only role
GRANT SELECT ON shop_db.* TO 'readonly_role';

-- Admin role (use sparingly!)
GRANT ALL PRIVILEGES ON shop_db.* TO 'admin_role';

-- ============================================================================
-- SECTION 8: THE CHANGE MANAGEMENT PROCESS
-- ============================================================================

/*
PROFESSIONAL CHANGE MANAGEMENT:

1. WRITE THE CHANGE
   - Create migration file
   - Include rollback steps
   - Document the purpose

2. TEST LOCALLY
   - Run on your development database
   - Verify it works
   - Test the rollback

3. CODE REVIEW
   - Have another developer review
   - Check for obvious issues
   - Ensure rollback works

4. TEST IN STAGING
   - Apply to staging environment
   - Run application tests
   - Verify with real-like data

5. SCHEDULE PRODUCTION CHANGE
   - Create change request
   - Get approval from lead/manager
   - Schedule maintenance window

6. BACKUP BEFORE CHANGE
   - Full backup of affected tables
   - Point-in-time recovery enabled

7. APPLY TO PRODUCTION
   - Run the migration
   - Monitor for errors
   - Verify application works

8. VERIFY AND MONITOR
   - Check logs for errors
   - Monitor performance
   - Be ready to rollback

9. DOCUMENT
   - Record what was changed
   - Update any documentation
   - Close the change request
*/

-- ============================================================================
-- SECTION 9: EMERGENCY PROCEDURES
-- ============================================================================

/*
WHEN THINGS GO WRONG:

1. DON'T PANIC
   - Stay calm
   - Don't make it worse with hasty "fixes"

2. STOP THE BLEEDING
   - If a bad UPDATE is running, kill it
   - If application is crashing, take it offline

3. ASSESS THE DAMAGE
   - What data was affected?
   - How many rows?
   - Can we identify what changed?
*/

-- Find currently running dangerous queries
SELECT 
    id, 
    user, 
    time, 
    state,
    LEFT(info, 100) AS query
FROM information_schema.processlist
WHERE command != 'Sleep'
AND (info LIKE 'UPDATE%' OR info LIKE 'DELETE%' OR info LIKE 'ALTER%')
ORDER BY time DESC;

-- Kill a dangerous query
-- KILL 12345;  -- Process ID from above

-- Check what rows were recently modified
-- (If you have audit logging or triggers)
SELECT * FROM audit_log 
WHERE action_time > NOW() - INTERVAL 1 HOUR
ORDER BY action_time DESC;

/*
4. RESTORE FROM BACKUP
   - Use the backup you made before the change
   - Or restore specific rows from backup table
*/

-- Restore from backup table
INSERT INTO customers 
SELECT * FROM customers_backup_20240115 
WHERE customer_id IN (1, 2, 3);  -- Affected IDs

/*
5. COMMUNICATE
   - Tell the team what happened
   - Update stakeholders on impact
   - Estimate time to fix

6. ROOT CAUSE ANALYSIS
   - Why did this happen?
   - How do we prevent it next time?
   - Update procedures/documentation
*/

-- ============================================================================
-- SECTION 10: THE PROFESSIONAL'S CHECKLIST
-- ============================================================================

/*
BEFORE ANY PRODUCTION CHANGE:

□ Do I understand what this change does?
□ Have I tested this in development?
□ Have I tested this in staging?
□ Is there a backup?
□ Do I have a rollback plan?
□ Is this approved by the team/lead?
□ Is this during a maintenance window?
□ Are the right people available if something goes wrong?
□ Have I checked how many rows will be affected?
□ Have I verified I'm on the right database/server?

IF ANY ANSWER IS "NO" - STOP AND ADDRESS IT FIRST!

AFTER THE CHANGE:

□ Did the expected number of rows change?
□ Is the application working?
□ Are there any errors in the logs?
□ Has anyone reported issues?
□ Is performance normal?
□ Did I document what I did?
*/

-- ============================================================================
-- SUMMARY: THE GOLDEN RULES
-- ============================================================================

/*
🏆 THE 10 GOLDEN RULES OF DATABASE WORK:

1. ALWAYS KNOW YOUR ENVIRONMENT
   Production is sacred. Treat it with respect.

2. NEVER UPDATE/DELETE WITHOUT WHERE
   Run as SELECT first. Always.

3. ALWAYS HAVE A BACKUP
   Before any change, backup what you're touching.

4. ALWAYS HAVE A ROLLBACK PLAN
   Know how to undo what you're about to do.

5. TEST IN STAGING FIRST
   Never experiment in production.

6. USE TRANSACTIONS
   Wrap changes in transactions. COMMIT only when verified.

7. LIMIT YOUR IMPACT
   Change the minimum necessary. Small changes = small risks.

8. COMMUNICATE
   Inform the team before major changes.

9. TAKE YOUR TIME
   Rushing causes mistakes. If you're nervous, slow down.

10. LEARN FROM MISTAKES
    Everyone makes mistakes. Document them. Don't repeat them.

================================================================================
"With great SQL power comes great responsibility."

You now have the knowledge. Use it wisely.
================================================================================
*/

-- ============================================================================
-- PRACTICE SCENARIOS
-- ============================================================================

/*
EXERCISE 1: Risk Assessment
For each operation, rate the risk (Low/Medium/High) and explain why:

a) SELECT * FROM customers WHERE email = 'test@test.com'
b) UPDATE customers SET email = 'new@test.com' WHERE customer_id = 123
c) UPDATE customers SET status = 'active'
d) DELETE FROM orders WHERE order_date < '2020-01-01'
e) ALTER TABLE customers ADD COLUMN temp INT
f) DROP TABLE customer_backup

EXERCISE 2: Fix the Danger
Rewrite these dangerous operations to be safe:

a) DELETE FROM orders WHERE status = 'cancelled'
b) UPDATE products SET price = price * 1.1
c) ALTER TABLE huge_table ADD INDEX idx_name (column_name)
d) DROP COLUMN old_data FROM transactions

EXERCISE 3: Create a Change Plan
Write a complete change plan for:
"Add a 'loyalty_points' column to the customers table in production"

Include:
- Pre-change checklist
- The actual SQL
- Rollback procedure
- Post-change verification
- Communication plan

EXERCISE 4: Incident Response
You accidentally run: UPDATE accounts SET balance = 0 WHERE status = 'active'
This affected 50,000 accounts.

Write your incident response plan:
- Immediate actions
- Assessment queries
- Recovery steps
- Communication template
- Prevention measures
*/

-- ============================================================================
-- END OF DATABASE DISCIPLINE MODULE
-- ============================================================================

/*
This lesson was written to help you avoid the mistakes that many developers
make early in their careers. The knowledge here comes from real-world
incidents and hard-learned lessons.

Remember: The best database change is the one you didn't need to make.
The second best is the one you made carefully and successfully rolled back
when something went wrong.

Stay safe out there! 🛡️
*/

