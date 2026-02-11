-- ============================================================================
-- SQL PERFORMANCE AND OPTIMIZATION
-- Module 16: Query Tuning and Indexing Mastery
-- Goal: Write blazing-fast queries and design optimal database structures
-- ============================================================================

-- ============================================================================
-- SECTION 1: UNDERSTANDING QUERY EXECUTION
-- ============================================================================

/*
QUERY EXECUTION STAGES:
1. Parsing: Syntax check
2. Optimization: Choose execution plan
3. Execution: Run the plan
4. Return: Send results

EXPLAIN shows the execution plan chosen by optimizer.
*/

-- Basic EXPLAIN
EXPLAIN SELECT * FROM orders WHERE customer_id = 5;

-- EXPLAIN with more details
EXPLAIN FORMAT=JSON SELECT * FROM orders WHERE customer_id = 5;

-- EXPLAIN ANALYZE (MySQL 8.0.18+) - actually executes
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 5;

-- Key metrics to watch:
-- type: System > const > eq_ref > ref > range > index > ALL
-- rows: Estimated rows examined
-- filtered: Percentage of rows after filtering
-- Extra: Using index, Using filesort, Using temporary

-- ============================================================================
-- SECTION 2: INDEX FUNDAMENTALS
-- ============================================================================

/*
INDEX TYPES:

1. B-Tree (default): Best for equality and range queries
2. Hash: Fast equality only (memory tables)
3. Full-Text: Text searching
4. Spatial: Geographic data
5. Composite: Multiple columns
*/

-- Create indexes
CREATE INDEX idx_customer_id ON orders(customer_id);
CREATE INDEX idx_order_date ON orders(order_date);
CREATE UNIQUE INDEX idx_email ON customers(email);

-- Composite index (column order matters!)
CREATE INDEX idx_customer_date ON orders(customer_id, order_date);

-- Prefix index for long strings
CREATE INDEX idx_product_name ON products(product_name(50));

-- Full-text index
CREATE FULLTEXT INDEX idx_product_search ON products(product_name, description);

-- Show indexes
SHOW INDEX FROM orders;

-- Drop index
DROP INDEX idx_old_index ON table_name;

-- ============================================================================
-- SECTION 3: INDEX OPTIMIZATION STRATEGIES
-- ============================================================================

/*
COMPOSITE INDEX ORDER:
1. Equality columns first (WHERE col = value)
2. Range columns next (WHERE col > value)
3. ORDER BY / GROUP BY columns last

Index on (a, b, c) helps:
- WHERE a = ?
- WHERE a = ? AND b = ?
- WHERE a = ? AND b = ? AND c = ?
- WHERE a = ? AND b > ?
- ORDER BY a, b
- GROUP BY a, b

Does NOT help:
- WHERE b = ?  (skipped first column)
- WHERE a = ? AND c = ?  (gap in columns)
- ORDER BY b, a  (wrong order)
*/

-- Good: Uses index effectively
SELECT * FROM orders 
WHERE customer_id = 5 AND order_date > '2024-01-01'
ORDER BY order_date;

-- Create optimal index
CREATE INDEX idx_cust_date ON orders(customer_id, order_date);

-- Bad: Can't use index efficiently
SELECT * FROM orders 
WHERE order_date > '2024-01-01' AND customer_id = 5
ORDER BY total_amount;

-- Covering index (index contains all needed columns)
CREATE INDEX idx_covering ON orders(customer_id, order_date, total_amount, status);

-- Query can be satisfied entirely from index ("Using index")
EXPLAIN SELECT customer_id, order_date, total_amount 
FROM orders WHERE customer_id = 5;

-- ============================================================================
-- SECTION 4: QUERY OPTIMIZATION TECHNIQUES
-- ============================================================================

-- TECHNIQUE 1: Avoid SELECT *
-- Bad
SELECT * FROM orders WHERE customer_id = 5;

-- Good
SELECT order_id, order_date, total_amount, status
FROM orders WHERE customer_id = 5;

-- TECHNIQUE 2: Use appropriate WHERE conditions
-- Bad: Function on indexed column prevents index use
SELECT * FROM orders WHERE YEAR(order_date) = 2024;

-- Good: Range query uses index
SELECT * FROM orders 
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01';

-- Bad: Leading wildcard can't use index
SELECT * FROM products WHERE product_name LIKE '%phone%';

-- Good: Trailing wildcard can use index
SELECT * FROM products WHERE product_name LIKE 'Smart%';

-- TECHNIQUE 3: Optimize JOINs
-- Ensure join columns are indexed
CREATE INDEX idx_orders_customer ON orders(customer_id);
CREATE INDEX idx_items_order ON order_items(order_id);

-- Use appropriate join order
EXPLAIN SELECT c.customer_name, COUNT(o.order_id)
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id;

-- TECHNIQUE 4: Limit early
-- Bad: Fetch all then limit
SELECT * FROM (
    SELECT * FROM orders ORDER BY order_date DESC
) t LIMIT 10;

