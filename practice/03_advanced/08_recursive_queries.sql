-- ============================================================================
-- SQL RECURSIVE QUERIES AND HIERARCHICAL DATA
-- Module 19: Processing Trees, Graphs, and Self-Referential Structures
-- Goal: Master recursive CTEs for complex data relationships
-- ============================================================================

-- ============================================================================
-- SECTION 1: RECURSIVE CTE FUNDAMENTALS
-- ============================================================================

/*
RECURSIVE CTEs consist of:
1. Anchor member: Base case (non-recursive)
2. Recursive member: Self-referencing query
3. Termination: When no more rows returned

Structure:
WITH RECURSIVE cte_name AS (
    -- Anchor member
    SELECT ...
    UNION ALL
    -- Recursive member
    SELECT ... FROM cte_name WHERE ...
)
SELECT * FROM cte_name;
*/

-- Setup: Employee hierarchy table
CREATE TABLE employees_org (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(100),
    title VARCHAR(100),
    manager_id INT,
    salary DECIMAL(12,2),
    FOREIGN KEY (manager_id) REFERENCES employees_org(emp_id)
);

INSERT INTO employees_org VALUES
(1, 'Sarah Nakato', 'CEO', NULL, 15000000),
(2, 'John Ochieng', 'VP Operations', 1, 10000000),
(3, 'Mary Namukasa', 'VP Sales', 1, 10000000),
(4, 'Peter Kizza', 'Operations Manager', 2, 6000000),
(5, 'Jane Auma', 'Sales Manager - Kampala', 3, 6000000),
(6, 'David Ssempala', 'Sales Manager - Eastern', 3, 5500000),
(7, 'Alice Namutebi', 'Team Lead', 4, 4000000),
(8, 'Bob Mukasa', 'Senior Sales Rep', 5, 3500000),
(9, 'Carol Atim', 'Sales Rep', 5, 2500000),
(10, 'Dan Okello', 'Sales Rep', 6, 2500000),
(11, 'Eve Nakimera', 'Operations Staff', 7, 2000000),
(12, 'Frank Tumusiime', 'Operations Staff', 7, 2000000);

-- ============================================================================
-- SECTION 2: TRAVERSING HIERARCHIES
-- ============================================================================

-- Get all subordinates (downward traversal)
WITH RECURSIVE subordinates AS (
    -- Anchor: Start with specific manager
    SELECT emp_id, emp_name, title, manager_id, 0 AS level
    FROM employees_org
    WHERE emp_id = 1  -- Start from CEO
    
    UNION ALL
    
    -- Recursive: Find employees who report to current level
    SELECT e.emp_id, e.emp_name, e.title, e.manager_id, s.level + 1
    FROM employees_org e
    INNER JOIN subordinates s ON e.manager_id = s.emp_id
)
SELECT 
    CONCAT(REPEAT('  ', level), emp_name) AS org_chart,
    title,
    level
FROM subordinates
ORDER BY level, emp_name;

-- Get management chain (upward traversal)
WITH RECURSIVE management_chain AS (
    -- Anchor: Start with specific employee
    SELECT emp_id, emp_name, title, manager_id, 0 AS level
    FROM employees_org
    WHERE emp_id = 9  -- Start from Carol Atim
    
    UNION ALL
    
    -- Recursive: Find each manager up the chain
    SELECT e.emp_id, e.emp_name, e.title, e.manager_id, mc.level + 1
    FROM employees_org e
    INNER JOIN management_chain mc ON e.emp_id = mc.manager_id
)
SELECT emp_name, title, level
FROM management_chain
ORDER BY level;

-- ============================================================================
-- SECTION 3: HIERARCHY PATH AND DEPTH
-- ============================================================================

-- Build full path from root
WITH RECURSIVE org_paths AS (
    -- Anchor: Start at top (no manager)
    SELECT 
        emp_id, 
        emp_name, 
        title,
        manager_id,
        CAST(emp_name AS CHAR(500)) AS path,
        0 AS depth
    FROM employees_org
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive: Add each level
    SELECT 
        e.emp_id,
        e.emp_name,
        e.title,
        e.manager_id,
        CONCAT(op.path, ' > ', e.emp_name),
        op.depth + 1
    FROM employees_org e
    INNER JOIN org_paths op ON e.manager_id = op.emp_id
)
SELECT emp_name, title, path, depth
FROM org_paths
ORDER BY path;

