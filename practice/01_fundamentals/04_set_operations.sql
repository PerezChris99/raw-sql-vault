-- ============================================================================
-- SQL SET OPERATIONS: UNION, INTERSECT, EXCEPT
-- Module 07: Combining Query Results
-- Goal: Master techniques for combining results from multiple queries
-- ============================================================================

-- ============================================================================
-- SETUP: SAMPLE TABLES
-- ============================================================================

-- Current employees
CREATE TABLE current_employees (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(100),
    department VARCHAR(50),
    salary DECIMAL(12, 2),
    hire_date DATE
);

-- Former employees
CREATE TABLE former_employees (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(100),
    department VARCHAR(50),
    last_salary DECIMAL(12, 2),
    termination_date DATE
);

-- Kampala branch customers
CREATE TABLE kampala_customers (
    customer_id INT,
    customer_name VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(100)
);

-- Jinja branch customers
CREATE TABLE jinja_customers (
    customer_id INT,
    customer_name VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(100)
);

-- Insert sample data
INSERT INTO current_employees VALUES
(1, 'John Mukasa', 'Engineering', 5000000, '2020-01-15'),
(2, 'Sarah Nalwoga', 'Marketing', 4500000, '2020-03-20'),
(3, 'Peter Okello', 'Engineering', 4000000, '2021-06-10'),
(4, 'Grace Auma', 'Finance', 4200000, '2022-01-05'),
(5, 'David Ssempijja', 'Engineering', 3800000, '2023-02-15');

INSERT INTO former_employees VALUES
(101, 'James Ochieng', 'Engineering', 4500000, '2023-06-30'),
(102, 'Mary Atim', 'Marketing', 3800000, '2022-12-15'),
(2, 'Sarah Nalwoga', 'Sales', 3500000, '2019-09-30'), -- Rejoined!
(103, 'Robert Kato', 'Finance', 4000000, '2023-03-01');

INSERT INTO kampala_customers VALUES
(1, 'Uganda Traders Ltd', '+256700111111', 'info@ugatraders.ug'),
(2, 'Nakasero Supplies', '+256700222222', 'sales@nakasero.ug'),
(3, 'Kampala Motors', '+256700333333', 'contact@kmotors.ug'),
(4, 'City Pharmacy', '+256700444444', 'orders@citypharm.ug');

INSERT INTO jinja_customers VALUES
(2, 'Nakasero Supplies', '+256700222222', 'sales@nakasero.ug'), -- Same customer!
(5, 'Jinja Steel Works', '+256700555555', 'info@jinjasteel.ug'),
(6, 'Source of Nile Hotel', '+256700666666', 'reservations@snh.ug'),
(7, 'Owen Falls Power', '+256700777777', 'procurement@ofp.ug');

-- ============================================================================
-- SECTION 1: UNION - COMBINING RESULTS (REMOVE DUPLICATES)
-- ============================================================================

/*
UNION:
- Combines results from multiple SELECT statements
- Removes duplicate rows
- Column count and data types must match
- Column names from FIRST query are used
*/

-- Basic UNION
SELECT emp_name, department FROM current_employees
UNION
SELECT emp_name, department FROM former_employees;

-- All customers from both branches (no duplicates)
SELECT customer_id, customer_name, phone FROM kampala_customers
UNION
SELECT customer_id, customer_name, phone FROM jinja_customers;

-- UNION with different column names (first query names are used)
SELECT emp_name AS person_name, salary AS amount FROM current_employees
UNION
SELECT emp_name, last_salary FROM former_employees;

-- UNION with ORDER BY (applies to entire result)
SELECT emp_name, department, 'Current' AS status FROM current_employees
UNION
SELECT emp_name, department, 'Former' AS status FROM former_employees
ORDER BY emp_name;

-- ============================================================================
-- SECTION 2: UNION ALL - KEEP ALL ROWS (INCLUDING DUPLICATES)
-- ============================================================================

/*
UNION ALL:
- Keeps ALL rows including duplicates
- Faster than UNION (no duplicate checking)
- Use when you know there are no duplicates or want them
*/

-- Count difference: UNION vs UNION ALL
SELECT 'UNION' AS type, COUNT(*) AS count FROM (
    SELECT customer_id FROM kampala_customers
    UNION
    SELECT customer_id FROM jinja_customers
) AS u

UNION ALL

SELECT 'UNION ALL' AS type, COUNT(*) AS count FROM (
    SELECT customer_id FROM kampala_customers
    UNION ALL
    SELECT customer_id FROM jinja_customers
) AS ua;

-- Use UNION ALL for reporting (want to see all transactions)
SELECT 'Kampala' AS branch, customer_name, phone FROM kampala_customers
UNION ALL
SELECT 'Jinja' AS branch, customer_name, phone FROM jinja_customers
ORDER BY customer_name;

