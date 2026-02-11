-- ============================================================================
-- REAL-WORLD SQL PROJECTS
-- Practice Set 2: Industry Scenarios
-- Goal: Build complete database solutions for real business problems
-- ============================================================================

-- ============================================================================
-- PROJECT 1: E-COMMERCE ANALYTICS DASHBOARD
-- ============================================================================

/*
SCENARIO:
You're building a data analytics dashboard for "UG Electronics", a Ugandan
e-commerce company. Create queries for the following dashboard metrics.
*/

-- Setup: Use the uganda_shop database from exercises
USE uganda_shop;

-- TASK 1.1: Sales Overview Widget
-- Show: Today's sales, yesterday's sales, this week, this month, change %
WITH daily_sales AS (
    SELECT 
        DATE(order_date) AS sale_date,
        SUM(total_amount) AS daily_total
    FROM orders
    WHERE status IN ('completed', 'shipped')
    GROUP BY DATE(order_date)
)
SELECT 
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders 
     WHERE DATE(order_date) = CURDATE()) AS today_sales,
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders 
     WHERE DATE(order_date) = DATE_SUB(CURDATE(), INTERVAL 1 DAY)) AS yesterday_sales,
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders 
     WHERE order_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)) AS week_sales,
    (SELECT COALESCE(SUM(total_amount), 0) FROM orders 
     WHERE MONTH(order_date) = MONTH(CURDATE()) AND YEAR(order_date) = YEAR(CURDATE())) AS month_sales;

-- TASK 1.2: Top Products Widget
-- Show top 5 products by revenue this month with units sold and revenue
SELECT 
    p.product_name,
    SUM(oi.quantity) AS units_sold,
    SUM(oi.line_total) AS revenue,
    ROUND(SUM(oi.line_total) * 100.0 / (
        SELECT SUM(line_total) FROM order_items oi2
        JOIN orders o2 ON oi2.order_id = o2.order_id
        WHERE MONTH(o2.order_date) = MONTH(CURDATE())
    ), 2) AS revenue_percentage
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE MONTH(o.order_date) = MONTH(CURDATE())
GROUP BY p.product_id
ORDER BY revenue DESC
LIMIT 5;

-- TASK 1.3: Customer Acquisition Widget
-- New customers per week for the last 8 weeks
WITH RECURSIVE weeks AS (
    SELECT 0 AS week_num
    UNION ALL
    SELECT week_num + 1 FROM weeks WHERE week_num < 7
)
SELECT 
    DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL w.week_num WEEK), '%Y-%W') AS week,
    COUNT(c.customer_id) AS new_customers
FROM weeks w
LEFT JOIN customers c ON YEARWEEK(c.registration_date) = YEARWEEK(DATE_SUB(CURDATE(), INTERVAL w.week_num WEEK))
GROUP BY w.week_num
ORDER BY w.week_num;

-- TASK 1.4: Sales Funnel
-- Order status distribution
SELECT 
    status,
    COUNT(*) AS order_count,
    SUM(total_amount) AS total_value,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS percentage
FROM orders
GROUP BY status
ORDER BY 
    CASE status 
        WHEN 'pending' THEN 1
        WHEN 'processing' THEN 2
        WHEN 'shipped' THEN 3
        WHEN 'completed' THEN 4
        ELSE 5
    END;

-- TASK 1.5: Geographic Distribution
-- Sales by district with customer count
SELECT 
    c.district,
    COUNT(DISTINCT c.customer_id) AS customers,
    COUNT(o.order_id) AS orders,
    COALESCE(SUM(o.total_amount), 0) AS revenue,
    ROUND(AVG(o.total_amount), 0) AS avg_order_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.district
ORDER BY revenue DESC;

-- ============================================================================
-- PROJECT 2: INVENTORY MANAGEMENT SYSTEM
-- ============================================================================

/*
SCENARIO:
Create queries for an inventory management system that helps warehouse
staff track stock levels and manage reorders.
*/

-- TASK 2.1: Stock Alert Report
-- Products that need reordering
SELECT 
    p.product_id,
    p.product_name,
    c.category_name,
    p.stock_quantity AS current_stock,
    p.reorder_level,
    p.stock_quantity - p.reorder_level AS units_below_level,
    CASE 
        WHEN p.stock_quantity = 0 THEN 'OUT OF STOCK'
        WHEN p.stock_quantity <= p.reorder_level * 0.5 THEN 'CRITICAL'
        WHEN p.stock_quantity <= p.reorder_level THEN 'LOW'
        ELSE 'OK'
    END AS stock_status,
    -- Calculate recommended order quantity (to reach 2x reorder level)
    GREATEST(p.reorder_level * 2 - p.stock_quantity, 0) AS recommended_order_qty
