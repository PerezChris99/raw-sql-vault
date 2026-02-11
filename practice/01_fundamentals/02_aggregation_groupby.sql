-- ============================================================================
-- SQL AGGREGATION: GROUP BY, HAVING, AND AGGREGATE FUNCTIONS
-- Module 05: Data Summarization and Analysis
-- Goal: Master data aggregation for reporting and analytics
-- ============================================================================

-- ============================================================================
-- SETUP: SAMPLE DATA FOR PRACTICE
-- ============================================================================

CREATE TABLE sales (
    sale_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    region VARCHAR(50),
    salesperson VARCHAR(100),
    sale_date DATE,
    quantity INT,
    unit_price DECIMAL(10, 2),
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    total_amount DECIMAL(12, 2)
);

INSERT INTO sales (product_name, category, region, salesperson, sale_date, quantity, unit_price, discount_percent, total_amount) VALUES
('Smartphone X', 'Electronics', 'Central', 'John Mukasa', '2024-01-05', 5, 1500000, 0, 7500000),
('Laptop Pro', 'Electronics', 'Central', 'Sarah Nalwoga', '2024-01-07', 2, 4000000, 5, 7600000),
('Office Chair', 'Furniture', 'Eastern', 'Peter Okello', '2024-01-10', 10, 250000, 10, 2250000),
('Standing Desk', 'Furniture', 'Central', 'John Mukasa', '2024-01-12', 3, 800000, 0, 2400000),
('Smartphone X', 'Electronics', 'Western', 'Grace Auma', '2024-01-15', 8, 1500000, 5, 11400000),
('Tablet Mini', 'Electronics', 'Northern', 'David Ochen', '2024-01-18', 15, 800000, 10, 10800000),
('Office Chair', 'Furniture', 'Central', 'Sarah Nalwoga', '2024-01-20', 20, 250000, 15, 4250000),
('Laptop Pro', 'Electronics', 'Eastern', 'Peter Okello', '2024-01-22', 4, 4000000, 0, 16000000),
('Monitor 27"', 'Electronics', 'Central', 'John Mukasa', '2024-01-25', 6, 1200000, 0, 7200000),
('Filing Cabinet', 'Furniture', 'Western', 'Grace Auma', '2024-01-28', 8, 350000, 0, 2800000),
('Smartphone X', 'Electronics', 'Central', 'Sarah Nalwoga', '2024-02-01', 10, 1500000, 10, 13500000),
('Keyboard Pro', 'Electronics', 'Northern', 'David Ochen', '2024-02-03', 25, 150000, 5, 3562500),
('Standing Desk', 'Furniture', 'Eastern', 'Peter Okello', '2024-02-05', 5, 800000, 0, 4000000),
('Laptop Pro', 'Electronics', 'Central', 'John Mukasa', '2024-02-08', 3, 4000000, 10, 10800000),
('Monitor 27"', 'Electronics', 'Western', 'Grace Auma', '2024-02-10', 4, 1200000, 0, 4800000),
('Office Chair', 'Furniture', 'Northern', 'David Ochen', '2024-02-12', 15, 250000, 5, 3562500),
('Tablet Mini', 'Electronics', 'Central', 'Sarah Nalwoga', '2024-02-15', 12, 800000, 0, 9600000),
('Filing Cabinet', 'Furniture', 'Central', 'John Mukasa', '2024-02-18', 6, 350000, 10, 1890000),
('Smartphone X', 'Electronics', 'Eastern', 'Peter Okello', '2024-02-20', 7, 1500000, 0, 10500000),
('Standing Desk', 'Furniture', 'Western', 'Grace Auma', '2024-02-22', 4, 800000, 5, 3040000);

-- ============================================================================
-- SECTION 1: AGGREGATE FUNCTIONS - THE BASICS
-- ============================================================================

/*
Core Aggregate Functions:
- COUNT() - Count rows or non-null values
- SUM() - Sum of values
- AVG() - Average of values
- MIN() - Minimum value
- MAX() - Maximum value
*/

-- COUNT variations
SELECT COUNT(*) AS total_rows FROM sales;              -- Count all rows
SELECT COUNT(sale_id) AS count_with_ids FROM sales;    -- Count non-null sale_ids
SELECT COUNT(DISTINCT category) AS unique_categories FROM sales;
SELECT COUNT(DISTINCT salesperson) AS unique_salespeople FROM sales;

-- SUM
SELECT SUM(total_amount) AS total_revenue FROM sales;
SELECT SUM(quantity) AS total_units_sold FROM sales;

-- AVG
SELECT AVG(total_amount) AS average_sale FROM sales;
SELECT AVG(unit_price) AS average_unit_price FROM sales;

