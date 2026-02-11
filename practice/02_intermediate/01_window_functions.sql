-- ============================================================================
-- SQL WINDOW FUNCTIONS: ANALYTICS POWERHOUSE
-- Module 08: Complete Window Functions Mastery
-- Goal: Perform advanced analytics without losing row-level detail
-- ============================================================================

-- ============================================================================
-- SETUP: SAMPLE DATA
-- ============================================================================

CREATE TABLE employee_sales (
    sale_id INT PRIMARY KEY AUTO_INCREMENT,
    employee_id INT,
    employee_name VARCHAR(100),
    department VARCHAR(50),
    sale_date DATE,
    amount DECIMAL(12, 2),
    region VARCHAR(50)
);

INSERT INTO employee_sales (employee_id, employee_name, department, sale_date, amount, region) VALUES
(1, 'John Mukasa', 'Electronics', '2024-01-05', 5000000, 'Central'),
(1, 'John Mukasa', 'Electronics', '2024-01-15', 3500000, 'Central'),
(1, 'John Mukasa', 'Electronics', '2024-02-10', 4200000, 'Central'),
(2, 'Sarah Nalwoga', 'Electronics', '2024-01-08', 6000000, 'Central'),
(2, 'Sarah Nalwoga', 'Electronics', '2024-01-25', 4500000, 'Eastern'),
(2, 'Sarah Nalwoga', 'Electronics', '2024-02-15', 5500000, 'Central'),
(3, 'Peter Okello', 'Furniture', '2024-01-10', 2500000, 'Eastern'),
(3, 'Peter Okello', 'Furniture', '2024-01-20', 3000000, 'Eastern'),
(3, 'Peter Okello', 'Furniture', '2024-02-05', 2800000, 'Northern'),
(4, 'Grace Auma', 'Furniture', '2024-01-12', 3500000, 'Western'),
(4, 'Grace Auma', 'Furniture', '2024-02-01', 4000000, 'Western'),
(5, 'David Ochen', 'Appliances', '2024-01-15', 4500000, 'Northern'),
(5, 'David Ochen', 'Appliances', '2024-01-28', 5000000, 'Northern'),
(5, 'David Ochen', 'Appliances', '2024-02-12', 4800000, 'Central');

-- ============================================================================
-- SECTION 1: WINDOW FUNCTION BASICS
-- ============================================================================

/*
Window Functions:
- Perform calculations across a set of rows RELATED to current row
- Unlike GROUP BY, don't collapse rows
- Syntax: function() OVER (...)

Key Components:
- PARTITION BY: Divides rows into groups (like GROUP BY but keeps rows)
- ORDER BY: Defines row order within partition
- Frame: Specifies which rows to include in calculation
*/

-- Basic window function vs aggregate
-- Aggregate (loses row detail):
SELECT department, SUM(amount) AS dept_total
FROM employee_sales
GROUP BY department;

-- Window function (keeps row detail):
SELECT 
    employee_name,
    department,
    amount,
    SUM(amount) OVER (PARTITION BY department) AS dept_total
FROM employee_sales;

-- Multiple window functions in same query
SELECT 
    employee_name,
    department,
    amount,
    SUM(amount) OVER (PARTITION BY department) AS dept_total,
    AVG(amount) OVER (PARTITION BY department) AS dept_avg,
    COUNT(*) OVER (PARTITION BY department) AS dept_count
FROM employee_sales;

-- ============================================================================
-- SECTION 2: RANKING FUNCTIONS
-- ============================================================================

/*
ROW_NUMBER(): Sequential number, no ties
RANK(): Same rank for ties, gaps after
DENSE_RANK(): Same rank for ties, no gaps
NTILE(n): Divides into n equal groups
*/

-- ROW_NUMBER - unique sequential numbers
SELECT 
    employee_name,
    department,
    amount,
    ROW_NUMBER() OVER (ORDER BY amount DESC) AS row_num
FROM employee_sales;

-- ROW_NUMBER with partition - rank within each department
SELECT 
    employee_name,
    department,
    amount,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY amount DESC) AS dept_rank
FROM employee_sales;

