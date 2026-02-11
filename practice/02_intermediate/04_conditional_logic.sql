-- ============================================================================
-- SQL CONDITIONAL LOGIC: CASE, IF, COALESCE, NULLIF
-- Module 11: Decision Making in SQL
-- Goal: Master conditional expressions for complex business logic
-- ============================================================================

-- ============================================================================
-- SECTION 1: CASE EXPRESSION - THE FOUNDATION
-- ============================================================================

/*
CASE has two forms:
1. Simple CASE: Compares expression to values
2. Searched CASE: Evaluates conditions
*/

-- Simple CASE (equality comparison)
SELECT 
    product_name,
    category,
    CASE category
        WHEN 'Electronics' THEN 'Tech Products'
        WHEN 'Furniture' THEN 'Office Items'
        WHEN 'Appliances' THEN 'Home Products'
        ELSE 'Other'
    END AS category_description
FROM products;

-- Searched CASE (complex conditions)
SELECT 
    product_name,
    price,
    CASE 
        WHEN price >= 5000000 THEN 'Premium'
        WHEN price >= 2000000 THEN 'Mid-Range'
        WHEN price >= 500000 THEN 'Budget'
        ELSE 'Economy'
    END AS price_tier
FROM products;

-- CASE with multiple conditions
SELECT 
    employee_name,
    salary,
    years_of_service,
    CASE 
        WHEN salary > 5000000 AND years_of_service > 5 THEN 'Senior High Paid'
        WHEN salary > 5000000 THEN 'New High Paid'
        WHEN years_of_service > 5 THEN 'Senior Standard'
        ELSE 'Standard'
    END AS employee_category
FROM employees;

-- Nested CASE
SELECT 
    customer_name,
    total_purchases,
    district,
    CASE district
        WHEN 'Kampala' THEN 
            CASE 
                WHEN total_purchases > 10000000 THEN 'Kampala VIP'
                ELSE 'Kampala Regular'
            END
        ELSE 
            CASE 
                WHEN total_purchases > 5000000 THEN 'Regional VIP'
                ELSE 'Regional Regular'
            END
    END AS customer_tier
FROM customers;

-- ============================================================================
-- SECTION 2: CASE IN DIFFERENT CONTEXTS
-- ============================================================================

-- CASE in ORDER BY
SELECT product_name, category, price
FROM products
ORDER BY 
    CASE category
        WHEN 'Electronics' THEN 1
        WHEN 'Appliances' THEN 2
        WHEN 'Furniture' THEN 3
        ELSE 4
    END,
    price DESC;

-- CASE in WHERE clause
SELECT * FROM orders
WHERE 
    CASE 
        WHEN status = 'urgent' THEN total_amount > 1000000
        WHEN status = 'standard' THEN total_amount > 5000000
        ELSE FALSE
    END;

-- CASE in JOIN condition
SELECT o.*, c.customer_name, c.credit_limit
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
    AND CASE 
        WHEN o.status = 'credit' THEN o.total_amount <= c.credit_limit
        ELSE TRUE
    END;

-- CASE in UPDATE
UPDATE products
SET price = CASE 
    WHEN category = 'Electronics' THEN price * 1.10
    WHEN category = 'Furniture' THEN price * 1.05
    ELSE price * 1.03
END;

-- CASE in GROUP BY
SELECT 
    CASE 
        WHEN HOUR(order_time) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN HOUR(order_time) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN HOUR(order_time) BETWEEN 18 AND 21 THEN 'Evening'
        ELSE 'Night'
    END AS time_of_day,
    COUNT(*) AS order_count,
    SUM(total_amount) AS total_sales
FROM orders
GROUP BY 
    CASE 
        WHEN HOUR(order_time) BETWEEN 6 AND 11 THEN 'Morning'
        WHEN HOUR(order_time) BETWEEN 12 AND 17 THEN 'Afternoon'
        WHEN HOUR(order_time) BETWEEN 18 AND 21 THEN 'Evening'
        ELSE 'Night'
    END;

-- ============================================================================
-- SECTION 3: CONDITIONAL AGGREGATION WITH CASE
-- ============================================================================