-- MIN and MAX
SELECT 
    MIN(total_amount) AS smallest_sale,
    MAX(total_amount) AS largest_sale,
    MIN(sale_date) AS first_sale_date,
    MAX(sale_date) AS last_sale_date
FROM sales;

-- ============================================================================
-- SECTION 2: GROUP BY - AGGREGATING BY CATEGORIES
-- ============================================================================

-- Basic GROUP BY
SELECT 
    category,
    COUNT(*) AS num_sales,
    SUM(total_amount) AS total_revenue
FROM sales
GROUP BY category;

-- Group by multiple columns
SELECT 
    category,
    region,
    COUNT(*) AS num_sales,
    SUM(total_amount) AS total_revenue
FROM sales
GROUP BY category, region
ORDER BY category, total_revenue DESC;

-- Group by with expressions
SELECT 
    MONTH(sale_date) AS sale_month,
    YEAR(sale_date) AS sale_year,
    COUNT(*) AS num_sales,
    SUM(total_amount) AS monthly_revenue
FROM sales
GROUP BY YEAR(sale_date), MONTH(sale_date)
ORDER BY sale_year, sale_month;

-- Group by with date truncation
SELECT 
    DATE_FORMAT(sale_date, '%Y-%m') AS month,
    SUM(total_amount) AS revenue
FROM sales
GROUP BY DATE_FORMAT(sale_date, '%Y-%m');

-- ============================================================================
-- SECTION 3: HAVING - FILTERING GROUPED RESULTS
-- ============================================================================

/*
WHERE vs HAVING:
- WHERE filters rows BEFORE grouping
- HAVING filters groups AFTER aggregation
*/

-- HAVING with aggregate condition
SELECT 
    salesperson,
    COUNT(*) AS num_sales,
    SUM(total_amount) AS total_revenue
FROM sales
GROUP BY salesperson
HAVING SUM(total_amount) > 20000000;

-- WHERE and HAVING together
SELECT 
    salesperson,
    COUNT(*) AS num_sales,
    SUM(total_amount) AS total_revenue
FROM sales
WHERE category = 'Electronics'       -- Filter rows first
GROUP BY salesperson
HAVING COUNT(*) >= 3;                -- Then filter groups

-- HAVING with multiple conditions
SELECT 
    category,
    region,
    COUNT(*) AS num_sales,
    AVG(total_amount) AS avg_sale
FROM sales
GROUP BY category, region
HAVING COUNT(*) >= 2 
   AND AVG(total_amount) > 3000000;

-- ============================================================================
-- SECTION 4: ADVANCED AGGREGATE FUNCTIONS
-- ============================================================================

-- GROUP_CONCAT / STRING_AGG - Concatenate values
SELECT 
    category,
    GROUP_CONCAT(DISTINCT product_name ORDER BY product_name SEPARATOR ', ') AS products
FROM sales
GROUP BY category;

-- With custom separator and limit
SELECT 
    region,
    GROUP_CONCAT(DISTINCT salesperson ORDER BY salesperson SEPARATOR ' | ') AS salespeople
FROM sales
GROUP BY region;

-- Statistical functions
SELECT 
    category,
    COUNT(*) AS n,
    AVG(total_amount) AS mean,
    STDDEV(total_amount) AS std_dev,
    VARIANCE(total_amount) AS variance
FROM sales
GROUP BY category;

-- ============================================================================
-- SECTION 5: GROUPING WITH ROLLUP AND CUBE
-- ============================================================================

/*
ROLLUP: Creates subtotals and grand total
CUBE: Creates all possible subtotals (PostgreSQL/SQL Server)
*/

-- ROLLUP - hierarchical subtotals
SELECT 
    COALESCE(category, '*** ALL CATEGORIES ***') AS category,
    COALESCE(region, '*** ALL REGIONS ***') AS region,
    COUNT(*) AS num_sales,
    SUM(total_amount) AS total_revenue
FROM sales
GROUP BY category, region WITH ROLLUP;

-- Identify rollup rows with GROUPING()
SELECT 
    IF(GROUPING(category), 'ALL CATEGORIES', category) AS category,
    IF(GROUPING(region), 'ALL REGIONS', region) AS region,
    COUNT(*) AS num_sales,
    SUM(total_amount) AS total_revenue,
    GROUPING(category) AS is_category_total,
    GROUPING(region) AS is_region_total
FROM sales
GROUP BY category, region WITH ROLLUP;

-- Two-level rollup for time-based analysis
SELECT 
    COALESCE(DATE_FORMAT(sale_date, '%Y-%m'), 'TOTAL') AS month,
    COALESCE(category, 'ALL') AS category,
    SUM(total_amount) AS revenue
