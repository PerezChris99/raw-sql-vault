-- ============================================================================
-- SQL JOINS: COMBINING DATA FROM MULTIPLE TABLES
-- Module 04: Mastering All Types of Joins
-- Goal: Expert-level understanding of relational data combination
-- ============================================================================

-- ============================================================================
-- SETUP: CREATE SAMPLE TABLES
-- ============================================================================

-- Departments table
CREATE TABLE departments (
    dept_id INT PRIMARY KEY,
    dept_name VARCHAR(50) NOT NULL,
    location VARCHAR(50)
);

INSERT INTO departments VALUES
(1, 'Engineering', 'Kampala'),
(2, 'Marketing', 'Kampala'),
(3, 'Finance', 'Entebbe'),
(4, 'HR', 'Kampala'),
(5, 'Operations', 'Jinja');  -- No employees in this dept

-- Employees table
CREATE TABLE employees (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(100) NOT NULL,
    salary DECIMAL(12, 2),
    dept_id INT,
    manager_id INT,
    hire_date DATE
);

INSERT INTO employees VALUES
(1, 'John Mukasa', 5000000, 1, NULL, '2020-01-15'),
(2, 'Sarah Nalwoga', 4500000, 1, 1, '2020-03-20'),
(3, 'Peter Okello', 4000000, 2, 1, '2020-06-10'),
(4, 'Grace Auma', 3500000, 2, 3, '2021-01-05'),
(5, 'David Ssempijja', 6000000, 3, NULL, '2019-05-12'),
(6, 'Rose Nakato', 3800000, 1, 2, '2021-08-15'),
(7, 'James Ochieng', 4200000, NULL, 1, '2022-02-01'),  -- No department assigned
(8, 'Mary Atim', 3200000, 4, 5, '2022-06-20');

-- Projects table
CREATE TABLE projects (
    project_id INT PRIMARY KEY,
    project_name VARCHAR(100),
    dept_id INT,
    budget DECIMAL(15, 2),
    start_date DATE
);

INSERT INTO projects VALUES
(101, 'Mobile App Development', 1, 50000000, '2023-01-01'),
(102, 'Brand Campaign', 2, 30000000, '2023-03-15'),
(103, 'Financial System Upgrade', 3, 80000000, '2023-06-01'),
(104, 'Website Redesign', 1, 25000000, '2023-09-01');

-- Employee-Project assignments (many-to-many)
CREATE TABLE project_assignments (
    emp_id INT,
    project_id INT,
    role VARCHAR(50),
    hours_allocated INT,
    PRIMARY KEY (emp_id, project_id)
);

INSERT INTO project_assignments VALUES
(1, 101, 'Lead Developer', 40),
(2, 101, 'Developer', 40),
(6, 101, 'Developer', 30),
(1, 104, 'Technical Lead', 20),
(3, 102, 'Campaign Manager', 35),
(4, 102, 'Content Creator', 40),
(5, 103, 'Project Manager', 40);

-- ============================================================================
-- SECTION 1: INNER JOIN
-- ============================================================================

/*
INNER JOIN:
- Returns only rows that have matching values in BOTH tables
- Most common type of join
- Also called simply "JOIN"
*/

-- Basic INNER JOIN syntax
SELECT 
    e.emp_id,
    e.emp_name,
    d.dept_name,
    d.location
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id;

-- Alternative syntax (implicit join - older style, not recommended)
SELECT e.emp_id, e.emp_name, d.dept_name
FROM employees e, departments d
WHERE e.dept_id = d.dept_id;

-- INNER JOIN with additional conditions
SELECT 
    e.emp_name,
    e.salary,
    d.dept_name
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id
WHERE e.salary > 4000000;

-- Join on multiple conditions
SELECT 
    e.emp_name,
    d.dept_name
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id 
                        AND d.location = 'Kampala';

-- ============================================================================
-- SECTION 2: LEFT JOIN (LEFT OUTER JOIN)
-- ============================================================================