-- Pivot table using CASE
SELECT 
    DATE_FORMAT(order_date, '%Y-%m') AS month,
    SUM(CASE WHEN category = 'Electronics' THEN total_amount ELSE 0 END) AS electronics_sales,
    SUM(CASE WHEN category = 'Furniture' THEN total_amount ELSE 0 END) AS furniture_sales,
    SUM(CASE WHEN category = 'Appliances' THEN total_amount ELSE 0 END) AS appliances_sales,
    SUM(total_amount) AS total_sales
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY DATE_FORMAT(order_date, '%Y-%m');

-- Conditional counts
SELECT 
    employee_name,
    COUNT(*) AS total_sales,
    COUNT(CASE WHEN total_amount >= 5000000 THEN 1 END) AS large_sales,
    COUNT(CASE WHEN total_amount < 1000000 THEN 1 END) AS small_sales,
    SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed_sales,
    SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_sales
FROM orders o
JOIN employees e ON o.salesperson_id = e.employee_id
GROUP BY employee_id, employee_name;

-- Conditional averages
SELECT 
    category,
    AVG(price) AS avg_price,
    AVG(CASE WHEN stock_quantity > 0 THEN price END) AS avg_in_stock_price,
    AVG(CASE WHEN stock_quantity = 0 THEN price END) AS avg_out_of_stock_price
FROM products
GROUP BY category;

-- ============================================================================
-- SECTION 4: NULL HANDLING FUNCTIONS
-- ============================================================================

-- COALESCE: Return first non-NULL value
SELECT 
    customer_name,
    COALESCE(phone, email, 'No Contact') AS primary_contact,
    COALESCE(shipping_address, billing_address, 'No Address') AS address
FROM customers;

-- COALESCE for default values
SELECT 
    product_name,
    COALESCE(discount_percent, 0) AS discount,
    price * (1 - COALESCE(discount_percent, 0) / 100) AS final_price
FROM products;

-- COALESCE in calculations
SELECT 
    order_id,
    subtotal,
    COALESCE(discount, 0) AS discount,
    COALESCE(tax, 0) AS tax,
    COALESCE(shipping, 0) AS shipping,
    subtotal - COALESCE(discount, 0) + COALESCE(tax, 0) + COALESCE(shipping, 0) AS total
FROM orders;

-- IFNULL / NVL (database-specific)
SELECT 
    product_name,
    IFNULL(description, 'No description available') AS description,  -- MySQL
    -- NVL(description, 'No description available') AS description,  -- Oracle
    -- ISNULL(description, 'No description available') AS description -- SQL Server
FROM products;

-- NULLIF: Return NULL if values are equal
SELECT 
    product_name,
    price,
    cost_price,
    NULLIF(cost_price, 0) AS safe_cost,  -- Avoid division by zero
    price / NULLIF(cost_price, 0) AS markup_ratio
FROM products;

-- Using NULLIF to handle empty strings
SELECT 
    customer_name,
    COALESCE(NULLIF(phone, ''), NULLIF(email, ''), 'No Contact') AS contact
FROM customers;

-- ============================================================================
-- SECTION 5: IF FUNCTION (MySQL-specific)
-- ============================================================================

-- Basic IF
SELECT 
    product_name,
    stock_quantity,
    IF(stock_quantity > 0, 'In Stock', 'Out of Stock') AS availability,
    IF(stock_quantity < reorder_level, 'Need to Reorder', 'Stock OK') AS stock_status
FROM products;

-- IF with calculations
SELECT 
    order_id,
    total_amount,
    IF(total_amount > 5000000, total_amount * 0.95, total_amount) AS discounted_total,
    IF(total_amount > 5000000, 'Free Shipping', 'Standard Shipping') AS shipping_type
FROM orders;

-- Nested IF (better to use CASE for readability)
SELECT 
    product_name,
    price,
    IF(price > 5000000, 'Premium',
        IF(price > 2000000, 'Mid-Range',
            IF(price > 500000, 'Budget', 'Economy')
        )
    ) AS price_tier
FROM products;

-- ============================================================================
-- SECTION 6: GREATEST AND LEAST
-- ============================================================================

-- GREATEST: Return largest value
SELECT 
    product_name,
    price,
    cost_price,
    GREATEST(price, cost_price, 100000) AS max_value,
    GREATEST(price * 0.9, cost_price * 1.1) AS minimum_acceptable_price
FROM products;

-- LEAST: Return smallest value
SELECT 
    customer_name,
    credit_limit,
    pending_orders_total,
    LEAST(credit_limit, 10000000) AS max_allowed_credit,
    LEAST(credit_limit - pending_orders_total, 5000000) AS available_credit