-- Find employees at specific depth
WITH RECURSIVE levels AS (
    SELECT emp_id, emp_name, manager_id, 0 AS level
    FROM employees_org WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.emp_name, e.manager_id, l.level + 1
    FROM employees_org e
    JOIN levels l ON e.manager_id = l.emp_id
)
SELECT * FROM levels WHERE level = 2;  -- Get all at level 2

-- Calculate total depth of organization
WITH RECURSIVE org_depth AS (
    SELECT emp_id, manager_id, 0 AS level
    FROM employees_org WHERE manager_id IS NULL
    UNION ALL
    SELECT e.emp_id, e.manager_id, od.level + 1
    FROM employees_org e
    JOIN org_depth od ON e.manager_id = od.emp_id
)
SELECT MAX(level) AS max_depth FROM org_depth;

-- ============================================================================
-- SECTION 4: AGGREGATE CALCULATIONS IN HIERARCHIES
-- ============================================================================

-- Calculate team sizes
WITH RECURSIVE team_counts AS (
    SELECT emp_id, emp_name, manager_id
    FROM employees_org
    UNION ALL
    SELECT e.emp_id, tc.emp_name, e.manager_id
    FROM employees_org e
    JOIN team_counts tc ON e.manager_id = tc.emp_id
)
SELECT emp_name, COUNT(*) - 1 AS team_size
FROM team_counts
GROUP BY emp_name
HAVING COUNT(*) > 1
ORDER BY team_size DESC;

-- Calculate total salary by subtree (team cost)
WITH RECURSIVE team_salaries AS (
    -- Anchor: Each employee starts with their own salary count
    SELECT 
        emp_id,
        emp_name,
        manager_id,
        salary,
        emp_id AS root_id,
        emp_name AS root_name
    FROM employees_org
    
    UNION ALL
    
    -- Recursive: Add subordinate salaries to each manager
    SELECT 
        e.emp_id,
        e.emp_name,
        e.manager_id,
        e.salary,
        ts.root_id,
        ts.root_name
    FROM employees_org e
    JOIN team_salaries ts ON e.manager_id = ts.emp_id
)
SELECT 
    root_name AS manager,
    SUM(salary) AS total_team_cost,
    COUNT(*) AS team_size
FROM team_salaries
GROUP BY root_id, root_name
HAVING COUNT(*) > 1
ORDER BY total_team_cost DESC;

-- ============================================================================
-- SECTION 5: PRODUCT CATEGORIES (NESTED CATEGORIES)
-- ============================================================================

CREATE TABLE categories (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(100),
    parent_id INT,
    FOREIGN KEY (parent_id) REFERENCES categories(category_id)
);

INSERT INTO categories VALUES
(1, 'Electronics', NULL),
(2, 'Clothing', NULL),
(3, 'Phones', 1),
(4, 'Computers', 1),
(5, 'Smartphones', 3),
(6, 'Feature Phones', 3),
(7, 'Laptops', 4),
(8, 'Desktops', 4),
(9, "Men's Wear", 2),
(10, "Women's Wear", 2),
(11, 'Android Phones', 5),
(12, 'iPhones', 5);

-- Get full category tree with indentation
WITH RECURSIVE category_tree AS (
    SELECT 
        category_id,
        category_name,
        parent_id,
        0 AS level,
        CAST(category_name AS CHAR(500)) AS path
    FROM categories
    WHERE parent_id IS NULL
    
    UNION ALL
    
    SELECT 
        c.category_id,
        c.category_name,
        c.parent_id,
        ct.level + 1,
        CONCAT(ct.path, ' > ', c.category_name)
    FROM categories c
    JOIN category_tree ct ON c.parent_id = ct.category_id
)
SELECT 
    CONCAT(REPEAT('  ', level), category_name) AS category_tree,
    path
FROM category_tree
ORDER BY path;

-- Get all descendants of a category (for filtering products)
WITH RECURSIVE subcategories AS (
    SELECT category_id FROM categories WHERE category_id = 1  -- Electronics
    UNION ALL
    SELECT c.category_id
    FROM categories c
    JOIN subcategories sc ON c.parent_id = sc.category_id
)
SELECT * FROM products 
WHERE category_id IN (SELECT category_id FROM subcategories);

-- ============================================================================
-- SECTION 6: BILL OF MATERIALS (BOM)
-- ============================================================================

CREATE TABLE bom (
    parent_part VARCHAR(50),
    child_part VARCHAR(50),
    quantity INT,
    PRIMARY KEY (parent_part, child_part)
);

