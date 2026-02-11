-- ============================================================================
-- SQL COMPREHENSIVE PRACTICE EXERCISES
-- Practice Set 1: From Beginner to Expert
-- Goal: Test and reinforce all SQL concepts learned
-- ============================================================================

/*
These exercises progress from basic to advanced.
Complete each section before moving to the next.
Solutions are at the end - try without looking first!
*/

-- ============================================================================
-- SETUP: CREATE PRACTICE DATABASE
-- ============================================================================

-- Run this first to create the practice environment
CREATE DATABASE IF NOT EXISTS uganda_shop;
USE uganda_shop;

-- Customers table
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20),
    district VARCHAR(50),
    registration_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    credit_limit DECIMAL(12,2) DEFAULT 500000
);

-- Categories table
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL,
    parent_category_id INT,
    FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
);

-- Products table
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category_id INT,
    price DECIMAL(10,2) NOT NULL,
    cost_price DECIMAL(10,2),
    stock_quantity INT DEFAULT 0,
    reorder_level INT DEFAULT 10,
    supplier_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- Employees table
CREATE TABLE employees (
    emp_id INT AUTO_INCREMENT PRIMARY KEY,
    emp_name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    department VARCHAR(50),
    position VARCHAR(50),
    manager_id INT,
    hire_date DATE,
    salary DECIMAL(12,2),
    commission_rate DECIMAL(4,2),
    FOREIGN KEY (manager_id) REFERENCES employees(emp_id)
);

-- Orders table
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    employee_id INT,
    order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    required_date DATE,
    shipped_date DATE,
    status VARCHAR(20) DEFAULT 'pending',
    payment_method VARCHAR(30),
    subtotal DECIMAL(12,2),
    tax_amount DECIMAL(12,2),
    total_amount DECIMAL(12,2),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (employee_id) REFERENCES employees(emp_id)
);