/*
LEFT JOIN:
- Returns ALL rows from left table
- Matching rows from right table (NULL if no match)
- Useful for finding records with or without related data
*/

-- Basic LEFT JOIN
SELECT 
    e.emp_id,
    e.emp_name,
    d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id;
-- Notice: James Ochieng appears with NULL dept_name (no department assigned)

-- Find employees WITHOUT a department
SELECT 
    e.emp_id,
    e.emp_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE d.dept_id IS NULL;

-- Count employees per department (including depts with zero employees)
SELECT 
    d.dept_name,
    COUNT(e.emp_id) AS employee_count
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY employee_count DESC;

-- ============================================================================
-- SECTION 3: RIGHT JOIN (RIGHT OUTER JOIN)
-- ============================================================================

/*
RIGHT JOIN:
- Returns ALL rows from right table
- Matching rows from left table (NULL if no match)
- Less common; usually rewritten as LEFT JOIN
*/

-- Basic RIGHT JOIN
SELECT 
    e.emp_name,
    d.dept_id,
    d.dept_name
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id;
-- Notice: Operations dept appears with NULL emp_name (no employees)

-- Equivalent LEFT JOIN (preferred)
SELECT 
    e.emp_name,
    d.dept_id,
    d.dept_name
FROM departments d
LEFT JOIN employees e ON e.dept_id = d.dept_id;

-- Find departments with no employees
SELECT 
    d.dept_name
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL;

-- ============================================================================
-- SECTION 4: FULL OUTER JOIN
-- ============================================================================

/*
FULL OUTER JOIN:
- Returns ALL rows from BOTH tables
- NULL where no match exists on either side
- MySQL doesn't support directly; use UNION of LEFT and RIGHT
*/

-- Full outer join (MySQL workaround using UNION)
SELECT 
    e.emp_name,
    d.dept_name
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id

UNION

SELECT 
    e.emp_name,
    d.dept_name
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id;

-- PostgreSQL/SQL Server syntax (native support)
/*
SELECT 
    e.emp_name,
    d.dept_name
FROM employees e
FULL OUTER JOIN departments d ON e.dept_id = d.dept_id;
*/

-- Find unmatched records from both sides
SELECT 
    e.emp_name,
    d.dept_name,
    CASE 
        WHEN e.emp_id IS NULL THEN 'Department without employees'
        WHEN d.dept_id IS NULL THEN 'Employee without department'
        ELSE 'Matched'
    END AS match_status
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id

UNION

SELECT 
    e.emp_name,
    d.dept_name,
    CASE 
        WHEN e.emp_id IS NULL THEN 'Department without employees'
        WHEN d.dept_id IS NULL THEN 'Employee without department'
        ELSE 'Matched'
    END AS match_status
FROM employees e
RIGHT JOIN departments d ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL;

-- ============================================================================
-- SECTION 5: CROSS JOIN (CARTESIAN PRODUCT)
-- ============================================================================

/*
CROSS JOIN:
- Returns every combination of rows from both tables
- No ON clause needed
- Result size = rows in table A × rows in table B
- Use carefully - can create very large result sets!
*/

-- Basic CROSS JOIN
SELECT 
    e.emp_name,
    p.project_name
FROM employees e
CROSS JOIN projects p;

-- Useful application: Generate all date-product combinations for reporting
-- (Creates a row for every day for every product, even if no sales)

-- Cross join with filtering (same as inner join)
SELECT 
    e.emp_name,
    d.dept_name
FROM employees e
CROSS JOIN departments d
WHERE e.dept_id = d.dept_id;

-- ============================================================================
-- SECTION 6: SELF JOIN
-- ============================================================================

/*
SELF JOIN:
- Joins a table to itself
- Must use table aliases to distinguish the two instances
- Common use: Finding relationships within same table (managers, hierarchies)
*/

-- Find employees and their managers
SELECT 
    e.emp_name AS employee,
    m.emp_name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id;