FROM sales
GROUP BY DATE_FORMAT(sale_date, '%Y-%m'), category WITH ROLLUP;

-- ============================================================================
-- SECTION 6: CONDITIONAL AGGREGATION
-- ============================================================================

-- CASE inside aggregate functions
SELECT 
    salesperson,
    COUNT(*) AS total_sales,
    SUM(CASE WHEN category = 'Electronics' THEN 1 ELSE 0 END) AS electronics_sales,
    SUM(CASE WHEN category = 'Furniture' THEN 1 ELSE 0 END) AS furniture_sales,
    SUM(CASE WHEN discount_percent > 0 THEN 1 ELSE 0 END) AS discounted_sales
FROM sales
GROUP BY salesperson;

-- Pivot-style report: Revenue by category and region
SELECT 
    category,
    SUM(CASE WHEN region = 'Central' THEN total_amount ELSE 0 END) AS central_revenue,
    SUM(CASE WHEN region = 'Eastern' THEN total_amount ELSE 0 END) AS eastern_revenue,
    SUM(CASE WHEN region = 'Western' THEN total_amount ELSE 0 END) AS western_revenue,
    SUM(CASE WHEN region = 'Northern' THEN total_amount ELSE 0 END) AS northern_revenue,
    SUM(total_amount) AS total_revenue
FROM sales
GROUP BY category;

-- Conditional average
SELECT 
    category,
    AVG(total_amount) AS overall_avg,
    AVG(CASE WHEN discount_percent = 0 THEN total_amount END) AS full_price_avg,
    AVG(CASE WHEN discount_percent > 0 THEN total_amount END) AS discounted_avg
FROM sales
GROUP BY category;

-- Count with conditions
SELECT 
    DATE_FORMAT(sale_date, '%Y-%m') AS month,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN total_amount >= 10000000 THEN 1 END) AS large_orders,
    COUNT(CASE WHEN total_amount < 5000000 THEN 1 END) AS small_orders
FROM sales
GROUP BY DATE_FORMAT(sale_date, '%Y-%m');

-- ============================================================================
-- SECTION 7: AGGREGATE WITH FILTERING (FILTER CLAUSE - PostgreSQL)
-- ============================================================================

-- MySQL equivalent using CASE (shown above)
-- PostgreSQL FILTER syntax:
/*
SELECT 
    salesperson,
    COUNT(*) AS total_sales,
    COUNT(*) FILTER (WHERE category = 'Electronics') AS electronics_sales,
    SUM(total_amount) FILTER (WHERE discount_percent > 0) AS discounted_revenue
FROM sales
GROUP BY salesperson;
*/

-- ============================================================================
-- SECTION 8: FINDING TOP-N PER GROUP
-- ============================================================================

-- Top performer overall
SELECT salesperson, SUM(total_amount) AS revenue
FROM sales
GROUP BY salesperson
ORDER BY revenue DESC
LIMIT 1;

-- Top product per category (using subquery)
SELECT s1.category, s1.product_name, s1.total_revenue
FROM (
    SELECT 
        category,
        product_name,
        SUM(total_amount) AS total_revenue
    FROM sales
    GROUP BY category, product_name
) s1
WHERE s1.total_revenue = (
    SELECT MAX(s2.total_revenue)
    FROM (
        SELECT category, product_name, SUM(total_amount) AS total_revenue
        FROM sales
        GROUP BY category, product_name
    ) s2
    WHERE s2.category = s1.category
);

-- Using window functions (cleaner - covered in advanced module)
WITH ranked_products AS (
    SELECT 
        category,
        product_name,
        SUM(total_amount) AS total_revenue,
        RANK() OVER (PARTITION BY category ORDER BY SUM(total_amount) DESC) AS rnk
    FROM sales
    GROUP BY category, product_name
)
SELECT category, product_name, total_revenue
FROM ranked_products
WHERE rnk = 1;

-- ============================================================================
-- SECTION 9: PERCENTAGE AND RATIO CALCULATIONS
-- ============================================================================

-- Percentage of total
SELECT 
    category,
    SUM(total_amount) AS category_revenue,
    SUM(total_amount) * 100.0 / (SELECT SUM(total_amount) FROM sales) AS percent_of_total
FROM sales
GROUP BY category;

-- Percentage using window functions
SELECT 
    category,
    SUM(total_amount) AS category_revenue,
    ROUND(SUM(total_amount) * 100.0 / SUM(SUM(total_amount)) OVER (), 2) AS percent_of_total
FROM sales
GROUP BY category;