-- Good: Limit in query
SELECT * FROM orders ORDER BY order_date DESC LIMIT 10;

-- TECHNIQUE 5: Use EXISTS instead of IN for large subqueries
-- Potentially slower with large result
SELECT * FROM customers 
WHERE customer_id IN (SELECT customer_id FROM orders);

-- Often faster
SELECT * FROM customers c
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id);

-- ============================================================================
-- SECTION 5: OPTIMIZATION FOR SPECIFIC PATTERNS
-- ============================================================================

-- Pattern 1: Pagination optimization
-- Bad: OFFSET scans many rows
SELECT * FROM orders ORDER BY order_id LIMIT 10 OFFSET 100000;

-- Good: Keyset pagination (remember last ID)
SELECT * FROM orders 
WHERE order_id > 100000  -- Last seen ID
ORDER BY order_id 
LIMIT 10;

-- Pattern 2: COUNT optimization
-- Slow: Counts all rows
SELECT COUNT(*) FROM orders WHERE status = 'pending';

-- Faster: Use covering index
CREATE INDEX idx_status ON orders(status);
SELECT COUNT(*) FROM orders WHERE status = 'pending';

-- Even faster for approximate: Use statistics
SELECT table_rows FROM information_schema.tables 
WHERE table_name = 'orders';

-- Pattern 3: Aggregation optimization
-- Ensure GROUP BY columns are indexed
CREATE INDEX idx_customer_status ON orders(customer_id, status);

SELECT customer_id, status, COUNT(*), SUM(total_amount)
FROM orders
GROUP BY customer_id, status;

-- Pattern 4: Sorting optimization
-- Index for ORDER BY
CREATE INDEX idx_date_desc ON orders(order_date DESC);

SELECT * FROM orders ORDER BY order_date DESC LIMIT 100;

-- Pattern 5: OR optimization
-- Bad: OR often prevents index use
SELECT * FROM products WHERE category = 'Electronics' OR price > 5000000;

-- Better: UNION for different indexes
SELECT * FROM products WHERE category = 'Electronics'
UNION
SELECT * FROM products WHERE price > 5000000;

-- ============================================================================
-- SECTION 6: TABLE DESIGN OPTIMIZATION
-- ============================================================================

/*
NORMALIZATION vs DENORMALIZATION:

Normalization (3NF):
+ Less redundancy
+ Easier updates
- More JOINs

Denormalization:
+ Faster reads
- Redundant data
- Update anomalies
*/

-- Normalized design
CREATE TABLE orders (order_id INT, customer_id INT, ...);
CREATE TABLE customers (customer_id INT, customer_name VARCHAR(100), ...);
-- Need JOIN to get customer name with order

-- Denormalized for read performance
CREATE TABLE orders_denorm (
    order_id INT,
    customer_id INT,
    customer_name VARCHAR(100),  -- Copied from customers
    ...
);
-- No JOIN needed, but must update when customer name changes

-- Proper data types (use smallest that fits)
-- Bad
CREATE TABLE bad_design (
    id BIGINT,           -- Use INT if < 2 billion rows
    name VARCHAR(1000),  -- Use VARCHAR(100) if names are short
    is_active VARCHAR(5), -- Use BOOLEAN/TINYINT
    amount VARCHAR(20)   -- Use DECIMAL for money
);

-- Good
CREATE TABLE good_design (
    id INT UNSIGNED AUTO_INCREMENT,
    name VARCHAR(100),
    is_active BOOLEAN,
    amount DECIMAL(12,2)
);

-- ============================================================================
-- SECTION 7: PARTITIONING
-- ============================================================================

/*
Partition types:
- RANGE: Continuous ranges (dates, numbers)
- LIST: Discrete values
- HASH: Even distribution
- KEY: Like HASH, uses MySQL function
*/

-- Range partition by date
CREATE TABLE orders_partitioned (
    order_id INT,
    customer_id INT,
    order_date DATE,
    total_amount DECIMAL(12,2),
    PRIMARY KEY (order_id, order_date)
)
PARTITION BY RANGE (YEAR(order_date)) (
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION pmax VALUES LESS THAN MAXVALUE
);

-- Query benefits from partition pruning
SELECT * FROM orders_partitioned 
WHERE order_date >= '2024-01-01' AND order_date < '2024-07-01';
-- Only scans 2024 partition

-- List partition by region
CREATE TABLE customers_by_region (
    customer_id INT,
    customer_name VARCHAR(100),
    region VARCHAR(20),
    PRIMARY KEY (customer_id, region)
)
PARTITION BY LIST COLUMNS(region) (
    PARTITION p_central VALUES IN ('Kampala', 'Wakiso', 'Mukono'),
    PARTITION p_eastern VALUES IN ('Jinja', 'Mbale', 'Soroti'),
    PARTITION p_western VALUES IN ('Mbarara', 'Fort Portal', 'Kabale'),
    PARTITION p_northern VALUES IN ('Gulu', 'Lira', 'Arua')
);