-- Order items table
CREATE TABLE order_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    discount_percent DECIMAL(4,2) DEFAULT 0,
    line_total DECIMAL(12,2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- ============================================================================
-- INSERT SAMPLE DATA
-- ============================================================================

-- Categories
INSERT INTO categories (category_name, parent_category_id) VALUES
('Electronics', NULL),
('Phones', 1),
('Computers', 1),
('Clothing', NULL),
('Accessories', 1),
("Men's Wear", 4),
("Women's Wear", 4);

-- Customers
INSERT INTO customers (customer_name, email, phone, district, registration_date, credit_limit) VALUES
('Sarah Nakato', 'sarah@email.com', '0700100001', 'Kampala', '2023-01-15', 2000000),
('John Ochieng', 'john@email.com', '0700100002', 'Jinja', '2023-02-20', 1500000),
('Mary Namukasa', 'mary@email.com', '0700100003', 'Kampala', '2023-03-10', 1000000),
('Peter Kizza', 'peter@email.com', '0700100004', 'Mbarara', '2023-04-05', 800000),
('Jane Auma', 'jane@email.com', '0700100005', 'Gulu', '2023-05-12', 1200000),
('David Ssempala', 'david@email.com', '0700100006', 'Kampala', '2023-06-08', 2500000),
('Alice Namutebi', 'alice@email.com', '0700100007', 'Entebbe', '2023-07-22', 600000),
('Bob Mukasa', 'bob@email.com', '0700100008', 'Kampala', '2023-08-30', 900000),
('Carol Atim', 'carol@email.com', '0700100009', 'Lira', '2023-09-14', 700000),
('Dan Okello', 'dan@email.com', '0700100010', 'Mbale', '2023-10-01', 1100000);

-- Employees
INSERT INTO employees (emp_name, email, department, position, manager_id, hire_date, salary, commission_rate) VALUES
('Grace Nakirya', 'grace@shop.ug', 'Management', 'CEO', NULL, '2020-01-01', 8000000, NULL),
('Tom Wasswa', 'tom@shop.ug', 'Sales', 'Sales Manager', 1, '2020-03-15', 4000000, 0.02),
('Eva Nabatanzi', 'eva@shop.ug', 'Sales', 'Sales Rep', 2, '2021-06-01', 1500000, 0.05),
('Mike Ssali', 'mike@shop.ug', 'Sales', 'Sales Rep', 2, '2021-08-15', 1500000, 0.05),
('Rose Akello', 'rose@shop.ug', 'Sales', 'Sales Rep', 2, '2022-01-10', 1200000, 0.04),
('James Odong', 'james@shop.ug', 'Operations', 'Operations Manager', 1, '2020-05-01', 3500000, NULL),
('Susan Achieng', 'susan@shop.ug', 'Operations', 'Warehouse Staff', 6, '2022-03-01', 800000, NULL);

-- Products
INSERT INTO products (product_name, category_id, price, cost_price, stock_quantity, reorder_level) VALUES
('Samsung Galaxy S24', 2, 3500000, 2800000, 25, 10),
('iPhone 15', 2, 4500000, 3600000, 15, 5),
('Tecno Spark 20', 2, 450000, 350000, 50, 20),
('HP Laptop 15', 3, 2800000, 2200000, 12, 5),
('Dell Desktop', 3, 3200000, 2500000, 8, 3),
('MacBook Air', 3, 5500000, 4400000, 5, 3),
('Wireless Earbuds', 5, 150000, 90000, 100, 30),
('Phone Case', 5, 25000, 12000, 200, 50),
('Laptop Bag', 5, 80000, 45000, 60, 20),
('USB Cable', 5, 15000, 8000, 150, 40);

-- Orders and order items
INSERT INTO orders (customer_id, employee_id, order_date, required_date, status, payment_method, subtotal, tax_amount, total_amount) VALUES
(1, 3, '2024-01-05 10:30:00', '2024-01-10', 'completed', 'mobile_money', 3650000, 657000, 4307000),
(2, 4, '2024-01-07 14:15:00', '2024-01-12', 'completed', 'cash', 450000, 81000, 531000),
(3, 3, '2024-01-10 09:00:00', '2024-01-15', 'completed', 'mobile_money', 2950000, 531000, 3481000),
(1, 5, '2024-01-15 11:45:00', '2024-01-20', 'completed', 'card', 175000, 31500, 206500),
(4, 4, '2024-01-18 16:30:00', '2024-01-23', 'shipped', 'mobile_money', 4650000, 837000, 5487000),
(5, 3, '2024-01-20 13:00:00', '2024-01-25', 'processing', 'cash', 530000, 95400, 625400),
(6, 5, '2024-01-22 10:00:00', '2024-01-27', 'pending', 'mobile_money', 5580000, 1004400, 6584400),
(2, 4, '2024-01-25 15:30:00', '2024-01-30', 'pending', 'card', 3350000, 603000, 3953000);

INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_percent, line_total) VALUES
(1, 1, 1, 3500000, 0, 3500000),
(1, 7, 1, 150000, 0, 150000),
(2, 3, 1, 450000, 0, 450000),
(3, 4, 1, 2800000, 0, 2800000),
(3, 7, 1, 150000, 0, 150000),
(4, 8, 3, 25000, 0, 75000),
(4, 10, 5, 15000, 0, 75000),
(4, 9, 1, 80000, 0, 80000),
(5, 2, 1, 4500000, 0, 4500000),
(5, 7, 1, 150000, 0, 150000),
(6, 3, 1, 450000, 0, 450000),
(6, 9, 1, 80000, 0, 80000),
(7, 6, 1, 5500000, 0, 5500000),
(7, 9, 1, 80000, 0, 80000),
(8, 1, 1, 3500000, 5, 3325000),
(8, 8, 1, 25000, 0, 25000);

-- ============================================================================
-- LEVEL 1: BASIC QUERIES
-- ============================================================================

/*
EXERCISE 1.1: Simple SELECT
Write queries to:
a) Get all customers
b) Get customer names and emails only
c) Get all products with price greater than 1,000,000 UGX
d) Get all employees in the Sales department
*/

-- Your solutions:



/*
EXERCISE 1.2: Filtering with WHERE
Write queries to:
a) Find customers from Kampala
b) Find products with stock below reorder level
c) Find orders placed in January 2024
d) Find employees hired after 2021
*/

-- Your solutions:



/*
EXERCISE 1.3: Sorting and Limiting
Write queries to:
a) Get top 5 most expensive products
b) Get customers ordered alphabetically by name
c) Get the 3 most recent orders
d) Get products ordered by category, then by price descending
*/

-- Your solutions:



/*
EXERCISE 1.4: Basic Functions
Write queries to:
a) Count total number of customers
b) Find the highest and lowest product prices
c) Calculate average order total
d) Get current date and customer registration dates formatted as 'DD-MMM-YYYY'
*/

-- Your solutions:



-- ============================================================================
-- LEVEL 2: INTERMEDIATE QUERIES
-- ============================================================================

