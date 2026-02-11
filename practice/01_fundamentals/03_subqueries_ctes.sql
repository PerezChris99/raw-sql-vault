-- ============================================================================
-- SQL SUBQUERIES: QUERIES WITHIN QUERIES
-- Module 06: Complete Subquery Mastery
-- Goal: Write complex nested queries for advanced data retrieval
-- ============================================================================

-- ============================================================================
-- SETUP: SAMPLE TABLES
-- ============================================================================

-- Using existing tables from previous modules, plus:
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    district VARCHAR(50),
    credit_limit DECIMAL(12, 2),
    registration_date DATE
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    total_amount DECIMAL(12, 2),
    status VARCHAR(20)
);

CREATE TABLE order_items (
    item_id INT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    unit_price DECIMAL(10, 2)
);

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10, 2),
    stock_quantity INT
);

-- Insert sample data
INSERT INTO customers VALUES
(1, 'Kampala Traders Ltd', 'Kampala', 50000000, '2022-01-15'),
(2, 'Jinja Electronics', 'Jinja', 30000000, '2022-03-20'),
(3, 'Mbarara Supplies', 'Mbarara', 25000000, '2022-06-10'),
(4, 'Gulu Wholesale', 'Gulu', 20000000, '2023-01-05'),
(5, 'Entebbe Imports', 'Entebbe', 40000000, '2023-04-15');

INSERT INTO products VALUES
(1, 'Laptop Pro', 'Electronics', 4000000, 50),
(2, 'Smartphone X', 'Electronics', 1500000, 100),
(3, 'Office Desk', 'Furniture', 800000, 30),
(4, 'Office Chair', 'Furniture', 250000, 75),
(5, 'Printer Pro', 'Electronics', 1200000, 40);

INSERT INTO orders VALUES
(101, 1, '2024-01-05', 8000000, 'completed'),
(102, 1, '2024-01-15', 3000000, 'completed'),
(103, 2, '2024-01-20', 6000000, 'completed'),
(104, 3, '2024-02-01', 2500000, 'pending'),
(105, 1, '2024-02-10', 12000000, 'completed'),
(106, 4, '2024-02-15', 1500000, 'cancelled'),
(107, 2, '2024-02-20', 4500000, 'completed'),
(108, 5, '2024-03-01', 7500000, 'pending');

INSERT INTO order_items VALUES
(1, 101, 1, 2, 4000000),
(2, 102, 4, 12, 250000),
(3, 103, 1, 1, 4000000),
(4, 103, 2, 2, 1500000),
(5, 104, 3, 3, 800000),
(6, 105, 1, 3, 4000000),
(7, 106, 2, 1, 1500000),
(8, 107, 5, 3, 1200000),
(9, 107, 4, 6, 250000),
(10, 108, 1, 1, 4000000),
(11, 108, 2, 2, 1500000);

-- ============================================================================
-- SECTION 1: SCALAR SUBQUERIES (Return Single Value)
-- ============================================================================

/*
Scalar subqueries return exactly ONE value (one row, one column).
Can be used anywhere a single value is expected.
*/

-- In SELECT clause - compare to average
SELECT 
    product_name,
    price,
    (SELECT AVG(price) FROM products) AS avg_price,
    price - (SELECT AVG(price) FROM products) AS diff_from_avg
FROM products;

-- In WHERE clause - filter by computed value
SELECT * FROM products
WHERE price > (SELECT AVG(price) FROM products);

-- Find the most expensive product
SELECT * FROM products
WHERE price = (SELECT MAX(price) FROM products);

-- Customer with highest total orders
SELECT * FROM customers
WHERE customer_id = (
    SELECT customer_id 
    FROM orders 
    GROUP BY customer_id 
    ORDER BY SUM(total_amount) DESC 
    LIMIT 1
);

-- ============================================================================
-- SECTION 2: COLUMN SUBQUERIES (Return Single Column, Multiple Rows)
-- ============================================================================