-- Year-over-year comparison (if we had multiple years)
SELECT 
    category,
    SUM(CASE WHEN YEAR(sale_date) = 2024 THEN total_amount ELSE 0 END) AS revenue_2024,
    SUM(CASE WHEN YEAR(sale_date) = 2023 THEN total_amount ELSE 0 END) AS revenue_2023,
    ROUND(
        (SUM(CASE WHEN YEAR(sale_date) = 2024 THEN total_amount ELSE 0 END) - 
         SUM(CASE WHEN YEAR(sale_date) = 2023 THEN total_amount ELSE 0 END)) * 100.0 /
        NULLIF(SUM(CASE WHEN YEAR(sale_date) = 2023 THEN total_amount ELSE 0 END), 0),
        2
    ) AS yoy_growth_percent
FROM sales
GROUP BY category;

-- ============================================================================
-- SECTION 10: RUNNING TOTALS AND CUMULATIVE AGGREGATES
-- ============================================================================

-- Running total using subquery (older method)
SELECT 
    s1.sale_date,
    s1.total_amount,
    (SELECT SUM(s2.total_amount) 
     FROM sales s2 
     WHERE s2.sale_date <= s1.sale_date) AS running_total
FROM sales s1
ORDER BY s1.sale_date;

-- Running total using window functions (preferred)
SELECT 
    sale_date,
    total_amount,
    SUM(total_amount) OVER (ORDER BY sale_date) AS running_total
FROM sales
ORDER BY sale_date;

-- Daily cumulative by category
SELECT 
    sale_date,
    category,
    total_amount,
    SUM(total_amount) OVER (
        PARTITION BY category 
        ORDER BY sale_date
    ) AS category_running_total
FROM sales
ORDER BY category, sale_date;

-- ============================================================================
-- SECTION 11: AGGREGATE QUERY PATTERNS FOR REPORTING
-- ============================================================================

-- Sales Dashboard Summary
SELECT 
    -- Overall metrics
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT salesperson) AS active_salespeople,
    SUM(quantity) AS total_units,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS average_order_value,
    
    -- Period metrics
    SUM(CASE WHEN sale_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) 
        THEN total_amount ELSE 0 END) AS last_30_days_revenue,
    
    -- Category breakdown
    SUM(CASE WHEN category = 'Electronics' THEN total_amount ELSE 0 END) AS electronics_revenue,
    SUM(CASE WHEN category = 'Furniture' THEN total_amount ELSE 0 END) AS furniture_revenue
FROM sales;

-- Monthly Summary Report
SELECT 
    DATE_FORMAT(sale_date, '%Y-%m') AS month,
    COUNT(*) AS num_orders,
    COUNT(DISTINCT salesperson) AS active_reps,
    COUNT(DISTINCT product_name) AS products_sold,
    SUM(quantity) AS total_units,
    SUM(total_amount) AS revenue,
    AVG(total_amount) AS avg_order,
    MAX(total_amount) AS largest_order
FROM sales
GROUP BY DATE_FORMAT(sale_date, '%Y-%m')
ORDER BY month;

-- Salesperson Performance Report
SELECT 
    salesperson,
    COUNT(*) AS num_sales,
    SUM(quantity) AS units_sold,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS avg_sale,
    MAX(total_amount) AS best_sale,
    COUNT(DISTINCT category) AS categories_sold,
    AVG(discount_percent) AS avg_discount_given
FROM sales
GROUP BY salesperson
ORDER BY total_revenue DESC;

-- Product Performance Analysis
SELECT 
    product_name,
    category,
    COUNT(*) AS times_sold,
    SUM(quantity) AS total_units,
    AVG(unit_price) AS avg_price,
    SUM(total_amount) AS total_revenue,
    AVG(discount_percent) AS avg_discount
FROM sales
GROUP BY product_name, category
ORDER BY total_revenue DESC;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Write queries to find:
a) Total revenue by region, sorted highest to lowest
b) Average sale amount by salesperson, only for those with 3+ sales
c) Number of sales by category and month
d) Products that have never been discounted

EXERCISE 2: Create a pivot table showing:
- Rows: Salespeople
- Columns: Each category
- Values: Revenue per category per salesperson
- Include row and column totals

EXERCISE 3: Calculate for each salesperson:
- Their percentage of total company sales
- How they compare to the company average (above/below and by how much)
- Their ranking among all salespeople

EXERCISE 4: Write a query that shows:
- Month-over-month revenue growth
- Running total of revenue
- 3-month moving average of revenue

EXERCISE 5: Create a comprehensive "Daily Sales Report" that shows:
- Date
- Number of transactions
- Total revenue
- Percentage of monthly target (assume 50,000,000 UGX monthly target)
- Running total for the month
- Days remaining in month
- Required daily average to meet target

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

