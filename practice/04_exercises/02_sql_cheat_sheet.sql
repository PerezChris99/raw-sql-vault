-- ============================================================================
-- SQL MASTER CHEAT SHEET
-- Quick Reference for All SQL Concepts
-- Keep this handy for daily use!
-- ============================================================================

-- ============================================================================
-- SECTION 1: BASIC QUERIES
-- ============================================================================

-- SELECT basics
SELECT * FROM table_name;                          -- All columns
SELECT col1, col2 FROM table_name;                 -- Specific columns
SELECT DISTINCT column FROM table_name;            -- Unique values
SELECT col AS alias_name FROM table_name;          -- Column alias

-- Filtering
WHERE col = 'value'                                -- Equals
WHERE col != 'value'                               -- Not equals (also <>)
WHERE col > 100                                    -- Greater than
WHERE col >= 100                                   -- Greater than or equal
WHERE col < 100                                    -- Less than
WHERE col <= 100                                   -- Less than or equal
WHERE col BETWEEN 10 AND 20                        -- Range (inclusive)
WHERE col IN ('a', 'b', 'c')                       -- In list
WHERE col NOT IN ('x', 'y')                        -- Not in list
WHERE col LIKE 'pattern%'                          -- Pattern match (% = any chars)
WHERE col LIKE '_attern'                           -- Single char wildcard
WHERE col IS NULL                                  -- Null check
WHERE col IS NOT NULL                              -- Not null check
WHERE cond1 AND cond2                              -- Both conditions
WHERE cond1 OR cond2                               -- Either condition
WHERE NOT condition                                -- Negate condition

-- Sorting and limiting
ORDER BY col ASC                                   -- Ascending (default)
ORDER BY col DESC                                  -- Descending
ORDER BY col1, col2 DESC                           -- Multiple columns
LIMIT 10                                           -- First 10 rows
LIMIT 10 OFFSET 20                                 -- Skip 20, get 10

-- ============================================================================
-- SECTION 2: JOINS
-- ============================================================================

-- INNER JOIN (matching rows only)
SELECT * FROM t1 
INNER JOIN t2 ON t1.id = t2.t1_id;

-- LEFT JOIN (all from left, matching from right)
SELECT * FROM t1 
LEFT JOIN t2 ON t1.id = t2.t1_id;

-- RIGHT JOIN (all from right, matching from left)
SELECT * FROM t1 
RIGHT JOIN t2 ON t1.id = t2.t1_id;

-- FULL OUTER JOIN (all from both) - MySQL workaround
SELECT * FROM t1 LEFT JOIN t2 ON t1.id = t2.t1_id
UNION
SELECT * FROM t1 RIGHT JOIN t2 ON t1.id = t2.t1_id;

-- CROSS JOIN (cartesian product)
SELECT * FROM t1 CROSS JOIN t2;

-- Self JOIN
SELECT e.name, m.name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id;

-- ============================================================================
-- SECTION 3: AGGREGATION
-- ============================================================================

-- Aggregate functions
COUNT(*)                                           -- Count all rows
COUNT(column)                                      -- Count non-null
COUNT(DISTINCT column)                             -- Count unique
SUM(column)                                        -- Sum values
AVG(column)                                        -- Average
MAX(column)                                        -- Maximum
MIN(column)                                        -- Minimum
GROUP_CONCAT(column)                               -- Concatenate values (MySQL)

-- GROUP BY
SELECT category, COUNT(*), SUM(amount)
FROM orders
GROUP BY category;

-- HAVING (filter groups)
SELECT category, COUNT(*) AS cnt
FROM orders
GROUP BY category
HAVING cnt > 5;

-- GROUP BY with ROLLUP (subtotals)
SELECT category, product, SUM(amount)
FROM sales
GROUP BY category, product WITH ROLLUP;

-- ============================================================================
-- SECTION 4: SUBQUERIES
-- ============================================================================

-- Scalar subquery (returns one value)
SELECT *, (SELECT AVG(price) FROM products) AS avg_price FROM products;

-- Subquery in WHERE
SELECT * FROM products WHERE price > (SELECT AVG(price) FROM products);
SELECT * FROM customers WHERE id IN (SELECT customer_id FROM orders);
SELECT * FROM products WHERE id NOT IN (SELECT product_id FROM order_items);