/*
EXERCISE 2.1: JOIN Operations
Write queries to:
a) List all orders with customer names
b) Show products with their category names
c) Display order items with product names and order dates
d) Show employees with their manager names
*/

-- Your solutions:



/*
EXERCISE 2.2: Aggregation and Grouping
Write queries to:
a) Count orders per customer
b) Total sales by payment method
c) Average product price by category
d) Number of employees per department with total salary
*/

-- Your solutions:



/*
EXERCISE 2.3: Subqueries
Write queries to:
a) Find customers who have placed orders
b) Find products that have never been ordered
c) Get orders with total above average
d) Find the customer with the highest total purchases
*/

-- Your solutions:



/*
EXERCISE 2.4: Set Operations and CASE
Write queries to:
a) List all people (customers and employees) with their type
b) Categorize products as 'Budget', 'Mid-Range', or 'Premium' based on price
c) Show order status with custom labels
d) Calculate commission for sales employees
*/

-- Your solutions:



-- ============================================================================
-- LEVEL 3: ADVANCED QUERIES
-- ============================================================================

/*
EXERCISE 3.1: Window Functions
Write queries to:
a) Rank products by price within each category
b) Calculate running total of orders by date
c) Find the difference between each order and the previous order amount
d) Show each customer's orders with their percentage of total customer spending
*/

-- Your solutions:



/*
EXERCISE 3.2: CTEs and Complex Queries
Write queries to:
a) Find customers who haven't ordered in the last 30 days (CTE)
b) Calculate customer lifetime value and rank them
c) Find top-selling products by quantity and revenue
d) Create a sales summary by month with growth rate
*/

-- Your solutions:



/*
EXERCISE 3.3: String and Date Manipulation
Write queries to:
a) Extract phone network from phone numbers (first 4 digits)
b) Calculate how many days since each customer registered
c) Find orders placed on weekends
d) Create a customer username from name (first name + customer_id)
*/

-- Your solutions:



/*
EXERCISE 3.4: Recursive Queries
Write queries to:
a) Display category hierarchy with indentation
b) Show employee reporting chain from any employee to CEO
c) Calculate total employees under each manager (including indirect reports)
*/

-- Your solutions:



-- ============================================================================
-- LEVEL 4: EXPERT CHALLENGES
-- ============================================================================

/*
CHALLENGE 4.1: Business Analytics
a) Perform RFM (Recency, Frequency, Monetary) analysis on customers
b) Calculate month-over-month growth rate
c) Find products frequently bought together
d) Identify customers at risk of churning
*/

-- Your solutions:



/*
CHALLENGE 4.2: Data Integrity and Validation
a) Find orders where line items don't sum to subtotal
b) Identify duplicate customer registrations (same phone or email)
c) Find orphaned records (order_items without valid orders)
d) Validate that all product prices are positive
*/

-- Your solutions:



/*
CHALLENGE 4.3: Performance Optimization
a) Rewrite a slow query using proper indexes
b) Convert correlated subquery to JOIN
c) Optimize pagination for large result sets
d) Create a summary table for dashboard queries
*/

-- Your solutions:



-- ============================================================================
-- SOLUTIONS
-- ============================================================================
-- Scroll down for solutions...















































-- ============================================================================
-- SOLUTION 1.1: Simple SELECT
-- ============================================================================

-- a) Get all customers
SELECT * FROM customers;

-- b) Get customer names and emails only
SELECT customer_name, email FROM customers;

-- c) Get all products with price greater than 1,000,000 UGX
SELECT * FROM products WHERE price > 1000000;

-- d) Get all employees in the Sales department
SELECT * FROM employees WHERE department = 'Sales';

-- ============================================================================
-- SOLUTION 1.2: Filtering with WHERE
-- ============================================================================

-- a) Find customers from Kampala
SELECT * FROM customers WHERE district = 'Kampala';

-- b) Find products with stock below reorder level
SELECT * FROM products WHERE stock_quantity < reorder_level;

-- c) Find orders placed in January 2024
SELECT * FROM orders WHERE order_date >= '2024-01-01' AND order_date < '2024-02-01';

-- d) Find employees hired after 2021
SELECT * FROM employees WHERE hire_date > '2021-12-31';

-- ============================================================================
-- SOLUTION 1.3: Sorting and Limiting
-- ============================================================================

-- a) Get top 5 most expensive products
SELECT * FROM products ORDER BY price DESC LIMIT 5;

-- b) Get customers ordered alphabetically by name
SELECT * FROM customers ORDER BY customer_name;