-- IN operator with subquery
SELECT * FROM customers
WHERE customer_id IN (
    SELECT DISTINCT customer_id FROM orders WHERE status = 'completed'
);

-- NOT IN - customers who haven't ordered
SELECT * FROM customers
WHERE customer_id NOT IN (
    SELECT DISTINCT customer_id FROM orders
);

-- ANY/SOME - at least one match
SELECT * FROM products
WHERE price > ANY (
    SELECT price FROM products WHERE category = 'Furniture'
);
-- Returns products with price > minimum furniture price

-- ALL - must match all values
SELECT * FROM products
WHERE price > ALL (
    SELECT price FROM products WHERE category = 'Furniture'
);
-- Returns products with price > maximum furniture price

-- ============================================================================
-- SECTION 3: ROW SUBQUERIES (Return Single Row, Multiple Columns)
-- ============================================================================

-- Compare multiple columns at once
SELECT * FROM products
WHERE (category, price) = (
    SELECT category, MAX(price) 
    FROM products 
    WHERE category = 'Electronics'
    GROUP BY category
);

-- Find product with same category and price as specific product
SELECT * FROM products p1
WHERE (category, price) = (
    SELECT category, price FROM products WHERE product_id = 1
)
AND p1.product_id != 1;

-- ============================================================================
-- SECTION 4: TABLE SUBQUERIES (Derived Tables)
-- ============================================================================

/*
Subqueries in FROM clause create a temporary table (derived table).
Must have an alias in MySQL.
*/

-- Basic derived table
SELECT dt.category, dt.total_products, dt.avg_price
FROM (
    SELECT 
        category,
        COUNT(*) AS total_products,
        AVG(price) AS avg_price
    FROM products
    GROUP BY category
) AS dt;

-- Join with derived table
SELECT 
    c.customer_name,
    o.total_orders,
    o.total_spent
FROM customers c
INNER JOIN (
    SELECT 
        customer_id,
        COUNT(*) AS total_orders,
        SUM(total_amount) AS total_spent
    FROM orders
    WHERE status = 'completed'
    GROUP BY customer_id
) o ON c.customer_id = o.customer_id;

-- Complex derived table for reporting
SELECT 
    p.product_name,
    p.category,
    p.price,
    COALESCE(sales.total_sold, 0) AS total_sold,
    COALESCE(sales.revenue, 0) AS revenue
FROM products p
LEFT JOIN (
    SELECT 
        product_id,
        SUM(quantity) AS total_sold,
        SUM(quantity * unit_price) AS revenue
    FROM order_items
    GROUP BY product_id
) sales ON p.product_id = sales.product_id
ORDER BY revenue DESC;

-- ============================================================================
-- SECTION 5: CORRELATED SUBQUERIES
-- ============================================================================

/*
Correlated subqueries reference the outer query.
Executed once for EACH row of the outer query.
More flexible but can be slower than joins.
*/

-- Find products priced above category average
SELECT p.product_name, p.category, p.price
FROM products p
WHERE p.price > (
    SELECT AVG(p2.price)
    FROM products p2
    WHERE p2.category = p.category  -- References outer query
);

-- Find each customer's most recent order
SELECT 
    c.customer_name,
    o.order_id,
    o.order_date,
    o.total_amount
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_date = (
    SELECT MAX(o2.order_date)
    FROM orders o2
    WHERE o2.customer_id = c.customer_id
);

-- Running total using correlated subquery
SELECT 
    o.order_date,
    o.total_amount,
    (
        SELECT SUM(o2.total_amount)
        FROM orders o2
        WHERE o2.order_date <= o.order_date
    ) AS running_total
FROM orders o
ORDER BY o.order_date;

-- Count orders per customer inline
SELECT 
    c.customer_name,
    c.district,
    (
        SELECT COUNT(*) 
        FROM orders o 
        WHERE o.customer_id = c.customer_id
    ) AS order_count,
    (
        SELECT SUM(total_amount) 
        FROM orders o 
        WHERE o.customer_id = c.customer_id 
        AND o.status = 'completed'
    ) AS total_spent