-- EXISTS
SELECT * FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.id);

-- Correlated subquery
SELECT p.*, 
    (SELECT COUNT(*) FROM order_items oi WHERE oi.product_id = p.id) AS times_ordered
FROM products p;

-- ============================================================================
-- SECTION 5: COMMON TABLE EXPRESSIONS (CTEs)
-- ============================================================================

-- Basic CTE
WITH cte_name AS (
    SELECT column1, column2 FROM table_name WHERE condition
)
SELECT * FROM cte_name;

-- Multiple CTEs
WITH 
    cte1 AS (SELECT * FROM table1),
    cte2 AS (SELECT * FROM table2)
SELECT * FROM cte1 JOIN cte2 ON cte1.id = cte2.id;

-- Recursive CTE
WITH RECURSIVE cte AS (
    -- Anchor
    SELECT id, name, parent_id, 0 AS level FROM categories WHERE parent_id IS NULL
    UNION ALL
    -- Recursive
    SELECT c.id, c.name, c.parent_id, cte.level + 1
    FROM categories c JOIN cte ON c.parent_id = cte.id
)
SELECT * FROM cte;

-- ============================================================================
-- SECTION 6: WINDOW FUNCTIONS
-- ============================================================================

-- Ranking
ROW_NUMBER() OVER (ORDER BY col)                   -- Unique sequential
RANK() OVER (ORDER BY col)                         -- Same rank for ties, gaps
DENSE_RANK() OVER (ORDER BY col)                   -- Same rank for ties, no gaps
NTILE(4) OVER (ORDER BY col)                       -- Divide into N buckets

-- Partition
ROW_NUMBER() OVER (PARTITION BY category ORDER BY sales DESC)

-- Analytics
LAG(col, 1) OVER (ORDER BY date)                   -- Previous row value
LEAD(col, 1) OVER (ORDER BY date)                  -- Next row value
FIRST_VALUE(col) OVER (ORDER BY date)              -- First value in window
LAST_VALUE(col) OVER (ORDER BY date)               -- Last value in window

-- Aggregates as window functions
SUM(amount) OVER (ORDER BY date)                   -- Running total
AVG(amount) OVER (PARTITION BY category)           -- Average in category

-- Window frame
SUM(col) OVER (ORDER BY date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)
SUM(col) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)

-- ============================================================================
-- SECTION 7: STRING FUNCTIONS
-- ============================================================================

CONCAT('Hello', ' ', 'World')                      -- Concatenate
CONCAT_WS(',', 'a', 'b', 'c')                      -- Concat with separator
LENGTH('string')                                   -- Character count
CHAR_LENGTH('string')                              -- Character count
UPPER('text')                                      -- Uppercase
LOWER('TEXT')                                      -- Lowercase
TRIM('  text  ')                                   -- Remove whitespace
LTRIM('  text')                                    -- Left trim
RTRIM('text  ')                                    -- Right trim
SUBSTRING('hello', 2, 3)                           -- Extract 'ell'
LEFT('hello', 2)                                   -- 'he'
RIGHT('hello', 2)                                  -- 'lo'
REPLACE('hello', 'l', 'L')                         -- 'heLLo'
REVERSE('hello')                                   -- 'olleh'
LOCATE('l', 'hello')                               -- Position (1-based)
INSTR('hello', 'l')                                -- Same as LOCATE
SUBSTRING_INDEX('a.b.c', '.', 2)                   -- 'a.b'
LPAD('5', 3, '0')                                  -- '005'
RPAD('5', 3, '0')                                  -- '500'

-- ============================================================================
-- SECTION 8: DATE/TIME FUNCTIONS
-- ============================================================================

-- Current date/time
NOW()                                              -- Current datetime
CURDATE()                                          -- Current date
CURTIME()                                          -- Current time
CURRENT_TIMESTAMP                                  -- Same as NOW()

-- Extract parts
YEAR(date)
MONTH(date)
DAY(date)
HOUR(datetime)
MINUTE(datetime)
SECOND(datetime)
DAYOFWEEK(date)                                    -- 1=Sunday, 7=Saturday
DAYOFMONTH(date)
DAYOFYEAR(date)
WEEKOFYEAR(date)
QUARTER(date)