-- Manage partitions
ALTER TABLE orders_partitioned ADD PARTITION (
    PARTITION p2025 VALUES LESS THAN (2026)
);

ALTER TABLE orders_partitioned DROP PARTITION p2022;

-- ============================================================================
-- SECTION 8: QUERY TUNING CASE STUDIES
-- ============================================================================

-- Case Study 1: Slow report query
-- Original (slow):
EXPLAIN ANALYZE
SELECT 
    c.customer_name,
    COUNT(o.order_id) AS order_count,
    SUM(o.total_amount) AS total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_date >= '2024-01-01'
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 10;

-- Analysis: Full table scan on orders, no index on order_date
-- Solution:
CREATE INDEX idx_order_date_customer ON orders(order_date, customer_id, total_amount);

-- Case Study 2: N+1 query problem
-- Bad pattern (in application):
/*
customers = SELECT * FROM customers;
FOR each customer:
    orders = SELECT * FROM orders WHERE customer_id = ?
*/

-- Solution: Single query with JOIN
SELECT c.*, o.order_id, o.order_date, o.total_amount
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.customer_id;

-- Or use subquery for counts
SELECT c.*, 
    (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS order_count
FROM customers c;

-- Case Study 3: Large IN clause
-- Bad (can be slow with many values):
SELECT * FROM orders WHERE customer_id IN (1, 2, 3, ... 1000 values);

-- Solution: Temporary table
CREATE TEMPORARY TABLE temp_customer_ids (customer_id INT PRIMARY KEY);
INSERT INTO temp_customer_ids VALUES (1), (2), (3), ...;

SELECT o.* FROM orders o
INNER JOIN temp_customer_ids t ON o.customer_id = t.customer_id;

-- ============================================================================
-- SECTION 9: MONITORING AND PROFILING
-- ============================================================================

-- Enable profiling
SET profiling = 1;

-- Run query
SELECT * FROM orders WHERE customer_id = 5;

-- Show profile
SHOW PROFILE;
SHOW PROFILE ALL;

-- Show all profiles
SHOW PROFILES;

-- Performance Schema queries
-- Find slow queries
SELECT * FROM performance_schema.events_statements_summary_by_digest
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;

-- Find unused indexes
SELECT * FROM sys.schema_unused_indexes;

-- Find missing indexes (heuristic)
SELECT * FROM sys.statements_with_full_table_scans
ORDER BY exec_count DESC
LIMIT 10;

-- Table statistics
SELECT 
    table_name,
    table_rows,
    data_length / 1024 / 1024 AS data_mb,
    index_length / 1024 / 1024 AS index_mb
FROM information_schema.tables
WHERE table_schema = DATABASE()
ORDER BY data_length DESC;

-- ============================================================================
-- SECTION 10: OPTIMIZATION CHECKLIST
-- ============================================================================

/*
CHECKLIST FOR QUERY OPTIMIZATION:

1. EXPLAIN first
   - Check type (aim for index/range, avoid ALL)
   - Check rows scanned
   - Look for "Using filesort" or "Using temporary"

2. Indexes
   - Create indexes on WHERE columns
   - Create composite indexes for multi-column conditions
   - Consider covering indexes for frequent queries
   - Remove unused indexes (they slow writes)

3. Query structure
   - Avoid SELECT * 
   - Push filters as early as possible
   - Use LIMIT when appropriate
   - Avoid functions on indexed columns in WHERE

4. Table design
   - Use appropriate data types
   - Consider denormalization for read-heavy workloads
   - Partition large tables

5. Application level
   - Avoid N+1 queries
   - Use connection pooling
   - Cache frequently accessed data
   - Batch operations

6. Server configuration
   - Buffer pool size
   - Query cache (if applicable)
   - Connection limits
*/

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Index optimization
a) Analyze a slow query with EXPLAIN and add appropriate index
b) Create a covering index for a parameterized query
c) Optimize a query with multiple OR conditions
d) Fix a query that can't use index due to function in WHERE

EXERCISE 2: Query rewriting
a) Rewrite correlated subquery as JOIN
b) Optimize pagination for large offset
c) Replace IN subquery with EXISTS
d) Optimize GROUP BY with aggregate functions

EXERCISE 3: Table optimization
a) Design partitioned table for time-series data
b) Denormalize a normalized schema for reporting
c) Choose optimal data types for a given schema
d) Create efficient audit trail table

EXERCISE 4: Profiling and monitoring
a) Profile a complex query and identify bottlenecks
b) Find and eliminate unused indexes
c) Identify queries causing most load
d) Create monitoring dashboard queries

EXERCISE 5: Real-world scenarios
a) Optimize e-commerce product search
b) Tune dashboard summary queries
c) Optimize bulk data import process
d) Design efficient logging system

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