-- Find employees who earn more than their manager
SELECT 
    e.emp_name AS employee,
    e.salary AS emp_salary,
    m.emp_name AS manager,
    m.salary AS mgr_salary
FROM employees e
INNER JOIN employees m ON e.manager_id = m.emp_id
WHERE e.salary > m.salary;

-- Find peers (employees with same manager)
SELECT 
    e1.emp_name AS employee1,
    e2.emp_name AS employee2,
    m.emp_name AS shared_manager
FROM employees e1
INNER JOIN employees e2 ON e1.manager_id = e2.manager_id 
                       AND e1.emp_id < e2.emp_id  -- Avoid duplicates
INNER JOIN employees m ON e1.manager_id = m.emp_id;

-- ============================================================================
-- SECTION 7: MULTIPLE TABLE JOINS
-- ============================================================================

-- Join three tables
SELECT 
    e.emp_name,
    d.dept_name,
    p.project_name,
    pa.role
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id
INNER JOIN project_assignments pa ON e.emp_id = pa.emp_id
INNER JOIN projects p ON pa.project_id = p.project_id;

-- Mix of join types
SELECT 
    e.emp_name,
    d.dept_name,
    COALESCE(p.project_name, 'No Project') AS project
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
LEFT JOIN project_assignments pa ON e.emp_id = pa.emp_id
LEFT JOIN projects p ON pa.project_id = p.project_id
ORDER BY e.emp_name;

-- Complex join with aggregation
SELECT 
    d.dept_name,
    COUNT(DISTINCT e.emp_id) AS total_employees,
    COUNT(DISTINCT pa.project_id) AS active_projects,
    SUM(e.salary) AS total_salary_budget,
    SUM(p.budget) AS total_project_budget
FROM departments d
LEFT JOIN employees e ON d.dept_id = e.dept_id
LEFT JOIN project_assignments pa ON e.emp_id = pa.emp_id
LEFT JOIN projects p ON pa.project_id = p.project_id
GROUP BY d.dept_id, d.dept_name;

-- ============================================================================
-- SECTION 8: JOIN WITH SUBQUERIES
-- ============================================================================

-- Join with derived table (subquery in FROM)
SELECT 
    e.emp_name,
    e.salary,
    dept_avgs.avg_salary,
    e.salary - dept_avgs.avg_salary AS diff_from_avg
FROM employees e
INNER JOIN (
    SELECT dept_id, AVG(salary) AS avg_salary
    FROM employees
    GROUP BY dept_id
) AS dept_avgs ON e.dept_id = dept_avgs.dept_id;

-- Join with CTE (cleaner syntax)
WITH dept_stats AS (
    SELECT 
        dept_id,
        AVG(salary) AS avg_salary,
        MAX(salary) AS max_salary,
        MIN(salary) AS min_salary
    FROM employees
    GROUP BY dept_id
)
SELECT 
    e.emp_name,
    e.salary,
    ds.avg_salary,
    ds.max_salary,
    CASE 
        WHEN e.salary = ds.max_salary THEN 'Highest in Dept'
        WHEN e.salary > ds.avg_salary THEN 'Above Average'
        ELSE 'At or Below Average'
    END AS salary_status
FROM employees e
INNER JOIN dept_stats ds ON e.dept_id = ds.dept_id;

-- ============================================================================
-- SECTION 9: NON-EQUI JOINS
-- ============================================================================

/*
Non-equi joins use operators other than = in the join condition
Examples: <, >, <=, >=, <>, BETWEEN
*/

-- Salary grades table
CREATE TABLE salary_grades (
    grade CHAR(1) PRIMARY KEY,
    min_salary DECIMAL(12, 2),
    max_salary DECIMAL(12, 2)
);

INSERT INTO salary_grades VALUES
('A', 5000001, 10000000),
('B', 4000001, 5000000),
('C', 3000001, 4000000),
('D', 0, 3000000);