-- Date arithmetic
DATE_ADD(date, INTERVAL 1 DAY)
DATE_SUB(date, INTERVAL 1 MONTH)
DATEDIFF(date1, date2)                             -- Days between
TIMESTAMPDIFF(MONTH, date1, date2)                 -- Units between

-- Formatting
DATE_FORMAT(date, '%Y-%m-%d')                      -- 2024-01-15
DATE_FORMAT(date, '%d/%m/%Y')                      -- 15/01/2024
DATE_FORMAT(date, '%W, %M %d, %Y')                 -- Monday, January 15, 2024
STR_TO_DATE('15-01-2024', '%d-%m-%Y')              -- Parse string to date

-- ============================================================================
-- SECTION 9: CONDITIONAL LOGIC
-- ============================================================================

-- CASE expression
CASE 
    WHEN condition1 THEN result1
    WHEN condition2 THEN result2
    ELSE default_result
END

-- Simple CASE
CASE column
    WHEN 'value1' THEN 'result1'
    WHEN 'value2' THEN 'result2'
    ELSE 'default'
END

-- IF function (MySQL)
IF(condition, true_value, false_value)

-- NULL handling
COALESCE(val1, val2, val3)                         -- First non-null
IFNULL(value, default)                             -- MySQL: default if null
NULLIF(val1, val2)                                 -- NULL if equal

-- ============================================================================
-- SECTION 10: DATA MODIFICATION
-- ============================================================================

-- INSERT
INSERT INTO table (col1, col2) VALUES ('val1', 'val2');
INSERT INTO table (col1, col2) VALUES ('a', 1), ('b', 2), ('c', 3);
INSERT INTO table SELECT * FROM other_table WHERE condition;

-- UPDATE
UPDATE table SET col1 = 'new_value' WHERE condition;
UPDATE table SET col1 = 'val1', col2 = 'val2' WHERE condition;

-- DELETE
DELETE FROM table WHERE condition;
TRUNCATE TABLE table_name;                         -- Fast delete all

-- UPSERT (MySQL)
INSERT INTO table (id, name) VALUES (1, 'new')
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- ============================================================================
-- SECTION 11: TABLE OPERATIONS
-- ============================================================================