INSERT INTO bom VALUES
('Bicycle', 'Frame', 1),
('Bicycle', 'Wheel', 2),
('Bicycle', 'Handlebars', 1),
('Bicycle', 'Seat', 1),
('Frame', 'Tube', 3),
('Frame', 'Joint', 4),
('Frame', 'Paint', 1),
('Wheel', 'Rim', 1),
('Wheel', 'Tire', 1),
('Wheel', 'Spoke', 32),
('Wheel', 'Hub', 1),
('Handlebars', 'Grip', 2),
('Handlebars', 'Bar', 1);

-- Explode BOM (get all components with quantities)
WITH RECURSIVE bom_explosion AS (
    -- Anchor: Top-level product components
    SELECT 
        parent_part AS product,
        child_part AS component,
        quantity,
        1 AS level,
        CAST(child_part AS CHAR(500)) AS path
    FROM bom
    WHERE parent_part = 'Bicycle'
    
    UNION ALL
    
    -- Recursive: Components of components
    SELECT 
        be.product,
        b.child_part,
        be.quantity * b.quantity,  -- Multiply quantities
        be.level + 1,
        CONCAT(be.path, ' > ', b.child_part)
    FROM bom b
    JOIN bom_explosion be ON b.parent_part = be.component
)
SELECT 
    CONCAT(REPEAT('  ', level - 1), component) AS component_tree,
    quantity AS total_needed,
    path
FROM bom_explosion
ORDER BY path;

-- Calculate total parts needed
WITH RECURSIVE bom_totals AS (
    SELECT child_part AS part, quantity
    FROM bom WHERE parent_part = 'Bicycle'
    UNION ALL
    SELECT b.child_part, bt.quantity * b.quantity
    FROM bom b
    JOIN bom_totals bt ON b.parent_part = bt.part
)
SELECT part, SUM(quantity) AS total_quantity
FROM bom_totals
GROUP BY part
ORDER BY total_quantity DESC;

-- ============================================================================
-- SECTION 7: GRAPH TRAVERSAL
-- ============================================================================

-- Social network connections
CREATE TABLE connections (
    person_id INT,
    friend_id INT,
    PRIMARY KEY (person_id, friend_id)
);

INSERT INTO connections VALUES
(1, 2), (1, 3), (2, 1), (2, 4), (3, 1), (3, 5),
(4, 2), (4, 5), (5, 3), (5, 4), (5, 6), (6, 5);

-- Find friends of friends (2 degrees of separation)
WITH RECURSIVE friend_network AS (
    -- Direct friends
    SELECT 
        person_id AS origin,
        friend_id AS connection,
        1 AS degree,
        CAST(CONCAT(person_id, '->', friend_id) AS CHAR(500)) AS path
    FROM connections
    WHERE person_id = 1
    
    UNION ALL
    
    -- Friends of friends
    SELECT 
        fn.origin,
        c.friend_id,
        fn.degree + 1,
        CONCAT(fn.path, '->', c.friend_id)
    FROM connections c
    JOIN friend_network fn ON c.person_id = fn.connection
    WHERE fn.degree < 3  -- Limit depth
      AND c.friend_id != fn.origin  -- Avoid returning to origin
      AND NOT FIND_IN_SET(c.friend_id, REPLACE(fn.path, '->', ','))  -- Avoid cycles
)
SELECT DISTINCT connection, MIN(degree) AS degrees_of_separation
FROM friend_network
WHERE connection != 1  -- Exclude origin
GROUP BY connection
ORDER BY degrees_of_separation;

-- Route finding
CREATE TABLE routes (
    from_city VARCHAR(50),
    to_city VARCHAR(50),
    distance_km INT,
    travel_hours DECIMAL(4,2),
    PRIMARY KEY (from_city, to_city)
);

INSERT INTO routes VALUES
('Kampala', 'Jinja', 80, 1.5),
('Kampala', 'Entebbe', 40, 1.0),
('Jinja', 'Mbale', 110, 2.0),
('Mbale', 'Soroti', 85, 1.5),
('Kampala', 'Masaka', 130, 2.5),
('Masaka', 'Mbarara', 140, 2.5),
('Mbarara', 'Kabale', 150, 3.0),
('Entebbe', 'Masaka', 100, 2.0);

-- Find all paths between two cities
WITH RECURSIVE all_routes AS (
    SELECT 
        from_city,
        to_city,
        distance_km AS total_distance,
        travel_hours AS total_hours,
        CAST(CONCAT(from_city, ' -> ', to_city) AS CHAR(1000)) AS route,
        1 AS stops
    FROM routes
    WHERE from_city = 'Kampala'
    
    UNION ALL
    
    SELECT 
        ar.from_city,
        r.to_city,
        ar.total_distance + r.distance_km,
        ar.total_hours + r.travel_hours,
        CONCAT(ar.route, ' -> ', r.to_city),
        ar.stops + 1
    FROM routes r
    JOIN all_routes ar ON r.from_city = ar.to_city
    WHERE ar.stops < 5  -- Limit stops
      AND NOT LOCATE(r.to_city, ar.route)  -- Avoid revisiting
)
SELECT route, total_distance, total_hours, stops
FROM all_routes
WHERE to_city = 'Kabale'
ORDER BY total_distance;