FROM customers c;

-- ============================================================================
-- SECTION 6: EXISTS AND NOT EXISTS
-- ============================================================================

/*
EXISTS returns TRUE if subquery returns ANY rows.
Often more efficient than IN for large datasets.
*/

-- Customers who have placed orders
SELECT * FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
);

-- Customers who have NEVER placed orders
SELECT * FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id
);

-- Products that have been ordered
SELECT * FROM products p
WHERE EXISTS (
    SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id
);

-- Complex EXISTS: Customers who ordered electronics
SELECT * FROM customers c
WHERE EXISTS (
    SELECT 1 
    FROM orders o
    INNER JOIN order_items oi ON o.order_id = oi.order_id
    INNER JOIN products p ON oi.product_id = p.product_id
    WHERE o.customer_id = c.customer_id
    AND p.category = 'Electronics'
);

-- EXISTS vs IN performance comparison
-- EXISTS: stops at first match (efficient for large subqueries)
-- IN: evaluates entire subquery (efficient for small result sets)

-- ============================================================================
-- SECTION 7: SUBQUERIES IN UPDATE AND DELETE
-- ============================================================================

-- Update based on subquery
UPDATE products
SET price = price * 1.10
WHERE product_id IN (
    SELECT product_id 
    FROM order_items 
    GROUP BY product_id 
    HAVING SUM(quantity) > 5
);

-- Update with correlated subquery
UPDATE customers c
SET credit_limit = credit_limit * 1.20
WHERE (
    SELECT SUM(total_amount) 
    FROM orders o 
    WHERE o.customer_id = c.customer_id
) > 10000000;

-- Delete using subquery
DELETE FROM orders
WHERE customer_id IN (
    SELECT customer_id FROM customers WHERE district = 'Gulu'
)
AND status = 'cancelled';

-- Delete with NOT EXISTS
DELETE FROM products p
WHERE NOT EXISTS (
    SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id
);

-- ============================================================================
-- SECTION 8: SUBQUERY VS JOIN
-- ============================================================================

/*
When to use subqueries:
- Checking existence (EXISTS)
- Comparing aggregates
- When result is used once
- Scalar comparisons

When to use joins:
- Need columns from multiple tables
- Better readability for simple cases
- Often better optimized by database
*/

-- Same result, different approaches:

-- Approach 1: Subquery in WHERE
SELECT c.customer_name, c.district
FROM customers c
WHERE c.customer_id IN (
    SELECT o.customer_id FROM orders o WHERE o.status = 'completed'
);

-- Approach 2: JOIN
SELECT DISTINCT c.customer_name, c.district
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
WHERE o.status = 'completed';

-- Approach 3: EXISTS
SELECT c.customer_name, c.district
FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o 
    WHERE o.customer_id = c.customer_id 
    AND o.status = 'completed'
);

-- ============================================================================
-- SECTION 9: NESTED SUBQUERIES (Multiple Levels)
-- ============================================================================

-- Three levels of nesting
SELECT customer_name
FROM customers
WHERE customer_id IN (
    SELECT customer_id FROM orders WHERE order_id IN (
        SELECT order_id FROM order_items WHERE product_id IN (
            SELECT product_id FROM products WHERE category = 'Electronics'
        )
    )
);

-- Better approach using joins
SELECT DISTINCT c.customer_name
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN products p ON oi.product_id = p.product_id
WHERE p.category = 'Electronics';

-- ============================================================================
-- SECTION 10: COMMON TABLE EXPRESSIONS (CTEs)
-- ============================================================================

/*
CTEs are named subqueries defined at the start of a query.
More readable than nested subqueries.
Can be referenced multiple times.
*/

-- Basic CTE
WITH customer_totals AS (
    SELECT 
        customer_id,
        SUM(total_amount) AS total_spent
    FROM orders
    WHERE status = 'completed'
    GROUP BY customer_id
)
SELECT 
    c.customer_name,
    c.district,
    ct.total_spent