FROM products p
JOIN categories c ON p.category_id = c.category_id
WHERE p.stock_quantity <= p.reorder_level
ORDER BY 
    CASE 
        WHEN p.stock_quantity = 0 THEN 1
        WHEN p.stock_quantity <= p.reorder_level * 0.5 THEN 2
        ELSE 3
    END,
    p.stock_quantity;

-- TASK 2.2: Inventory Value Report
-- Total inventory value by category
SELECT 
    c.category_name,
    COUNT(p.product_id) AS product_count,
    SUM(p.stock_quantity) AS total_units,
    SUM(p.stock_quantity * p.cost_price) AS inventory_cost,
    SUM(p.stock_quantity * p.price) AS inventory_retail_value,
    SUM(p.stock_quantity * p.price) - SUM(p.stock_quantity * p.cost_price) AS potential_profit
FROM products p
JOIN categories c ON p.category_id = c.category_id
GROUP BY c.category_id
WITH ROLLUP;

-- TASK 2.3: Product Movement Analysis
-- Fast vs slow moving products based on sales velocity
WITH product_sales AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.stock_quantity,
        COALESCE(SUM(oi.quantity), 0) AS units_sold_30_days,
        DATEDIFF(CURDATE(), MIN(o.order_date)) AS days_since_first_sale
    FROM products p
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN orders o ON oi.order_id = o.order_id 
        AND o.order_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    GROUP BY p.product_id
)
SELECT 
    product_id,
    product_name,
    stock_quantity,
    units_sold_30_days,
    CASE 
        WHEN units_sold_30_days >= 10 THEN 'Fast Moving'
        WHEN units_sold_30_days >= 5 THEN 'Normal'
        WHEN units_sold_30_days > 0 THEN 'Slow Moving'
        ELSE 'No Sales'
    END AS movement_category,
    CASE 
        WHEN units_sold_30_days > 0 THEN 
            ROUND(stock_quantity / (units_sold_30_days / 30.0), 0)
        ELSE NULL
    END AS days_of_stock_remaining
FROM product_sales
ORDER BY units_sold_30_days DESC;

-- TASK 2.4: ABC Analysis
-- Classify products by sales contribution (Pareto)
WITH product_revenue AS (
    SELECT 
        p.product_id,
        p.product_name,
        COALESCE(SUM(oi.line_total), 0) AS total_revenue
    FROM products p
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY p.product_id
),
ranked_products AS (
    SELECT 
        *,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER () AS grand_total
    FROM product_revenue
)
SELECT 
    product_id,
    product_name,
    total_revenue,
    ROUND(total_revenue * 100.0 / grand_total, 2) AS revenue_percentage,
    ROUND(cumulative_revenue * 100.0 / grand_total, 2) AS cumulative_percentage,
    CASE 
        WHEN cumulative_revenue <= grand_total * 0.8 THEN 'A' -- Top 80% revenue
        WHEN cumulative_revenue <= grand_total * 0.95 THEN 'B' -- Next 15%
        ELSE 'C' -- Bottom 5%
    END AS abc_class
FROM ranked_products
ORDER BY total_revenue DESC;

-- ============================================================================
-- PROJECT 3: CUSTOMER RELATIONSHIP MANAGEMENT (CRM)
-- ============================================================================

/*
SCENARIO:
Build CRM analytics to understand customers better and improve
retention and marketing effectiveness.
*/

-- TASK 3.1: Customer Segmentation (RFM Analysis)
WITH customer_rfm AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.district,
        DATEDIFF(CURDATE(), MAX(o.order_date)) AS recency_days,
        COUNT(o.order_id) AS frequency,
        COALESCE(SUM(o.total_amount), 0) AS monetary
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
),
rfm_scores AS (
    SELECT 
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score, -- Lower recency = better = higher score
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM customer_rfm
)
SELECT 
    customer_id,
    customer_name,
    district,
    recency_days,
    frequency,
    monetary,
    CONCAT(r_score, f_score, m_score) AS rfm_score,
    CASE 
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Cant Lose Them'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
        ELSE 'Potential Loyalists'
    END AS customer_segment
FROM rfm_scores
ORDER BY r_score + f_score + m_score DESC;