FROM customers;

-- Business rule: Discount cannot exceed 50% or reduce price below cost
SELECT 
    product_name,
    price,
    cost_price,
    LEAST(
        discount_percent,
        50,  -- Max 50% discount
        (price - cost_price) / price * 100  -- Cannot go below cost
    ) AS allowed_discount
FROM products;

-- ============================================================================
-- SECTION 7: COMPARISON FUNCTIONS
-- ============================================================================

-- BETWEEN (inclusive)
SELECT * FROM products
WHERE price BETWEEN 1000000 AND 5000000;

-- Equivalent CASE
SELECT 
    product_name,
    price,
    CASE WHEN price BETWEEN 1000000 AND 5000000 THEN 'In Range' ELSE 'Out of Range' END AS status
FROM products;

-- IN
SELECT * FROM orders
WHERE status IN ('pending', 'processing', 'shipped');

-- NOT IN
SELECT * FROM products
WHERE category NOT IN ('Discontinued', 'Archived');

-- ============================================================================
-- SECTION 8: BOOLEAN EXPRESSIONS
-- ============================================================================

-- Boolean result (1 or 0)
SELECT 
    product_name,
    stock_quantity > 0 AS is_in_stock,
    price > 5000000 AS is_premium,
    (stock_quantity > 0 AND price > 5000000) AS premium_and_available
FROM products;

-- Combine with IF
SELECT 
    customer_name,
    is_active,
    has_credit,
    IF(is_active AND has_credit, 'Can Order', 'Cannot Order') AS order_eligibility
FROM customers;

-- ============================================================================
-- SECTION 9: PRACTICAL BUSINESS LOGIC EXAMPLES
-- ============================================================================

-- Example 1: Dynamic Pricing
SELECT 
    product_name,
    category,
    base_price,
    stock_quantity,
    CASE 
        -- Clearance: Low stock, old inventory
        WHEN stock_quantity < 5 AND days_in_inventory > 90 THEN base_price * 0.70
        -- Sale: Overstocked
        WHEN stock_quantity > 100 THEN base_price * 0.85
        -- Premium: High demand, low stock
        WHEN demand_score > 8 AND stock_quantity < 20 THEN base_price * 1.10
        -- Normal price
        ELSE base_price
    END AS current_price,
    CASE 
        WHEN stock_quantity < 5 AND days_in_inventory > 90 THEN '30% OFF - Clearance'
        WHEN stock_quantity > 100 THEN '15% OFF - Sale'
        WHEN demand_score > 8 AND stock_quantity < 20 THEN 'High Demand Premium'
        ELSE 'Regular Price'
    END AS pricing_reason
FROM products;

-- Example 2: Customer Segmentation (RFM Analysis)
SELECT 
    customer_id,
    customer_name,
    last_order_date,
    total_orders,
    total_spent,
    -- Recency Score
    CASE 
        WHEN DATEDIFF(CURDATE(), last_order_date) <= 30 THEN 5
        WHEN DATEDIFF(CURDATE(), last_order_date) <= 60 THEN 4
        WHEN DATEDIFF(CURDATE(), last_order_date) <= 90 THEN 3
        WHEN DATEDIFF(CURDATE(), last_order_date) <= 180 THEN 2
        ELSE 1
    END AS recency_score,
    -- Frequency Score
    CASE 
        WHEN total_orders >= 20 THEN 5
        WHEN total_orders >= 10 THEN 4
        WHEN total_orders >= 5 THEN 3
        WHEN total_orders >= 2 THEN 2
        ELSE 1
    END AS frequency_score,
    -- Monetary Score
    CASE 
        WHEN total_spent >= 50000000 THEN 5
        WHEN total_spent >= 20000000 THEN 4
        WHEN total_spent >= 10000000 THEN 3
        WHEN total_spent >= 5000000 THEN 2
        ELSE 1
    END AS monetary_score
FROM (
    SELECT 
        c.customer_id,
        c.customer_name,
        MAX(o.order_date) AS last_order_date,
        COUNT(o.order_id) AS total_orders,
        COALESCE(SUM(o.total_amount), 0) AS total_spent
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.customer_name
) customer_summary;