-- RANK vs DENSE_RANK
SELECT 
    employee_name,
    amount,
    ROW_NUMBER() OVER (ORDER BY amount DESC) AS row_num,
    RANK() OVER (ORDER BY amount DESC) AS rank_num,
    DENSE_RANK() OVER (ORDER BY amount DESC) AS dense_rank_num
FROM employee_sales;

-- NTILE - divide into quartiles
SELECT 
    employee_name,
    amount,
    NTILE(4) OVER (ORDER BY amount) AS quartile,
    NTILE(3) OVER (ORDER BY amount) AS tertile,
    NTILE(2) OVER (ORDER BY amount) AS half
FROM employee_sales;

-- Top N per group using ROW_NUMBER
SELECT * FROM (
    SELECT 
        employee_name,
        department,
        amount,
        ROW_NUMBER() OVER (PARTITION BY department ORDER BY amount DESC) AS rn
    FROM employee_sales
) ranked
WHERE rn <= 2;  -- Top 2 sales per department

-- ============================================================================
-- SECTION 3: AGGREGATE WINDOW FUNCTIONS
-- ============================================================================

-- Running totals
SELECT 
    sale_date,
    employee_name,
    amount,
    SUM(amount) OVER (ORDER BY sale_date) AS running_total
FROM employee_sales
ORDER BY sale_date;

-- Running total per employee
SELECT 
    sale_date,
    employee_name,
    amount,
    SUM(amount) OVER (PARTITION BY employee_id ORDER BY sale_date) AS emp_running_total
FROM employee_sales
ORDER BY employee_name, sale_date;

-- Running count and average
SELECT 
    sale_date,
    employee_name,
    amount,
    COUNT(*) OVER (ORDER BY sale_date) AS running_count,
    AVG(amount) OVER (ORDER BY sale_date) AS running_avg
FROM employee_sales
ORDER BY sale_date;

-- Percentage of total
SELECT 
    employee_name,
    department,
    amount,
    SUM(amount) OVER () AS grand_total,
    ROUND(amount * 100.0 / SUM(amount) OVER (), 2) AS pct_of_total,
    ROUND(amount * 100.0 / SUM(amount) OVER (PARTITION BY department), 2) AS pct_of_dept
FROM employee_sales;

-- ============================================================================
-- SECTION 4: VALUE FUNCTIONS (LAG, LEAD, FIRST_VALUE, LAST_VALUE)
-- ============================================================================

-- LAG - access previous row
SELECT 
    sale_date,
    employee_name,
    amount,
    LAG(amount) OVER (ORDER BY sale_date) AS prev_sale,
    amount - LAG(amount) OVER (ORDER BY sale_date) AS change_from_prev
FROM employee_sales
ORDER BY sale_date;

-- LAG with partition - previous sale by same employee
SELECT 
    sale_date,
    employee_name,
    amount,
    LAG(amount) OVER (PARTITION BY employee_id ORDER BY sale_date) AS prev_emp_sale,
    amount - LAG(amount) OVER (PARTITION BY employee_id ORDER BY sale_date) AS emp_change
FROM employee_sales
ORDER BY employee_name, sale_date;

-- LAG with offset and default
SELECT 
    sale_date,
    employee_name,
    amount,
    LAG(amount, 1, 0) OVER (ORDER BY sale_date) AS prev_1,      -- 1 row back, default 0
    LAG(amount, 2, 0) OVER (ORDER BY sale_date) AS prev_2       -- 2 rows back
FROM employee_sales
ORDER BY sale_date;

-- LEAD - access next row
SELECT 
    sale_date,
    employee_name,
    amount,
    LEAD(amount) OVER (ORDER BY sale_date) AS next_sale,
    LEAD(amount, 1, 0) OVER (ORDER BY sale_date) - amount AS diff_to_next
FROM employee_sales
ORDER BY sale_date;