-- c) Get the 3 most recent orders
SELECT * FROM orders ORDER BY order_date DESC LIMIT 3;

-- d) Get products ordered by category, then by price descending
SELECT * FROM products ORDER BY category_id, price DESC;

-- ============================================================================
-- SOLUTION 1.4: Basic Functions
-- ============================================================================

-- a) Count total number of customers
SELECT COUNT(*) AS total_customers FROM customers;

-- b) Find the highest and lowest product prices
SELECT MAX(price) AS highest_price, MIN(price) AS lowest_price FROM products;

-- c) Calculate average order total
SELECT AVG(total_amount) AS average_order_value FROM orders;

-- d) Format dates
SELECT customer_name, DATE_FORMAT(registration_date, '%d-%b-%Y') AS formatted_date FROM customers;

-- ============================================================================
-- SOLUTION 2.1: JOIN Operations
-- ============================================================================

-- a) List all orders with customer names
SELECT o.order_id, o.order_date, c.customer_name, o.total_amount
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id;

-- b) Show products with their category names
SELECT p.product_name, p.price, c.category_name
FROM products p
LEFT JOIN categories c ON p.category_id = c.category_id;

-- c) Display order items with product names and order dates
SELECT oi.item_id, o.order_date, p.product_name, oi.quantity, oi.line_total
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id;

-- d) Show employees with their manager names
SELECT e.emp_name AS employee, e.position, m.emp_name AS manager
FROM employees e
LEFT JOIN employees m ON e.manager_id = m.emp_id;

-- ============================================================================
-- SOLUTION 2.2: Aggregation and Grouping
-- ============================================================================

-- a) Count orders per customer
SELECT c.customer_name, COUNT(o.order_id) AS order_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id
ORDER BY order_count DESC;

-- b) Total sales by payment method
SELECT payment_method, SUM(total_amount) AS total_sales, COUNT(*) AS order_count
FROM orders
GROUP BY payment_method;

-- c) Average product price by category
SELECT c.category_name, ROUND(AVG(p.price), 0) AS avg_price
FROM products p
JOIN categories c ON p.category_id = c.category_id
GROUP BY c.category_id;

-- d) Number of employees per department with total salary
SELECT department, COUNT(*) AS emp_count, SUM(salary) AS total_salary
FROM employees
GROUP BY department;

-- ============================================================================
-- SOLUTION 2.3: Subqueries
-- ============================================================================

-- a) Find customers who have placed orders
SELECT * FROM customers 
WHERE customer_id IN (SELECT DISTINCT customer_id FROM orders);

-- b) Find products that have never been ordered
SELECT * FROM products 
WHERE product_id NOT IN (SELECT DISTINCT product_id FROM order_items);

-- c) Get orders with total above average
SELECT * FROM orders 
WHERE total_amount > (SELECT AVG(total_amount) FROM orders);

-- d) Find the customer with the highest total purchases
SELECT c.customer_name, SUM(o.total_amount) AS total_spent
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id
ORDER BY total_spent DESC
LIMIT 1;

-- ============================================================================
-- SOLUTION 2.4: Set Operations and CASE
-- ============================================================================

-- a) List all people with their type
SELECT customer_name AS name, 'Customer' AS type FROM customers
UNION
SELECT emp_name, 'Employee' FROM employees;

-- b) Categorize products by price
SELECT product_name, price,
    CASE 
        WHEN price >= 3000000 THEN 'Premium'
        WHEN price >= 500000 THEN 'Mid-Range'
        ELSE 'Budget'
    END AS price_tier
FROM products;

-- c) Show order status with custom labels
SELECT order_id,
    CASE status
        WHEN 'pending' THEN 'Awaiting Processing'
        WHEN 'processing' THEN 'Being Prepared'
        WHEN 'shipped' THEN 'On The Way'
        WHEN 'completed' THEN 'Delivered'
        ELSE status
    END AS status_label
FROM orders;

-- d) Calculate commission for sales employees
SELECT emp_name, salary, commission_rate,
    COALESCE(commission_rate * 100, 0) AS commission_percent
FROM employees
WHERE department = 'Sales';

-- ============================================================================
-- SOLUTION 3.1: Window Functions
-- ============================================================================

-- a) Rank products by price within each category
SELECT 
    p.product_name, 
    c.category_name,
    p.price,
    RANK() OVER (PARTITION BY p.category_id ORDER BY p.price DESC) AS price_rank
FROM products p
JOIN categories c ON p.category_id = c.category_id;