-- Combining multiple queries
SELECT product_name, 'Premium' AS tier, price FROM products WHERE price > 3000000
UNION ALL
SELECT product_name, 'Standard' AS tier, price FROM products WHERE price BETWEEN 1000000 AND 3000000
UNION ALL
SELECT product_name, 'Budget' AS tier, price FROM products WHERE price < 1000000;

-- ============================================================================
-- SECTION 3: INTERSECT - COMMON ROWS ONLY
-- ============================================================================

/*
INTERSECT:
- Returns rows that appear in BOTH queries
- Removes duplicates
- MySQL doesn't support directly; use INNER JOIN or EXISTS
*/

-- PostgreSQL/SQL Server syntax:
/*
SELECT customer_id, customer_name FROM kampala_customers
INTERSECT
SELECT customer_id, customer_name FROM jinja_customers;
*/

-- MySQL alternative using INNER JOIN
SELECT k.customer_id, k.customer_name
FROM kampala_customers k
INNER JOIN jinja_customers j 
    ON k.customer_id = j.customer_id 
    AND k.customer_name = j.customer_name;

-- MySQL alternative using EXISTS
SELECT customer_id, customer_name FROM kampala_customers k
WHERE EXISTS (
    SELECT 1 FROM jinja_customers j 
    WHERE j.customer_id = k.customer_id 
    AND j.customer_name = k.customer_name
);

-- MySQL alternative using IN
SELECT customer_id, customer_name FROM kampala_customers
WHERE (customer_id, customer_name) IN (
    SELECT customer_id, customer_name FROM jinja_customers
);

-- Find employees who were former and are now current
SELECT ce.emp_id, ce.emp_name
FROM current_employees ce
INNER JOIN former_employees fe ON ce.emp_id = fe.emp_id;

-- ============================================================================
-- SECTION 4: EXCEPT / MINUS - ROWS IN FIRST BUT NOT SECOND
-- ============================================================================

/*
EXCEPT (SQL Server/PostgreSQL) / MINUS (Oracle):
- Returns rows in first query that don't appear in second
- MySQL doesn't support directly; use LEFT JOIN or NOT EXISTS
*/

-- PostgreSQL/SQL Server syntax:
/*
SELECT customer_id, customer_name FROM kampala_customers
EXCEPT
SELECT customer_id, customer_name FROM jinja_customers;
*/

-- MySQL alternative using LEFT JOIN
SELECT k.customer_id, k.customer_name
FROM kampala_customers k
LEFT JOIN jinja_customers j 
    ON k.customer_id = j.customer_id 
    AND k.customer_name = j.customer_name
WHERE j.customer_id IS NULL;

-- MySQL alternative using NOT EXISTS
SELECT customer_id, customer_name FROM kampala_customers k
WHERE NOT EXISTS (
    SELECT 1 FROM jinja_customers j 
    WHERE j.customer_id = k.customer_id 
    AND j.customer_name = k.customer_name
);

-- MySQL alternative using NOT IN
SELECT customer_id, customer_name FROM kampala_customers
WHERE (customer_id, customer_name) NOT IN (
    SELECT customer_id, customer_name FROM jinja_customers
);

-- Customers only in Kampala
SELECT k.customer_id, k.customer_name, 'Kampala Only' AS location
FROM kampala_customers k
LEFT JOIN jinja_customers j ON k.customer_id = j.customer_id
WHERE j.customer_id IS NULL;

-- ============================================================================
-- SECTION 5: COMBINING MULTIPLE SET OPERATIONS
-- ============================================================================

-- Complex combination
(
    SELECT customer_id, customer_name, 'Kampala' AS branch FROM kampala_customers
    UNION
    SELECT customer_id, customer_name, 'Jinja' AS branch FROM jinja_customers
)
ORDER BY customer_name;

-- Finding exclusive and shared customers
SELECT 
    customer_id,
    customer_name,
    CASE 
        WHEN in_kampala = 1 AND in_jinja = 1 THEN 'Both Branches'
        WHEN in_kampala = 1 THEN 'Kampala Only'
        ELSE 'Jinja Only'
    END AS branch_status
FROM (
    SELECT 
        customer_id,
        customer_name,
        MAX(CASE WHEN branch = 'Kampala' THEN 1 ELSE 0 END) AS in_kampala,
        MAX(CASE WHEN branch = 'Jinja' THEN 1 ELSE 0 END) AS in_jinja
    FROM (
        SELECT customer_id, customer_name, 'Kampala' AS branch FROM kampala_customers
        UNION ALL
        SELECT customer_id, customer_name, 'Jinja' AS branch FROM jinja_customers
    ) all_customers
    GROUP BY customer_id, customer_name
) categorized;

-- ============================================================================
-- SECTION 6: SET OPERATIONS WITH AGGREGATION
-- ============================================================================

-- Union of aggregated results
SELECT 
    'Current Employees' AS category,
    department,
    COUNT(*) AS count,
    AVG(salary) AS avg_salary