-- CREATE TABLE
CREATE TABLE table_name (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    price DECIMAL(10, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

-- ALTER TABLE
ALTER TABLE t ADD COLUMN new_col VARCHAR(50);
ALTER TABLE t DROP COLUMN old_col;
ALTER TABLE t MODIFY COLUMN col VARCHAR(100);
ALTER TABLE t CHANGE old_name new_name VARCHAR(50);
ALTER TABLE t ADD INDEX idx_name (column);
ALTER TABLE t ADD CONSTRAINT fk_name FOREIGN KEY (col) REFERENCES other(id);

-- DROP / TRUNCATE
DROP TABLE IF EXISTS table_name;
TRUNCATE TABLE table_name;

-- ============================================================================
-- SECTION 12: INDEXES
-- ============================================================================

-- Create index
CREATE INDEX idx_name ON table(column);
CREATE UNIQUE INDEX idx_name ON table(column);
CREATE INDEX idx_name ON table(col1, col2);        -- Composite
CREATE INDEX idx_name ON table(column(10));        -- Prefix index

-- Drop index
DROP INDEX idx_name ON table;

-- Show indexes
SHOW INDEX FROM table_name;

-- ============================================================================
-- SECTION 13: VIEWS
-- ============================================================================

CREATE VIEW view_name AS
SELECT col1, col2 FROM table WHERE condition;

CREATE OR REPLACE VIEW view_name AS SELECT ...;

DROP VIEW IF EXISTS view_name;

-- ============================================================================
-- SECTION 14: TRANSACTIONS
-- ============================================================================

START TRANSACTION;
-- or: BEGIN;

-- DML statements here
INSERT INTO ...
UPDATE ...
DELETE FROM ...

COMMIT;                                            -- Save changes
-- or
ROLLBACK;                                          -- Undo changes

-- Savepoints
SAVEPOINT sp1;
ROLLBACK TO SAVEPOINT sp1;

-- ============================================================================
-- SECTION 15: STORED PROCEDURES
-- ============================================================================

DELIMITER //
CREATE PROCEDURE procedure_name(
    IN param1 INT,
    OUT param2 VARCHAR(100)
)
BEGIN
    -- Procedure body
    SELECT column INTO param2 FROM table WHERE id = param1;
END //
DELIMITER ;

-- Call procedure
CALL procedure_name(1, @result);
SELECT @result;

-- ============================================================================
-- SECTION 16: FUNCTIONS
-- ============================================================================

DELIMITER //
CREATE FUNCTION function_name(param INT)
RETURNS VARCHAR(50)
DETERMINISTIC
BEGIN
    DECLARE result VARCHAR(50);
    -- Function body
    RETURN result;
END //
DELIMITER ;

-- ============================================================================
-- SECTION 17: TRIGGERS
-- ============================================================================

DELIMITER //
CREATE TRIGGER trigger_name
BEFORE INSERT ON table_name
FOR EACH ROW
BEGIN
    SET NEW.created_at = NOW();
END //
DELIMITER ;

-- Trigger timing: BEFORE, AFTER
-- Trigger event: INSERT, UPDATE, DELETE
-- OLD.column - previous value (UPDATE, DELETE)
-- NEW.column - new value (INSERT, UPDATE)

-- ============================================================================
-- SECTION 18: JSON (MySQL 5.7+)
-- ============================================================================

-- Create/Store JSON
JSON_OBJECT('key', 'value')
JSON_ARRAY(1, 2, 3)

-- Extract
data->'$.key'                                      -- Returns JSON
data->>'$.key'                                     -- Returns text (unquoted)
JSON_EXTRACT(data, '$.key')

-- Modify
JSON_SET(data, '$.key', 'new_value')
JSON_INSERT(data, '$.newkey', 'value')
JSON_REPLACE(data, '$.key', 'value')
JSON_REMOVE(data, '$.key')

-- Query
JSON_CONTAINS(data, '"value"', '$.array')
JSON_CONTAINS_PATH(data, 'one', '$.key1', '$.key2')
JSON_KEYS(data)
JSON_LENGTH(data)

-- ============================================================================
-- SECTION 19: SET OPERATIONS
-- ============================================================================

SELECT ... UNION SELECT ...                        -- Unique combined
SELECT ... UNION ALL SELECT ...                    -- All combined (with dups)
SELECT ... INTERSECT SELECT ...                    -- Common to both
SELECT ... EXCEPT SELECT ...                       -- In first, not in second

-- ============================================================================
-- SECTION 20: USEFUL PATTERNS
-- ============================================================================

-- Pagination (offset-based)
SELECT * FROM table ORDER BY id LIMIT 10 OFFSET 20;

-- Pagination (keyset - better for large data)
SELECT * FROM table WHERE id > 100 ORDER BY id LIMIT 10;

-- Random row
SELECT * FROM table ORDER BY RAND() LIMIT 1;

-- Conditional aggregation
SELECT 
    COUNT(CASE WHEN status = 'active' THEN 1 END) AS active_count,
    COUNT(CASE WHEN status = 'inactive' THEN 1 END) AS inactive_count
FROM users;

-- Find duplicates
SELECT email, COUNT(*) FROM users GROUP BY email HAVING COUNT(*) > 1;

-- Delete duplicates (keep one)
DELETE t1 FROM table t1
INNER JOIN table t2 
WHERE t1.id < t2.id AND t1.email = t2.email;

-- Running total
SELECT *, SUM(amount) OVER (ORDER BY date) AS running_total FROM sales;

-- Gap in sequence
SELECT t1.id + 1 AS gap_start
FROM table t1
LEFT JOIN table t2 ON t1.id + 1 = t2.id
WHERE t2.id IS NULL;

-- Pivot (rows to columns)
SELECT 
    product,
    SUM(CASE WHEN month = 'Jan' THEN sales END) AS jan_sales,
    SUM(CASE WHEN month = 'Feb' THEN sales END) AS feb_sales
FROM sales
GROUP BY product;

-- ============================================================================
-- END OF CHEAT SHEET
-- ============================================================================
