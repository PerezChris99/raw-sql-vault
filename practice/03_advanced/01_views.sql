-- ============================================================================
-- SQL VIEWS: VIRTUAL TABLES AND DATA ABSTRACTION
-- Module 12: Complete Guide to Views
-- Goal: Create reusable, secure, and performant data abstractions
-- ============================================================================

-- ============================================================================
-- SECTION 1: VIEW FUNDAMENTALS
-- ============================================================================

/*
VIEWS:
- Virtual tables based on SELECT queries
- Don't store data (computed on access)
- Simplify complex queries
- Provide data security layer
- Ensure consistent business logic
*/

-- Basic view creation
CREATE VIEW active_customers AS
SELECT 
    customer_id,
    customer_name,
    email,
    phone,
    district
FROM customers
WHERE is_active = TRUE;

-- Select from view like a table
SELECT * FROM active_customers;
SELECT * FROM active_customers WHERE district = 'Kampala';

-- View with calculations
CREATE VIEW product_summary AS
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    p.price,
    p.stock_quantity,
    p.price * p.stock_quantity AS inventory_value,
    CASE 
        WHEN p.stock_quantity = 0 THEN 'Out of Stock'
        WHEN p.stock_quantity < p.reorder_level THEN 'Low Stock'
        ELSE 'In Stock'
    END AS stock_status
FROM products p;

-- View with joins
CREATE VIEW order_details_view AS
SELECT 
    o.order_id,
    o.order_date,
    c.customer_name,
    c.email AS customer_email,
    e.emp_name AS salesperson,
    o.total_amount,
    o.status
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN employees e ON o.salesperson_id = e.emp_id;

-- ============================================================================
-- SECTION 2: VIEW OPTIONS AND MODIFIERS
-- ============================================================================

-- CREATE OR REPLACE (update existing view)
CREATE OR REPLACE VIEW active_customers AS
SELECT 
    customer_id,
    customer_name,
    email,
    phone,
    district,
    credit_limit  -- Added column
FROM customers
WHERE is_active = TRUE;

-- WITH CHECK OPTION (enforce view conditions on modifications)
CREATE VIEW kampala_customers AS
SELECT * FROM customers
WHERE district = 'Kampala'
WITH CHECK OPTION;

-- This would fail because district != 'Kampala':
-- INSERT INTO kampala_customers (customer_name, district) VALUES ('Test', 'Jinja');

-- WITH LOCAL CHECK OPTION vs WITH CASCADED CHECK OPTION
-- LOCAL: Only checks this view's conditions
-- CASCADED: Checks all underlying views' conditions (default)

-- WITH READ ONLY (PostgreSQL/Oracle) - prevent modifications
/*
CREATE VIEW product_catalog AS
SELECT product_id, product_name, price FROM products
WITH READ ONLY;
*/

-- ============================================================================
-- SECTION 3: UPDATABLE VIEWS
-- ============================================================================

/*
A view is updatable if:
- Based on single table
- Includes primary key
- No aggregates, DISTINCT, GROUP BY, UNION
- No subqueries in SELECT
- No derived columns
*/

-- Updatable view
CREATE VIEW employee_contact AS
SELECT 
    emp_id,
    emp_name,
    email,
    phone
FROM employees;

-- These work on updatable views:
UPDATE employee_contact SET phone = '0700000001' WHERE emp_id = 1;
INSERT INTO employee_contact (emp_id, emp_name, email, phone) 
VALUES (100, 'New Employee', 'new@company.ug', '0700000100');
DELETE FROM employee_contact WHERE emp_id = 100;

-- Non-updatable view (has JOIN)
CREATE VIEW order_customer_view AS
SELECT o.order_id, o.order_date, c.customer_name
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id;
-- Cannot INSERT/UPDATE/DELETE on this view

-- ============================================================================
-- SECTION 4: COMPLEX VIEWS
-- ============================================================================

-- View with subqueries
CREATE VIEW customer_statistics AS
SELECT 
    c.customer_id,
    c.customer_name,
    c.district,
    (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.customer_id) AS total_orders,
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders o WHERE o.customer_id = c.customer_id) AS total_spent,
    (SELECT MAX(order_date) FROM orders o WHERE o.customer_id = c.customer_id) AS last_order_date
FROM customers c;

-- View with window functions
CREATE VIEW sales_rankings AS
SELECT 
    e.emp_id,
    e.emp_name,
    e.department,
    SUM(o.total_amount) AS total_sales,
    RANK() OVER (ORDER BY SUM(o.total_amount) DESC) AS company_rank,
    RANK() OVER (PARTITION BY e.department ORDER BY SUM(o.total_amount) DESC) AS dept_rank