-- FIRST_VALUE and LAST_VALUE
SELECT 
    employee_name,
    department,
    amount,
    FIRST_VALUE(amount) OVER (PARTITION BY department ORDER BY amount DESC) AS highest_in_dept,
    LAST_VALUE(amount) OVER (
        PARTITION BY department 
        ORDER BY amount DESC
        RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS lowest_in_dept
FROM employee_sales;

-- NTH_VALUE - get specific position
SELECT 
    employee_name,
    department,
    amount,
    NTH_VALUE(amount, 1) OVER (PARTITION BY department ORDER BY amount DESC) AS first_highest,
    NTH_VALUE(amount, 2) OVER (PARTITION BY department ORDER BY amount DESC) AS second_highest
FROM employee_sales;

-- ============================================================================
-- SECTION 5: WINDOW FRAMES
-- ============================================================================

/*
Frame Syntax:
ROWS/RANGE BETWEEN <start> AND <end>

Frame Bounds:
- UNBOUNDED PRECEDING: Start of partition
- N PRECEDING: N rows before current
- CURRENT ROW: Current row
- N FOLLOWING: N rows after current
- UNBOUNDED FOLLOWING: End of partition

ROWS vs RANGE:
- ROWS: Physical rows
- RANGE: Logical range (rows with same value treated as one)
*/

-- Default frame (RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
SELECT 
    sale_date,
    amount,
    SUM(amount) OVER (ORDER BY sale_date) AS default_running_sum
FROM employee_sales;

-- Explicit frame: 3-row moving average
SELECT 
    sale_date,
    employee_name,
    amount,
    AVG(amount) OVER (
        ORDER BY sale_date 
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3
FROM employee_sales
ORDER BY sale_date;

-- Centered moving average (1 before, current, 1 after)
SELECT 
    sale_date,
    amount,
    AVG(amount) OVER (
        ORDER BY sale_date 
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS centered_avg
FROM employee_sales
ORDER BY sale_date;

-- Sum of current and all following
SELECT 
    sale_date,
    amount,
    SUM(amount) OVER (
        ORDER BY sale_date 
        ROWS BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING
    ) AS remaining_total
FROM employee_sales
ORDER BY sale_date;

-- RANGE vs ROWS (difference with ties)
SELECT 
    sale_date,
    amount,
    SUM(amount) OVER (ORDER BY sale_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS rows_sum,
    SUM(amount) OVER (ORDER BY sale_date RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS range_sum
FROM employee_sales
ORDER BY sale_date;

-- ============================================================================
-- SECTION 6: NAMED WINDOWS (WINDOW CLAUSE)
-- ============================================================================

-- Define window once, use multiple times
SELECT 
    employee_name,
    department,
    amount,
    SUM(amount) OVER dept_window AS dept_total,
    AVG(amount) OVER dept_window AS dept_avg,
    ROW_NUMBER() OVER dept_window AS dept_row
FROM employee_sales
WINDOW dept_window AS (PARTITION BY department ORDER BY amount DESC);

-- Multiple named windows
SELECT 
    sale_date,
    employee_name,
    amount,
    SUM(amount) OVER by_date AS running_total,
    RANK() OVER by_amount AS overall_rank,
    RANK() OVER by_emp_amount AS emp_rank
FROM employee_sales
WINDOW 
    by_date AS (ORDER BY sale_date),
    by_amount AS (ORDER BY amount DESC),
    by_emp_amount AS (PARTITION BY employee_id ORDER BY amount DESC);

-- ============================================================================
-- SECTION 7: PRACTICAL WINDOW FUNCTION APPLICATIONS
-- ============================================================================

-- Application 1: Sales Growth Analysis
SELECT 
    employee_name,
    sale_date,
    amount,
    LAG(amount) OVER (PARTITION BY employee_id ORDER BY sale_date) AS prev_sale,
    CASE 
        WHEN LAG(amount) OVER (PARTITION BY employee_id ORDER BY sale_date) IS NULL THEN 'First Sale'
        WHEN amount > LAG(amount) OVER (PARTITION BY employee_id ORDER BY sale_date) THEN 'Growth'
        WHEN amount < LAG(amount) OVER (PARTITION BY employee_id ORDER BY sale_date) THEN 'Decline'
        ELSE 'No Change'
    END AS trend
FROM employee_sales
ORDER BY employee_name, sale_date;

-- Application 2: Employee Performance Ranking
SELECT 
    employee_name,
    department,
    SUM(amount) AS total_sales,
    RANK() OVER (ORDER BY SUM(amount) DESC) AS company_rank,
    RANK() OVER (PARTITION BY department ORDER BY SUM(amount) DESC) AS dept_rank
FROM employee_sales
GROUP BY employee_id, employee_name, department
ORDER BY company_rank;

-- Application 3: Cumulative Distribution
SELECT 
    employee_name,
    amount,
    CUME_DIST() OVER (ORDER BY amount) AS cumulative_dist,
    PERCENT_RANK() OVER (ORDER BY amount) AS percent_rank
FROM employee_sales;

-- Application 4: Gap Analysis (days between sales)
SELECT 
    employee_name,
    sale_date,
    LAG(sale_date) OVER (PARTITION BY employee_id ORDER BY sale_date) AS prev_sale_date,
    DATEDIFF(sale_date, LAG(sale_date) OVER (PARTITION BY employee_id ORDER BY sale_date)) AS days_since_last
FROM employee_sales
ORDER BY employee_name, sale_date;

-- Application 5: Year-to-Date Running Totals
SELECT 
    sale_date,
    YEAR(sale_date) AS year,
    MONTH(sale_date) AS month,
    amount,
    SUM(amount) OVER (
        PARTITION BY YEAR(sale_date) 
        ORDER BY sale_date
    ) AS ytd_total
FROM employee_sales
ORDER BY sale_date;

-- Application 6: Moving Averages for Trend Analysis
SELECT 
    sale_date,
    amount,
    AVG(amount) OVER (ORDER BY sale_date ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ma_3,
    AVG(amount) OVER (ORDER BY sale_date ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS ma_5
FROM employee_sales
ORDER BY sale_date;

-- Application 7: Identifying Consecutive Events
SELECT 
    sale_date,
    employee_name,
    amount,
    ROW_NUMBER() OVER (ORDER BY sale_date) - 
    ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY sale_date) AS grp
FROM employee_sales
ORDER BY sale_date;

-- Application 8: Median Calculation (approximation)
SELECT DISTINCT
    department,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) OVER (PARTITION BY department) AS median_amount
FROM employee_sales;
-- Note: Syntax varies by database. MySQL uses different approach.

-- MySQL median approach
WITH ranked AS (
    SELECT 
        department,
        amount,
        ROW_NUMBER() OVER (PARTITION BY department ORDER BY amount) AS rn,
        COUNT(*) OVER (PARTITION BY department) AS cnt
    FROM employee_sales
)
SELECT 
    department,
    AVG(amount) AS median_amount
FROM ranked
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
GROUP BY department;

-- ============================================================================
-- SECTION 8: WINDOW FUNCTIONS VS ALTERNATIVES
-- ============================================================================

-- Compare approaches for running total:

-- 1. Correlated subquery (slow for large datasets)
SELECT 
    es1.sale_date,
    es1.amount,
    (SELECT SUM(es2.amount) 
     FROM employee_sales es2 
     WHERE es2.sale_date <= es1.sale_date) AS running_total
FROM employee_sales es1
ORDER BY es1.sale_date;

-- 2. Self-join (complex and slow)
SELECT 
    es1.sale_date,
    es1.amount,
    SUM(es2.amount) AS running_total
FROM employee_sales es1
JOIN employee_sales es2 ON es2.sale_date <= es1.sale_date
GROUP BY es1.sale_id, es1.sale_date, es1.amount
ORDER BY es1.sale_date;

-- 3. Window function (elegant and efficient!)
SELECT 
    sale_date,
    amount,
    SUM(amount) OVER (ORDER BY sale_date) AS running_total
FROM employee_sales
ORDER BY sale_date;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: For each sale, show:
- Employee name
- Sale amount
- Running total for that employee
- Running count for that employee
- Difference from employee's average

EXERCISE 2: Create a ranking report showing:
- Department
- Employee name
- Total sales
- Rank within department
- Overall company rank
- Percentage of department total

EXERCISE 3: Identify:
- Each employee's best and worst sale
- The gap between consecutive sales (in days)
- Whether each sale was above their personal average

EXERCISE 4: Calculate:
- 5-day moving average of sales
- 5-day moving minimum
- 5-day moving maximum
- Current value vs moving average percentage

EXERCISE 5: For each department:
- Show running total by date
- Year-over-year comparison (if applicable)
- Month-to-date subtotals
- Compare each sale to department average

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