-- b) Calculate running total of orders by date
SELECT 
    order_date,
    total_amount,
    SUM(total_amount) OVER (ORDER BY order_date) AS running_total
FROM orders;

-- c) Difference from previous order
SELECT 
    order_id,
    order_date,
    total_amount,
    LAG(total_amount) OVER (ORDER BY order_date) AS prev_order,
    total_amount - LAG(total_amount) OVER (ORDER BY order_date) AS difference
FROM orders;

-- d) Customer spending percentage
SELECT 
    c.customer_name,
    o.total_amount,
    SUM(o.total_amount) OVER (PARTITION BY c.customer_id) AS customer_total,
    ROUND(o.total_amount * 100.0 / SUM(o.total_amount) OVER (), 2) AS pct_of_all_sales
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id;

-- ============================================================================
-- SOLUTION 3.2: CTEs and Complex Queries
-- ============================================================================

-- a) Customers who haven't ordered in last 30 days
WITH recent_buyers AS (
    SELECT DISTINCT customer_id 
    FROM orders 
    WHERE order_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
)
SELECT c.* FROM customers c
LEFT JOIN recent_buyers rb ON c.customer_id = rb.customer_id
WHERE rb.customer_id IS NULL;

-- b) Customer lifetime value ranking
WITH customer_ltv AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        COALESCE(SUM(o.total_amount), 0) AS lifetime_value,
        COUNT(o.order_id) AS total_orders
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
)
SELECT 
    customer_name,
    lifetime_value,
    total_orders,
    RANK() OVER (ORDER BY lifetime_value DESC) AS ltv_rank
FROM customer_ltv;

-- c) Top-selling products
SELECT 
    p.product_name,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.line_total) AS revenue
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_id
ORDER BY revenue DESC;

-- d) Monthly sales with growth
WITH monthly_sales AS (
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
    ROUND((total - LAG(total) OVER (ORDER BY month)) * 100.0 / 
          NULLIF(LAG(total) OVER (ORDER BY month), 0), 2) AS growth_rate
FROM monthly_sales;

-- ============================================================================
-- SOLUTION 3.3: String and Date Manipulation
-- ============================================================================

-- a) Extract phone network
SELECT customer_name, phone, LEFT(phone, 4) AS network_code FROM customers;

-- b) Days since registration
SELECT customer_name, registration_date, 
       DATEDIFF(CURDATE(), registration_date) AS days_since_registration
FROM customers;

-- c) Weekend orders
SELECT * FROM orders 
WHERE DAYOFWEEK(order_date) IN (1, 7);  -- 1=Sunday, 7=Saturday

-- d) Create username
SELECT customer_name, 
       CONCAT(LOWER(SUBSTRING_INDEX(customer_name, ' ', 1)), customer_id) AS username
FROM customers;

-- ============================================================================
-- SOLUTION 3.4: Recursive Queries
-- ============================================================================

-- a) Category hierarchy
WITH RECURSIVE cat_tree AS (
    SELECT category_id, category_name, parent_category_id, 0 AS level
    FROM categories WHERE parent_category_id IS NULL
    UNION ALL
    SELECT c.category_id, c.category_name, c.parent_category_id, ct.level + 1
    FROM categories c
    JOIN cat_tree ct ON c.parent_category_id = ct.category_id
)
SELECT CONCAT(REPEAT('  ', level), category_name) AS category_tree FROM cat_tree;

-- b) Employee reporting chain
WITH RECURSIVE report_chain AS (
    SELECT emp_id, emp_name, manager_id, 0 AS level
    FROM employees WHERE emp_id = 5  -- Start from specific employee
    UNION ALL
    SELECT e.emp_id, e.emp_name, e.manager_id, rc.level + 1
    FROM employees e
    JOIN report_chain rc ON e.emp_id = rc.manager_id
)
SELECT emp_name, level FROM report_chain ORDER BY level;

-- c) Total reports under each manager
WITH RECURSIVE all_reports AS (
    SELECT emp_id, emp_name, manager_id, emp_id AS root_manager
    FROM employees
    UNION ALL
    SELECT e.emp_id, e.emp_name, e.manager_id, ar.root_manager
    FROM employees e
    JOIN all_reports ar ON e.manager_id = ar.emp_id
)
SELECT e.emp_name AS manager, COUNT(*) - 1 AS total_reports
FROM all_reports ar
JOIN employees e ON ar.root_manager = e.emp_id
GROUP BY ar.root_manager
HAVING COUNT(*) > 1;