-- TASK 3.2: Customer Lifetime Value Prediction
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.registration_date,
        DATEDIFF(CURDATE(), c.registration_date) AS customer_age_days,
        COUNT(o.order_id) AS total_orders,
        COALESCE(SUM(o.total_amount), 0) AS total_spent,
        COALESCE(AVG(o.total_amount), 0) AS avg_order_value,
        DATEDIFF(CURDATE(), MAX(o.order_date)) AS days_since_last_order
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
)
SELECT 
    customer_id,
    customer_name,
    total_orders,
    total_spent AS actual_ltv,
    avg_order_value,
    ROUND(
        CASE 
            WHEN customer_age_days > 0 THEN 
                (total_orders / customer_age_days) * 365 * avg_order_value * 3  -- Projected 3-year LTV
            ELSE 0
        END, 0
    ) AS projected_3yr_ltv,
    CASE 
        WHEN days_since_last_order IS NULL THEN 'Never Purchased'
        WHEN days_since_last_order <= 30 THEN 'Active'
        WHEN days_since_last_order <= 90 THEN 'At Risk'
        ELSE 'Churned'
    END AS customer_status
FROM customer_metrics
ORDER BY total_spent DESC;

-- TASK 3.3: Cohort Analysis
-- Customer retention by registration month
WITH first_orders AS (
    SELECT 
        c.customer_id,
        DATE_FORMAT(c.registration_date, '%Y-%m') AS cohort_month,
        MIN(DATE_FORMAT(o.order_date, '%Y-%m')) AS first_order_month
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id
),
cohort_data AS (
    SELECT 
        fo.customer_id,
        fo.cohort_month,
        DATE_FORMAT(o.order_date, '%Y-%m') AS order_month,
        PERIOD_DIFF(
            EXTRACT(YEAR_MONTH FROM o.order_date),
            EXTRACT(YEAR_MONTH FROM STR_TO_DATE(CONCAT(fo.cohort_month, '-01'), '%Y-%m-%d'))
        ) AS months_since_registration
    FROM first_orders fo
    LEFT JOIN orders o ON fo.customer_id = o.customer_id
)
SELECT 
    cohort_month,
    COUNT(DISTINCT customer_id) AS cohort_size,
    COUNT(DISTINCT CASE WHEN months_since_registration = 0 THEN customer_id END) AS month_0,
    COUNT(DISTINCT CASE WHEN months_since_registration = 1 THEN customer_id END) AS month_1,
    COUNT(DISTINCT CASE WHEN months_since_registration = 2 THEN customer_id END) AS month_2,
    COUNT(DISTINCT CASE WHEN months_since_registration = 3 THEN customer_id END) AS month_3
FROM cohort_data
GROUP BY cohort_month
ORDER BY cohort_month;

-- ============================================================================
-- PROJECT 4: EMPLOYEE PERFORMANCE SYSTEM
-- ============================================================================

/*
SCENARIO:
Create performance metrics and reports for the sales team.
*/

-- TASK 4.1: Sales Leaderboard
SELECT 
    e.emp_id,
    e.emp_name,
    e.position,
    COUNT(o.order_id) AS orders_handled,
    SUM(o.total_amount) AS total_sales,
    AVG(o.total_amount) AS avg_order_value,
    e.salary,
    e.commission_rate,
    COALESCE(SUM(o.total_amount) * e.commission_rate, 0) AS commission_earned,
    RANK() OVER (ORDER BY SUM(o.total_amount) DESC) AS sales_rank
FROM employees e
LEFT JOIN orders o ON e.emp_id = o.employee_id
WHERE e.department = 'Sales'
GROUP BY e.emp_id
ORDER BY total_sales DESC;

-- TASK 4.2: Target vs Achievement
-- Assuming monthly targets stored or calculated
WITH monthly_sales AS (
    SELECT 
        e.emp_id,
        e.emp_name,
        DATE_FORMAT(o.order_date, '%Y-%m') AS month,
        COUNT(o.order_id) AS orders,
        SUM(o.total_amount) AS sales
    FROM employees e
    LEFT JOIN orders o ON e.emp_id = o.employee_id
    WHERE e.department = 'Sales'
    GROUP BY e.emp_id, DATE_FORMAT(o.order_date, '%Y-%m')
)
SELECT 
    emp_id,
    emp_name,
    month,
    orders,
    sales,
    5000000 AS target, -- Example target
    ROUND(sales * 100.0 / 5000000, 2) AS achievement_percentage,
    CASE 
        WHEN sales >= 5000000 THEN 'Target Met'
        WHEN sales >= 4000000 THEN 'Almost There'
        ELSE 'Needs Improvement'
    END AS status
FROM monthly_sales
ORDER BY emp_id, month;