-- Assign salary grades using non-equi join
SELECT 
    e.emp_name,
    e.salary,
    g.grade AS salary_grade
FROM employees e
INNER JOIN salary_grades g 
    ON e.salary BETWEEN g.min_salary AND g.max_salary;

-- Find employees hired before others
SELECT 
    e1.emp_name AS senior_employee,
    e1.hire_date,
    e2.emp_name AS junior_employee,
    e2.hire_date
FROM employees e1
INNER JOIN employees e2 ON e1.hire_date < e2.hire_date
                       AND e1.dept_id = e2.dept_id  -- Same department
ORDER BY e1.emp_name, e2.hire_date;

-- ============================================================================
-- SECTION 10: USING CLAUSE AND NATURAL JOIN
-- ============================================================================

-- USING clause (when column names are identical)
SELECT 
    e.emp_name,
    d.dept_name
FROM employees e
INNER JOIN departments d USING (dept_id);
-- Equivalent to: ON e.dept_id = d.dept_id

-- NATURAL JOIN (automatically joins on columns with same names)
-- Use with caution - can be unpredictable!
SELECT 
    emp_name,
    dept_name
FROM employees
NATURAL JOIN departments;

-- ============================================================================
-- SECTION 11: ANTI-JOINS AND SEMI-JOINS
-- ============================================================================

-- Anti-join: Find rows in A that have NO match in B
-- Method 1: LEFT JOIN with NULL check
SELECT e.*
FROM employees e
LEFT JOIN project_assignments pa ON e.emp_id = pa.emp_id
WHERE pa.emp_id IS NULL;  -- Employees with no projects

-- Method 2: NOT EXISTS (often more efficient)
SELECT e.*
FROM employees e
WHERE NOT EXISTS (
    SELECT 1 FROM project_assignments pa 
    WHERE pa.emp_id = e.emp_id
);

-- Method 3: NOT IN
SELECT * FROM employees
WHERE emp_id NOT IN (
    SELECT DISTINCT emp_id FROM project_assignments
);

-- Semi-join: Find rows in A that have at least one match in B
-- (Return only columns from A, unlike INNER JOIN)
SELECT DISTINCT e.*
FROM employees e
INNER JOIN project_assignments pa ON e.emp_id = pa.emp_id;

-- Cleaner with EXISTS
SELECT e.*
FROM employees e
WHERE EXISTS (
    SELECT 1 FROM project_assignments pa 
    WHERE pa.emp_id = e.emp_id
);

-- ============================================================================
-- SECTION 12: JOIN PERFORMANCE TIPS
-- ============================================================================

/*
PERFORMANCE BEST PRACTICES:

1. ALWAYS index foreign key columns
   CREATE INDEX idx_emp_dept ON employees(dept_id);

2. Use INNER JOIN when you only need matched rows

3. Start with the smallest table or most filtered result

4. Avoid SELECT * - only select needed columns

5. Push WHERE conditions as early as possible

6. Use EXPLAIN to analyze query execution plan
   EXPLAIN SELECT ... FROM ... JOIN ...;

7. Consider denormalization for read-heavy workloads

8. Use covering indexes for frequently joined columns
*/

-- Example: Analyzing join performance
EXPLAIN SELECT 
    e.emp_name,
    d.dept_name
FROM employees e
INNER JOIN departments d ON e.dept_id = d.dept_id;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Write queries to:
a) List all employees with their department and project names
b) Find departments that have no projects
c) Find employees who work on the same projects
d) List employees and count of projects they're assigned to (including zero)

EXERCISE 2: Create a report showing:
- Employee name
- Manager name (or 'No Manager')
- Department name (or 'Unassigned')
- Total hours on all projects (or 0)
- List of project names (comma-separated)

EXERCISE 3: Find pairs of employees where:
- They work in the same department
- One earns more than double the other's salary

EXERCISE 4: Generate an organization chart showing:
- Employee hierarchy (who reports to whom)
- Department of each employee
- Total team salary for each manager

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