FROM customers c
INNER JOIN customer_totals ct ON c.customer_id = ct.customer_id
WHERE ct.total_spent > 5000000;

-- Multiple CTEs
WITH 
customer_orders AS (
    SELECT 
        customer_id,
        COUNT(*) AS num_orders,
        SUM(total_amount) AS total_spent
    FROM orders
    GROUP BY customer_id
),
product_sales AS (
    SELECT 
        p.category,
        SUM(oi.quantity) AS total_quantity
    FROM products p
    INNER JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY p.category
)
SELECT 
    c.customer_name,
    co.num_orders,
    co.total_spent
FROM customers c
INNER JOIN customer_orders co ON c.customer_id = co.customer_id;

-- Recursive CTE (for hierarchies)
-- Example: Employee hierarchy
WITH RECURSIVE employee_hierarchy AS (
    -- Anchor: Top-level managers (no manager)
    SELECT 
        emp_id,
        emp_name,
        manager_id,
        1 AS level,
        emp_name AS path
    FROM employees
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- Recursive: Employees who report to previous level
    SELECT 
        e.emp_id,
        e.emp_name,
        e.manager_id,
        eh.level + 1,
        CONCAT(eh.path, ' > ', e.emp_name)
    FROM employees e
    INNER JOIN employee_hierarchy eh ON e.manager_id = eh.emp_id
)
SELECT * FROM employee_hierarchy ORDER BY level, path;

-- ============================================================================
-- SECTION 11: REAL-WORLD SUBQUERY PATTERNS
-- ============================================================================

-- Pattern 1: Find records with no related data
SELECT p.product_name
FROM products p
WHERE NOT EXISTS (
    SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id
);

-- Pattern 2: Top N per group
SELECT * FROM (
    SELECT 
        o.*,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total_amount DESC) AS rn
    FROM orders o
) ranked
WHERE rn <= 2;  -- Top 2 orders per customer

-- Pattern 3: Percentage of total
SELECT 
    c.customer_name,
    SUM(o.total_amount) AS customer_total,
    ROUND(
        SUM(o.total_amount) * 100.0 / (SELECT SUM(total_amount) FROM orders), 
        2
    ) AS percentage_of_total
FROM customers c
INNER JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.customer_name;

-- Pattern 4: Moving average
SELECT 
    order_date,
    total_amount,
    (
        SELECT AVG(o2.total_amount)
        FROM orders o2
        WHERE o2.order_date BETWEEN DATE_SUB(o1.order_date, INTERVAL 7 DAY) 
                                AND o1.order_date
    ) AS seven_day_avg
FROM orders o1
ORDER BY order_date;

-- Pattern 5: Gap analysis (find missing sequences)
SELECT t1.order_id + 1 AS gap_start,
       (SELECT MIN(t2.order_id) - 1 FROM orders t2 WHERE t2.order_id > t1.order_id) AS gap_end
FROM orders t1
WHERE NOT EXISTS (
    SELECT 1 FROM orders t3 WHERE t3.order_id = t1.order_id + 1
)
AND t1.order_id < (SELECT MAX(order_id) FROM orders);

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Using subqueries, find:
a) Customers whose orders exceed their credit limit
b) Products that cost more than all furniture items
c) The second highest priced product
d) Orders placed by customers from Kampala

EXERCISE 2: Write a query using correlated subquery to show:
- Each product
- How many times it was ordered
- Its percentage of total orders

EXERCISE 3: Using CTEs, create a report showing:
- Customer name
- Number of orders
- Total spent
- Average order value
- Their rank by total spent

EXERCISE 4: Find customers who have:
- Ordered ALL categories of products (use NOT EXISTS)

EXERCISE 5: Write a query to find:
- Months where sales exceeded the previous month
- Use subquery to compare each month to its predecessor

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