-- ============================================================================
-- SECTION 8: SEQUENCE GENERATION
-- ============================================================================

-- Generate number sequence
WITH RECURSIVE numbers AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM numbers WHERE n < 100
)
SELECT n FROM numbers;

-- Generate date sequence
WITH RECURSIVE dates AS (
    SELECT DATE('2024-01-01') AS date_val
    UNION ALL
    SELECT DATE_ADD(date_val, INTERVAL 1 DAY)
    FROM dates
    WHERE date_val < '2024-01-31'
)
SELECT date_val, DAYNAME(date_val) AS day_name
FROM dates;

-- Fill gaps in time series data
CREATE TABLE daily_sales (
    sale_date DATE PRIMARY KEY,
    amount DECIMAL(12,2)
);

INSERT INTO daily_sales VALUES
('2024-01-01', 1500000),
('2024-01-03', 2000000),
('2024-01-05', 1800000),
('2024-01-07', 2200000);

WITH RECURSIVE all_dates AS (
    SELECT DATE('2024-01-01') AS d
    UNION ALL
    SELECT DATE_ADD(d, INTERVAL 1 DAY)
    FROM all_dates
    WHERE d < '2024-01-10'
)
SELECT 
    ad.d AS date,
    COALESCE(ds.amount, 0) AS sales_amount,
    CASE WHEN ds.amount IS NULL THEN 'No Sales' ELSE 'Sales' END AS status
FROM all_dates ad
LEFT JOIN daily_sales ds ON ad.d = ds.sale_date
ORDER BY ad.d;

-- ============================================================================
-- SECTION 9: COMMON PATTERNS AND BEST PRACTICES
-- ============================================================================

/*
RECURSIVE CTE BEST PRACTICES:

1. ALWAYS include termination condition
   - Without it, query runs forever
   - Use level/depth counter
   - Use WHERE clause in recursive part

2. Avoid cycles in graph traversal
   - Keep track of visited nodes
   - Use path string or temporary storage

3. Performance considerations
   - Limit recursion depth
   - Add proper indexes on join columns
   - Use UNION ALL (not UNION) unless duplicates problematic

4. Set recursion limit if needed
   SET SESSION cte_max_recursion_depth = 1000;
*/

-- Set recursion limit (default is 1000 in MySQL)
SET SESSION cte_max_recursion_depth = 500;

-- Pattern: Safe cycle detection
WITH RECURSIVE safe_traverse AS (
    SELECT 
        emp_id,
        emp_name,
        manager_id,
        CAST(emp_id AS CHAR(500)) AS visited,
        0 AS depth
    FROM employees_org
    WHERE manager_id IS NULL
    
    UNION ALL
    
    SELECT 
        e.emp_id,
        e.emp_name,
        e.manager_id,
        CONCAT(st.visited, ',', e.emp_id),
        st.depth + 1
    FROM employees_org e
    JOIN safe_traverse st ON e.manager_id = st.emp_id
    WHERE st.depth < 10  -- Depth limit
      AND NOT FIND_IN_SET(e.emp_id, st.visited)  -- Cycle detection
)
SELECT * FROM safe_traverse;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Organization hierarchy
a) Find all employees under a specific manager (with levels)
b) Calculate total salary budget for each manager's team
c) Find employees with no subordinates (leaf nodes)
d) Display full org chart with indentation

EXERCISE 2: Category navigation
a) Build breadcrumb trail for any category
b) Get all products in a category including subcategories
c) Calculate product count at each category level
d) Find the deepest category path

EXERCISE 3: Bill of Materials
a) Calculate total cost to build a product (with part prices)
b) Find all products that use a specific component
c) Compare BOM between two product versions
d) Find critical path (longest chain of dependencies)

EXERCISE 4: Graph problems
a) Find shortest path between two nodes
b) Detect cycles in a graph
c) Find all nodes reachable from a starting point
d) Calculate degree centrality for each node

EXERCISE 5: Time series
a) Generate calendar table with business days
b) Fill missing dates in sales data with 0
c) Calculate running averages with filled gaps
d) Find longest streak of consecutive days with sales

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