FROM employees e
LEFT JOIN orders o ON e.emp_id = o.salesperson_id
GROUP BY e.emp_id, e.emp_name, e.department;

-- View with CTEs
CREATE VIEW monthly_sales_analysis AS
WITH monthly_totals AS (
    SELECT 
        DATE_FORMAT(order_date, '%Y-%m') AS month,
        SUM(total_amount) AS total
    FROM orders
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT 
    month,
    total,
    LAG(total) OVER (ORDER BY month) AS prev_month,
    total - LAG(total) OVER (ORDER BY month) AS change,
    ROUND((total - LAG(total) OVER (ORDER BY month)) * 100.0 / 
          LAG(total) OVER (ORDER BY month), 2) AS growth_percent
FROM monthly_totals;

-- ============================================================================
-- SECTION 5: MATERIALIZED VIEWS (Concept and Alternatives)
-- ============================================================================

/*
Materialized Views:
- Store query results physically
- Need periodic refresh
- Better performance for complex queries
- Native support: Oracle, PostgreSQL, SQL Server

MySQL Alternatives:
1. Summary tables with triggers
2. Scheduled events for refresh
3. Caching at application layer
*/

-- MySQL alternative: Summary table
CREATE TABLE customer_summary_cache (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    total_orders INT,
    total_spent DECIMAL(15, 2),
    last_order_date DATE,
    cached_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Procedure to refresh
DELIMITER //
CREATE PROCEDURE refresh_customer_summary()
BEGIN
    TRUNCATE TABLE customer_summary_cache;
    
    INSERT INTO customer_summary_cache (customer_id, customer_name, total_orders, total_spent, last_order_date)
    SELECT 
        c.customer_id,
        c.customer_name,
        COUNT(o.order_id),
        COALESCE(SUM(o.total_amount), 0),
        MAX(o.order_date)
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.customer_name;
END //
DELIMITER ;

-- Schedule refresh (MySQL Event)
CREATE EVENT refresh_customer_summary_daily
ON SCHEDULE EVERY 1 DAY
STARTS '2024-01-01 00:00:00'
DO CALL refresh_customer_summary();

-- PostgreSQL Materialized View syntax:
/*
CREATE MATERIALIZED VIEW customer_summary AS
SELECT 
    c.customer_id,
    c.customer_name,
    COUNT(o.order_id) AS total_orders,
    COALESCE(SUM(o.total_amount), 0) AS total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name;

-- Refresh
REFRESH MATERIALIZED VIEW customer_summary;
REFRESH MATERIALIZED VIEW CONCURRENTLY customer_summary; -- No lock
*/

-- ============================================================================
-- SECTION 6: VIEW USE CASES
-- ============================================================================

-- Use Case 1: Security - Hide sensitive columns
CREATE VIEW public_employee_info AS
SELECT 
    emp_id,
    emp_name,
    department,
    hire_date
    -- Excluded: salary, personal_email, ssn, bank_account
FROM employees;

-- Use Case 2: Data masking
CREATE VIEW masked_customers AS
SELECT 
    customer_id,
    customer_name,
    CONCAT(LEFT(email, 2), '****@', SUBSTRING_INDEX(email, '@', -1)) AS email,
    CONCAT(LEFT(phone, 4), '******', RIGHT(phone, 2)) AS phone,
    district
FROM customers;

-- Use Case 3: Simplify complex joins
CREATE VIEW full_order_info AS
SELECT 
    o.order_id,
    o.order_date,
    o.status,
    c.customer_name,
    c.district AS customer_district,
    e.emp_name AS salesperson,
    COUNT(oi.item_id) AS item_count,
    SUM(oi.quantity) AS total_units,
    o.total_amount
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN employees e ON o.salesperson_id = e.emp_id
JOIN order_items oi ON o.order_id = oi.order_id
GROUP BY o.order_id, o.order_date, o.status, c.customer_name, 
         c.district, e.emp_name, o.total_amount;

-- Use Case 4: Enforce business rules
CREATE VIEW valid_orders AS
SELECT * FROM orders
WHERE total_amount > 0
  AND status IN ('pending', 'processing', 'shipped', 'completed')
  AND order_date IS NOT NULL;

-- Use Case 5: API/Reporting layer
CREATE VIEW sales_dashboard AS
SELECT 
    DATE_FORMAT(order_date, '%Y-%m-%d') AS sale_date,
    COUNT(*) AS orders_count,
    SUM(total_amount) AS daily_revenue,
    AVG(total_amount) AS avg_order_value,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM orders
WHERE status = 'completed'
GROUP BY DATE_FORMAT(order_date, '%Y-%m-%d');

-- Use Case 6: Versioning/Historical views
CREATE VIEW current_prices AS
SELECT 
    product_id,
    product_name,
    price,
    effective_date
FROM product_prices
WHERE effective_date <= CURDATE()
  AND (end_date IS NULL OR end_date > CURDATE());

-- ============================================================================
-- SECTION 7: VIEW MANAGEMENT
-- ============================================================================

-- Show view definition
SHOW CREATE VIEW active_customers;

-- List all views
SELECT TABLE_NAME, VIEW_DEFINITION 
FROM information_schema.VIEWS 
WHERE TABLE_SCHEMA = DATABASE();

-- Check if view exists
SELECT COUNT(*) FROM information_schema.VIEWS 
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'active_customers';

-- Drop view
DROP VIEW IF EXISTS old_view;

-- Drop multiple views
DROP VIEW IF EXISTS view1, view2, view3;

-- Rename view (MySQL: recreate with new name)
-- Some databases: ALTER VIEW old_name RENAME TO new_name;

-- ============================================================================
-- SECTION 8: VIEW PERFORMANCE CONSIDERATIONS
-- ============================================================================

/*
PERFORMANCE TIPS:

1. Views don't cache results - query runs each time
2. Complex views can be slow on large tables
3. Avoid views inside views (nested views)
4. Indexes on base tables benefit view queries
5. Consider materialized views for heavy analytics

ANTI-PATTERNS TO AVOID:
- SELECT * in views
- Deep view nesting
- Views on views on views
- Complex calculations without indexes
*/

-- Example: Efficient vs inefficient view

-- Inefficient: Uses SELECT *, subqueries in SELECT
CREATE VIEW inefficient_customer_view AS
SELECT 
    *,
    (SELECT COUNT(*) FROM orders WHERE customer_id = c.customer_id) AS order_count
FROM customers c;

-- Efficient: Specific columns, proper JOIN
CREATE VIEW efficient_customer_view AS
SELECT 
    c.customer_id,
    c.customer_name,
    c.email,
    COUNT(o.order_id) AS order_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name, c.email;

-- ============================================================================
-- SECTION 9: VIEW-BASED ARCHITECTURE PATTERNS
-- ============================================================================

-- Pattern 1: Layered views
-- Raw layer
CREATE VIEW raw_orders AS
SELECT * FROM orders WHERE deleted_at IS NULL;

-- Business layer
CREATE VIEW business_orders AS
SELECT 
    order_id,
    customer_id,
    order_date,
    total_amount,
    CASE status 
        WHEN 'pending' THEN 'Awaiting'
        WHEN 'completed' THEN 'Done'
        ELSE status
    END AS display_status
FROM raw_orders;

-- Presentation layer
CREATE VIEW dashboard_orders AS
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS period,
    COUNT(*) AS order_count,
    SUM(total_amount) AS total_revenue
FROM business_orders
GROUP BY DATE_FORMAT(order_date, '%Y-%m');

-- Pattern 2: Role-based views
CREATE VIEW admin_customers AS SELECT * FROM customers;

CREATE VIEW sales_customers AS
SELECT customer_id, customer_name, email, phone, district, credit_limit
FROM customers;

CREATE VIEW public_customers AS
SELECT customer_id, customer_name, district
FROM customers;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Create views for:
a) Active products with stock status and inventory value
b) Monthly revenue summary with growth percentage
c) Customer 360 view (all customer data in one place)
d) Employee performance dashboard

EXERCISE 2: Security views:
a) Create masked view for customer PII
b) Create department-specific employee views
c) Create read-only order audit view
d) Create view with row-level security simulation

EXERCISE 3: Reporting views:
a) Sales by region pivot view
b) Product performance metrics view
c) Customer segmentation view (RFM)
d) Inventory aging report view

EXERCISE 4: Complex views:
a) View showing running totals by customer
b) View ranking products by sales within category
c) View comparing current period to same period last year
d) View for cohort analysis (customers by registration month)

EXERCISE 5: View management:
a) Write query to list all views and their dependencies
b) Create procedure to refresh a "materialized" summary table
c) Design layered view architecture for a dashboard
d) Create view with appropriate CHECK OPTION

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