FROM current_employees
GROUP BY department

UNION ALL

SELECT 
    'Former Employees' AS category,
    department,
    COUNT(*) AS count,
    AVG(last_salary) AS avg_salary
FROM former_employees
GROUP BY department

ORDER BY department, category;

-- Comparison report
WITH 
kampala_summary AS (
    SELECT COUNT(*) AS count FROM kampala_customers
),
jinja_summary AS (
    SELECT COUNT(*) AS count FROM jinja_customers
),
overlap AS (
    SELECT COUNT(*) AS count
    FROM kampala_customers k
    INNER JOIN jinja_customers j ON k.customer_id = j.customer_id
)
SELECT 'Kampala Customers' AS metric, count FROM kampala_summary
UNION ALL
SELECT 'Jinja Customers', count FROM jinja_summary
UNION ALL
SELECT 'Customers in Both', count FROM overlap
UNION ALL
SELECT 'Unique Customers', 
       (SELECT count FROM kampala_summary) + 
       (SELECT count FROM jinja_summary) - 
       (SELECT count FROM overlap);

-- ============================================================================
-- SECTION 7: PRACTICAL APPLICATIONS
-- ============================================================================

-- Application 1: Merged contact list
CREATE VIEW all_contacts AS
SELECT 
    'Employee' AS contact_type,
    emp_name AS name,
    department AS organization
FROM current_employees

UNION

SELECT 
    'Customer',
    customer_name,
    'Kampala Branch'
FROM kampala_customers

UNION

SELECT 
    'Customer',
    customer_name,
    'Jinja Branch'
FROM jinja_customers;

-- Application 2: Historical record tracking
CREATE VIEW employee_history AS
SELECT 
    emp_id,
    emp_name,
    department,
    salary AS current_salary,
    NULL AS previous_salary,
    hire_date AS start_date,
    NULL AS end_date,
    'Active' AS status
FROM current_employees

UNION ALL

SELECT 
    emp_id,
    emp_name,
    department,
    NULL,
    last_salary,
    NULL,
    termination_date,
    'Terminated'
FROM former_employees
WHERE emp_id NOT IN (SELECT emp_id FROM current_employees);

-- Application 3: Data validation - Find mismatches
-- Products in inventory but not in catalog
SELECT product_id, 'In Inventory, Not in Catalog' AS issue
FROM inventory
WHERE product_id NOT IN (SELECT product_id FROM products)

UNION ALL

-- Products in catalog but not in inventory
SELECT product_id, 'In Catalog, Not in Inventory' AS issue
FROM products
WHERE product_id NOT IN (SELECT product_id FROM inventory);

-- Application 4: Period comparison
SELECT 
    'Q1 2024' AS period,
    category,
    SUM(total_amount) AS revenue
FROM sales
WHERE sale_date BETWEEN '2024-01-01' AND '2024-03-31'
GROUP BY category

UNION ALL

SELECT 
    'Q4 2023' AS period,
    category,
    SUM(total_amount) AS revenue
FROM sales
WHERE sale_date BETWEEN '2023-10-01' AND '2023-12-31'
GROUP BY category

ORDER BY category, period;

-- ============================================================================
-- SECTION 8: RULES AND BEST PRACTICES
-- ============================================================================

/*
RULES FOR SET OPERATIONS:

1. Same number of columns in all queries
2. Compatible data types in corresponding columns
3. ORDER BY appears only once, at the end
4. Column names from FIRST query are used
5. UNION removes duplicates; UNION ALL keeps them

BEST PRACTICES:

1. Use UNION ALL when possible (better performance)
2. Add a source column to identify where rows came from
3. Be explicit about column selection (avoid SELECT *)
4. Use CTEs for complex set operations
5. Consider views for frequently used combinations
6. In MySQL, simulate INTERSECT/EXCEPT with joins or EXISTS
*/

-- Example: Clear source identification
SELECT 
    'Source: Kampala DB' AS data_source,
    customer_id,
    customer_name,
    phone,
    NOW() AS query_timestamp
FROM kampala_customers

UNION ALL

SELECT 
    'Source: Jinja DB',
    customer_id,
    customer_name,
    phone,
    NOW()
FROM jinja_customers;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Using the employee tables:
a) Find all unique people who have ever worked here (current + former)
b) Find people who are in both tables (rehires)
c) Find former employees who haven't returned

EXERCISE 2: Create a report comparing:
- Number of customers in each branch
- Customers exclusive to each branch
- Customers shared between branches

EXERCISE 3: Write a query that mimics INTERSECT in MySQL to find
products that have been ordered by customers from BOTH Kampala and Jinja

EXERCISE 4: Create a unified audit log combining:
- Order creations
- Order updates
- Order cancellations
Each with appropriate status column and timestamp

EXERCISE 5: Build a "before and after" comparison:
- Show employees' salaries now vs. their last salary when they were former
- Only for employees who left and came back

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