-- TASK 4.3: Employee Productivity Trends
WITH weekly_productivity AS (
    SELECT 
        e.emp_id,
        e.emp_name,
        YEARWEEK(o.order_date) AS week,
        COUNT(o.order_id) AS orders_count,
        SUM(o.total_amount) AS weekly_sales
    FROM employees e
    JOIN orders o ON e.emp_id = o.employee_id
    GROUP BY e.emp_id, YEARWEEK(o.order_date)
)
SELECT 
    emp_id,
    emp_name,
    week,
    orders_count,
    weekly_sales,
    LAG(weekly_sales) OVER (PARTITION BY emp_id ORDER BY week) AS prev_week_sales,
    ROUND(
        (weekly_sales - LAG(weekly_sales) OVER (PARTITION BY emp_id ORDER BY week)) * 100.0 /
        NULLIF(LAG(weekly_sales) OVER (PARTITION BY emp_id ORDER BY week), 0), 
        2
    ) AS growth_percent
FROM weekly_productivity
ORDER BY emp_id, week;

-- ============================================================================
-- PROJECT 5: FINANCIAL REPORTING
-- ============================================================================

/*
SCENARIO:
Generate financial reports for management and accounting.
*/

-- TASK 5.1: Profit & Loss Summary
SELECT 
    DATE_FORMAT(o.order_date, '%Y-%m') AS month,
    SUM(oi.line_total) AS gross_revenue,
    SUM(oi.quantity * p.cost_price) AS cost_of_goods,
    SUM(oi.line_total) - SUM(oi.quantity * p.cost_price) AS gross_profit,
    ROUND(
        (SUM(oi.line_total) - SUM(oi.quantity * p.cost_price)) * 100.0 / SUM(oi.line_total),
        2
    ) AS gross_margin_percent
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
WHERE o.status IN ('completed', 'shipped')
GROUP BY DATE_FORMAT(o.order_date, '%Y-%m')
ORDER BY month;

-- TASK 5.2: Payment Method Analysis
SELECT 
    payment_method,
    COUNT(*) AS transaction_count,
    SUM(total_amount) AS total_value,
    AVG(total_amount) AS avg_transaction,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM orders), 2) AS percentage_of_transactions,
    ROUND(SUM(total_amount) * 100.0 / (SELECT SUM(total_amount) FROM orders), 2) AS percentage_of_value
FROM orders
GROUP BY payment_method
ORDER BY total_value DESC;

-- TASK 5.3: Daily Cash Flow Report
SELECT 
    DATE(order_date) AS date,
    COUNT(*) AS transactions,
    SUM(CASE WHEN status = 'completed' THEN total_amount ELSE 0 END) AS completed_sales,
    SUM(CASE WHEN status = 'pending' THEN total_amount ELSE 0 END) AS pending_sales,
    SUM(CASE WHEN status = 'shipped' THEN total_amount ELSE 0 END) AS shipped_sales,
    SUM(total_amount) AS gross_sales
FROM orders
GROUP BY DATE(order_date)
ORDER BY date DESC
LIMIT 30;

-- ============================================================================
-- BONUS: ADVANCED ANALYTICS QUERIES
-- ============================================================================

-- Market Basket Analysis (Products bought together)
SELECT 
    p1.product_name AS product_1,
    p2.product_name AS product_2,
    COUNT(*) AS times_bought_together
FROM order_items oi1
JOIN order_items oi2 ON oi1.order_id = oi2.order_id AND oi1.product_id < oi2.product_id
JOIN products p1 ON oi1.product_id = p1.product_id
JOIN products p2 ON oi2.product_id = p2.product_id
GROUP BY oi1.product_id, oi2.product_id
HAVING COUNT(*) > 1
ORDER BY times_bought_together DESC
LIMIT 10;

-- Customer Purchase Patterns (Day of Week Analysis)
SELECT 
    DAYNAME(order_date) AS day_of_week,
    DAYOFWEEK(order_date) AS day_num,
    COUNT(*) AS orders,
    SUM(total_amount) AS revenue,
    AVG(total_amount) AS avg_order_value
FROM orders
GROUP BY DAYOFWEEK(order_date), DAYNAME(order_date)
ORDER BY day_num;

-- Hourly Sales Pattern
SELECT 
    HOUR(order_date) AS hour_of_day,
    COUNT(*) AS orders,
    SUM(total_amount) AS revenue
FROM orders
GROUP BY HOUR(order_date)
ORDER BY hour_of_day;

-- ============================================================================
-- END OF REAL-WORLD PROJECTS
-- ============================================================================
