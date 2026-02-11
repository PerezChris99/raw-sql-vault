-- ============================================================================
-- SQL FUNDAMENTALS: THE ABSOLUTE BASICS
-- Module 01: Introduction to SQL
-- Goal: Master the foundation of all SQL operations
-- ============================================================================

-- ============================================================================
-- SECTION 1: WHAT IS SQL?
-- ============================================================================
/*
SQL (Structured Query Language) is the standard language for:
- Querying data from databases
- Inserting, updating, and deleting data
- Creating and modifying database structures
- Controlling access to data

Key SQL Categories:
1. DDL (Data Definition Language) - CREATE, ALTER, DROP, TRUNCATE
2. DML (Data Manipulation Language) - SELECT, INSERT, UPDATE, DELETE
3. DCL (Data Control Language) - GRANT, REVOKE
4. TCL (Transaction Control Language) - COMMIT, ROLLBACK, SAVEPOINT
*/

-- ============================================================================
-- SECTION 2: CREATING YOUR FIRST DATABASE AND TABLE
-- ============================================================================

-- Create a database
CREATE DATABASE uganda_business;

-- Use the database
USE uganda_business;

-- Create your first table
CREATE TABLE employees (
    employee_id INT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE,
    hire_date DATE,
    salary DECIMAL(10, 2),
    department VARCHAR(50)
);

-- ============================================================================
-- SECTION 3: INSERTING DATA
-- ============================================================================

-- Insert a single row
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, salary, department)
VALUES (1, 'John', 'Mukasa', 'john.mukasa@company.ug', '2024-01-15', 2500000.00, 'Engineering');

-- Insert multiple rows at once
INSERT INTO employees (employee_id, first_name, last_name, email, hire_date, salary, department)
VALUES 
    (2, 'Sarah', 'Namulondo', 'sarah.n@company.ug', '2024-02-01', 2800000.00, 'Marketing'),
    (3, 'Peter', 'Okello', 'peter.o@company.ug', '2024-01-20', 3200000.00, 'Engineering'),
    (4, 'Grace', 'Achieng', 'grace.a@company.ug', '2024-03-10', 2200000.00, 'HR'),
    (5, 'David', 'Ssempijja', 'david.s@company.ug', '2024-02-15', 4500000.00, 'Management');

-- ============================================================================
-- SECTION 4: BASIC SELECT QUERIES
-- ============================================================================

-- Select all columns from a table
SELECT * FROM employees;

-- Select specific columns
SELECT first_name, last_name, salary FROM employees;

-- Select with column aliases
SELECT 
    first_name AS "First Name",
    last_name AS "Last Name",
    salary AS "Monthly Salary (UGX)"
FROM employees;

-- ============================================================================
-- SECTION 5: FILTERING DATA WITH WHERE
-- ============================================================================

-- Basic WHERE clause
SELECT * FROM employees WHERE department = 'Engineering';

-- Comparison operators: =, <>, !=, <, >, <=, >=
SELECT * FROM employees WHERE salary > 2500000;
SELECT * FROM employees WHERE salary >= 2500000;
SELECT * FROM employees WHERE salary < 3000000;
SELECT * FROM employees WHERE salary <> 2500000;

-- BETWEEN operator (inclusive)
SELECT * FROM employees WHERE salary BETWEEN 2000000 AND 3000000;

-- IN operator
SELECT * FROM employees WHERE department IN ('Engineering', 'Marketing');

-- LIKE operator for pattern matching
SELECT * FROM employees WHERE first_name LIKE 'J%';     -- Starts with J
SELECT * FROM employees WHERE last_name LIKE '%a';      -- Ends with a
SELECT * FROM employees WHERE email LIKE '%@company%';  -- Contains @company
SELECT * FROM employees WHERE first_name LIKE '_o%';    -- Second character is 'o'

-- NULL checks
SELECT * FROM employees WHERE email IS NULL;
SELECT * FROM employees WHERE email IS NOT NULL;

-- ============================================================================
-- SECTION 6: LOGICAL OPERATORS
-- ============================================================================

-- AND operator
SELECT * FROM employees 
WHERE department = 'Engineering' AND salary > 2500000;

-- OR operator
SELECT * FROM employees 
WHERE department = 'Engineering' OR department = 'Marketing';

-- NOT operator
SELECT * FROM employees WHERE NOT department = 'HR';

-- Combining operators (use parentheses for clarity)
SELECT * FROM employees 
WHERE (department = 'Engineering' OR department = 'Marketing')
  AND salary > 2500000;

-- ============================================================================
-- SECTION 7: SORTING RESULTS WITH ORDER BY
-- ============================================================================

-- Sort ascending (default)
SELECT * FROM employees ORDER BY salary;
SELECT * FROM employees ORDER BY salary ASC;

-- Sort descending
SELECT * FROM employees ORDER BY salary DESC;

-- Sort by multiple columns
SELECT * FROM employees ORDER BY department ASC, salary DESC;

-- Sort by column position (not recommended for production)
SELECT first_name, last_name, salary FROM employees ORDER BY 3 DESC;

-- ============================================================================
-- SECTION 8: LIMITING RESULTS
-- ============================================================================

-- MySQL/PostgreSQL syntax
SELECT * FROM employees ORDER BY salary DESC LIMIT 3;

-- SQL Server syntax
SELECT TOP 3 * FROM employees ORDER BY salary DESC;

-- OFFSET for pagination (skip first 2, get next 3)
SELECT * FROM employees ORDER BY salary DESC LIMIT 3 OFFSET 2;

-- ============================================================================
-- SECTION 9: UPDATING DATA
-- ============================================================================

-- Update single column
UPDATE employees SET salary = 2700000 WHERE employee_id = 1;

-- Update multiple columns
UPDATE employees 
SET salary = 3000000, department = 'Senior Engineering' 
WHERE employee_id = 3;

-- Update with calculation
UPDATE employees SET salary = salary * 1.10 WHERE department = 'Engineering';

-- CAUTION: Always use WHERE clause to avoid updating all rows!
-- This would update ALL employees: UPDATE employees SET salary = 0;

-- ============================================================================
-- SECTION 10: DELETING DATA
-- ============================================================================

-- Delete specific rows
DELETE FROM employees WHERE employee_id = 5;

-- Delete with multiple conditions
DELETE FROM employees WHERE department = 'HR' AND salary < 2000000;

-- CAUTION: Always use WHERE clause to avoid deleting all rows!
-- This would delete ALL employees: DELETE FROM employees;

-- TRUNCATE removes all rows (faster than DELETE, cannot be rolled back easily)
-- TRUNCATE TABLE employees;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Create a table called 'products' with these columns:
- product_id (INT, PRIMARY KEY)
- product_name (VARCHAR(100), NOT NULL)
- price (DECIMAL(10,2))
- stock_quantity (INT)
- category (VARCHAR(50))

EXERCISE 2: Insert 5 products into the table

EXERCISE 3: Write queries to:
a) Select all products priced over 50000 UGX
b) Select products in 'Electronics' category sorted by price descending
c) Select products with stock less than 10
d) Update the price of product_id 1 to 75000
e) Delete products with 0 stock

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