-- Example 3: Order Status Workflow
SELECT 
    order_id,
    status,
    created_at,
    shipped_at,
    delivered_at,
    CASE status
        WHEN 'pending' THEN 
            CASE 
                WHEN TIMESTAMPDIFF(HOUR, created_at, NOW()) > 24 THEN 'ALERT: Pending > 24h'
                ELSE 'Normal - Awaiting Processing'
            END
        WHEN 'processing' THEN 'In Progress'
        WHEN 'shipped' THEN 
            CONCAT('In Transit - ', TIMESTAMPDIFF(DAY, shipped_at, NOW()), ' days')
        WHEN 'delivered' THEN 
            CONCAT('Completed in ', TIMESTAMPDIFF(DAY, created_at, delivered_at), ' days')
        WHEN 'cancelled' THEN 'Order Cancelled'
        ELSE 'Unknown Status'
    END AS status_detail,
    CASE 
        WHEN status = 'delivered' THEN 'complete'
        WHEN status = 'cancelled' THEN 'closed'
        ELSE 'active'
    END AS order_state
FROM orders;

-- Example 4: Commission Calculation
SELECT 
    e.employee_name,
    SUM(o.total_amount) AS total_sales,
    CASE 
        WHEN SUM(o.total_amount) >= 100000000 THEN 0.10  -- 10% for top performers
        WHEN SUM(o.total_amount) >= 50000000 THEN 0.07   -- 7% for high performers
        WHEN SUM(o.total_amount) >= 20000000 THEN 0.05   -- 5% for standard
        ELSE 0.03                                         -- 3% base commission
    END AS commission_rate,
    SUM(o.total_amount) * 
    CASE 
        WHEN SUM(o.total_amount) >= 100000000 THEN 0.10
        WHEN SUM(o.total_amount) >= 50000000 THEN 0.07
        WHEN SUM(o.total_amount) >= 20000000 THEN 0.05
        ELSE 0.03
    END AS commission_amount
FROM employees e
JOIN orders o ON e.employee_id = o.salesperson_id
WHERE o.status = 'completed'
  AND o.order_date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
GROUP BY e.employee_id, e.employee_name;

-- Example 5: Credit Risk Assessment
SELECT 
    customer_name,
    credit_limit,
    outstanding_balance,
    payment_history_score,
    CASE 
        WHEN outstanding_balance / credit_limit > 0.9 THEN 'High Risk'
        WHEN payment_history_score < 3 THEN 'High Risk'
        WHEN outstanding_balance / credit_limit > 0.7 AND payment_history_score < 5 THEN 'Medium Risk'
        WHEN outstanding_balance / credit_limit > 0.5 THEN 'Low-Medium Risk'
        ELSE 'Low Risk'
    END AS risk_level,
    CASE 
        WHEN outstanding_balance / credit_limit > 0.9 THEN credit_limit * 0
        WHEN outstanding_balance / credit_limit > 0.7 THEN credit_limit * 0.1
        WHEN outstanding_balance / credit_limit > 0.5 THEN credit_limit * 0.3
        ELSE credit_limit - outstanding_balance
    END AS available_credit
FROM customers;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: CASE statements
a) Create product price tiers: Economy, Budget, Standard, Premium, Luxury
b) Categorize orders by size: Small (<1M), Medium (1M-5M), Large (5M-10M), Mega (>10M)
c) Create employee performance ratings based on sales and tenure
d) Generate shipping priority based on customer tier and order value

EXERCISE 2: NULL handling
a) Show customer contact info with fallbacks (phone -> email -> 'No Contact')
b) Calculate profit margin handling NULL cost prices
c) Show order delivery status with proper NULL handling for dates
d) Compute average rating excluding NULLs and zeros

EXERCISE 3: Conditional aggregation
a) Create monthly sales pivot by category
b) Show employee performance with completed vs cancelled order counts
c) Calculate conversion rate (completed orders / total orders) per region
d) Generate inventory status summary (in stock, low stock, out of stock counts)

EXERCISE 4: Business logic
a) Implement tiered discount logic based on order value and customer loyalty
b) Create dynamic pricing based on demand, stock, and season
c) Implement credit approval workflow with multiple conditions
d) Calculate bonus eligibility based on multiple KPIs

EXERCISE 5: Complex scenarios
a) Implement A/B test result analysis with statistical significance
b) Create customer lifetime value calculation with segmentation
c) Build dynamic commission structure with accelerators
d) Implement inventory reorder point calculation with lead times

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

