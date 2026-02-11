-- ============================================================================
-- SQL STORED PROCEDURES AND FUNCTIONS
-- Module 13: Procedural SQL Programming
-- Goal: Master stored routines for business logic and automation
-- ============================================================================

-- ============================================================================
-- SECTION 1: STORED PROCEDURE BASICS
-- ============================================================================

/*
STORED PROCEDURES:
- Precompiled SQL code stored in database
- Can accept parameters (IN, OUT, INOUT)
- Can contain control flow (IF, LOOP, etc.)
- Cannot be used in SELECT statements
*/

-- Change delimiter for procedure body
DELIMITER //

-- Basic procedure (no parameters)
CREATE PROCEDURE get_all_products()
BEGIN
    SELECT * FROM products ORDER BY product_name;
END //

DELIMITER ;

-- Call procedure
CALL get_all_products();

-- Procedure with IN parameter
DELIMITER //

CREATE PROCEDURE get_products_by_category(IN p_category VARCHAR(50))
BEGIN
    SELECT * FROM products 
    WHERE category = p_category
    ORDER BY price DESC;
END //

DELIMITER ;

CALL get_products_by_category('Electronics');

-- Procedure with OUT parameter
DELIMITER //

CREATE PROCEDURE get_product_count(
    IN p_category VARCHAR(50),
    OUT p_count INT
)
BEGIN
    SELECT COUNT(*) INTO p_count
    FROM products
    WHERE category = p_category;
END //

DELIMITER ;

CALL get_product_count('Electronics', @product_count);
SELECT @product_count;

-- Procedure with INOUT parameter
DELIMITER //

CREATE PROCEDURE apply_discount(INOUT p_price DECIMAL(10,2), IN p_discount_percent DECIMAL(5,2))
BEGIN
    SET p_price = p_price * (1 - p_discount_percent / 100);
END //

DELIMITER ;

SET @price = 1000000;
CALL apply_discount(@price, 10);
SELECT @price;  -- 900000

-- ============================================================================
-- SECTION 2: STORED FUNCTIONS
-- ============================================================================

/*
STORED FUNCTIONS:
- Must return a single value
- Can be used in SELECT statements
- Cannot have OUT/INOUT parameters
- Should be deterministic when possible
*/

DELIMITER //

-- Basic function
CREATE FUNCTION calculate_vat(p_amount DECIMAL(15,2))
RETURNS DECIMAL(15,2)
DETERMINISTIC
BEGIN
    RETURN p_amount * 0.18;  -- 18% VAT
END //

DELIMITER ;

-- Use function in SELECT
SELECT 
    product_name,
    price,
    calculate_vat(price) AS vat,
    price + calculate_vat(price) AS price_with_vat
FROM products;

-- Function with conditional logic
DELIMITER //

CREATE FUNCTION get_price_tier(p_price DECIMAL(15,2))
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN
    DECLARE tier VARCHAR(20);
    
    IF p_price >= 5000000 THEN
        SET tier = 'Premium';
    ELSEIF p_price >= 2000000 THEN
        SET tier = 'Mid-Range';
    ELSEIF p_price >= 500000 THEN
        SET tier = 'Budget';
    ELSE
        SET tier = 'Economy';
    END IF;
    
    RETURN tier;
END //

DELIMITER ;

SELECT product_name, price, get_price_tier(price) AS tier FROM products;

-- Function for business calculations
DELIMITER //

CREATE FUNCTION calculate_commission(
    p_sales_amount DECIMAL(15,2),
    p_employee_tier VARCHAR(20)
)
RETURNS DECIMAL(15,2)
DETERMINISTIC
BEGIN
    DECLARE commission_rate DECIMAL(5,4);
    
    CASE p_employee_tier
        WHEN 'Senior' THEN SET commission_rate = 0.08;
        WHEN 'Regular' THEN SET commission_rate = 0.05;
        WHEN 'Junior' THEN SET commission_rate = 0.03;
        ELSE SET commission_rate = 0.02;
    END CASE;
    
    -- Bonus for high sales
    IF p_sales_amount > 50000000 THEN
        SET commission_rate = commission_rate + 0.02;
    END IF;
    
    RETURN p_sales_amount * commission_rate;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 3: VARIABLES AND DATA TYPES
-- ============================================================================

DELIMITER //

CREATE PROCEDURE demonstrate_variables()
BEGIN
    -- Local variables (must be declared first)
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_name VARCHAR(100);
    DECLARE v_price DECIMAL(10,2);
    DECLARE v_is_active BOOLEAN DEFAULT TRUE;
    DECLARE v_created_date DATE DEFAULT CURDATE();
    
    -- Assign values using SET
    SET v_count = 10;
    SET v_name = 'Test Product';
    SET v_price = 1500000.00;
    
    -- Assign values using SELECT INTO
    SELECT COUNT(*), MAX(price) INTO v_count, v_price
    FROM products;
    
    -- User-defined variables (session scope, prefixed with @)
    SET @session_var = 'This persists in session';
    
    -- Use variables
    SELECT v_count AS count, v_price AS max_price, @session_var AS session_variable;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 4: CONTROL FLOW STATEMENTS
-- ============================================================================

-- IF-ELSEIF-ELSE
DELIMITER //

CREATE PROCEDURE categorize_customer(
    IN p_customer_id INT,
    OUT p_category VARCHAR(20)
)
BEGIN
    DECLARE v_total_spent DECIMAL(15,2);
    DECLARE v_order_count INT;
    
    SELECT COALESCE(SUM(total_amount), 0), COUNT(*)
    INTO v_total_spent, v_order_count
    FROM orders
    WHERE customer_id = p_customer_id;
    
    IF v_total_spent >= 50000000 AND v_order_count >= 10 THEN
        SET p_category = 'Platinum';
    ELSEIF v_total_spent >= 20000000 AND v_order_count >= 5 THEN
        SET p_category = 'Gold';
    ELSEIF v_total_spent >= 5000000 THEN
        SET p_category = 'Silver';
    ELSE
        SET p_category = 'Bronze';
    END IF;
END //

DELIMITER ;

-- CASE statement
DELIMITER //

CREATE PROCEDURE get_order_status_message(
    IN p_status VARCHAR(20),
    OUT p_message VARCHAR(200)
)
BEGIN
    CASE p_status
        WHEN 'pending' THEN 
            SET p_message = 'Your order is being processed. Please wait.';
        WHEN 'shipped' THEN 
            SET p_message = 'Your order has been shipped and is on its way!';
        WHEN 'delivered' THEN 
            SET p_message = 'Your order has been delivered. Thank you!';
        WHEN 'cancelled' THEN 
            SET p_message = 'Your order has been cancelled.';
        ELSE 
            SET p_message = 'Unknown order status.';
    END CASE;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 5: LOOPS
-- ============================================================================

-- WHILE loop
DELIMITER //

CREATE PROCEDURE generate_numbers(IN p_count INT)
BEGIN
    DECLARE v_counter INT DEFAULT 1;
    
    CREATE TEMPORARY TABLE temp_numbers (num INT);
    
    WHILE v_counter <= p_count DO
        INSERT INTO temp_numbers VALUES (v_counter);
        SET v_counter = v_counter + 1;
    END WHILE;
    
    SELECT * FROM temp_numbers;
    DROP TEMPORARY TABLE temp_numbers;
END //

DELIMITER ;

-- REPEAT loop (executes at least once)
DELIMITER //

CREATE PROCEDURE countdown(IN p_start INT)
BEGIN
    DECLARE v_num INT;
    SET v_num = p_start;
    
    CREATE TEMPORARY TABLE temp_countdown (num INT);
    
    REPEAT
        INSERT INTO temp_countdown VALUES (v_num);
        SET v_num = v_num - 1;
    UNTIL v_num < 0
    END REPEAT;
    
    SELECT * FROM temp_countdown;
    DROP TEMPORARY TABLE temp_countdown;
END //

DELIMITER ;

-- LOOP with LEAVE (labeled loop)
DELIMITER //

CREATE PROCEDURE process_batches()
BEGIN
    DECLARE v_batch INT DEFAULT 0;
    DECLARE v_processed INT DEFAULT 0;
    
    batch_loop: LOOP
        SET v_batch = v_batch + 1;
        
        -- Process batch logic here
        SET v_processed = v_processed + 100;
        
        -- Exit conditions
        IF v_batch >= 10 THEN
            LEAVE batch_loop;
        END IF;
        
        -- Skip certain batches
        IF v_batch = 5 THEN
            ITERATE batch_loop;  -- Continue to next iteration
        END IF;
        
        SELECT CONCAT('Processing batch ', v_batch) AS message;
    END LOOP;
    
    SELECT v_processed AS total_processed;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 6: CURSORS
-- ============================================================================

/*
CURSORS:
- Process result sets row by row
- Useful for complex row-level operations
- Slower than set-based operations; use judiciously
*/

DELIMITER //

CREATE PROCEDURE process_low_stock_alerts()
BEGIN
    -- Variables for cursor
    DECLARE v_product_id INT;
    DECLARE v_product_name VARCHAR(100);
    DECLARE v_stock INT;
    DECLARE v_reorder_level INT;
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    
    -- Declare cursor
    DECLARE low_stock_cursor CURSOR FOR
        SELECT product_id, product_name, stock_quantity, reorder_level
        FROM products
        WHERE stock_quantity < reorder_level;
    
    -- Handler for when no more rows
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    
    -- Create alerts table
    CREATE TEMPORARY TABLE temp_alerts (
        product_id INT,
        product_name VARCHAR(100),
        current_stock INT,
        reorder_level INT,
        alert_message VARCHAR(200)
    );
    
    -- Open cursor
    OPEN low_stock_cursor;
    
    -- Loop through rows
    read_loop: LOOP
        FETCH low_stock_cursor INTO v_product_id, v_product_name, v_stock, v_reorder_level;
        
        IF v_done THEN
            LEAVE read_loop;
        END IF;
        
        -- Process each row
        INSERT INTO temp_alerts VALUES (
            v_product_id,
            v_product_name,
            v_stock,
            v_reorder_level,
            CONCAT('ALERT: ', v_product_name, ' needs restock. Current: ', v_stock, 
                   ', Reorder Level: ', v_reorder_level)
        );
    END LOOP;
    
    -- Close cursor
    CLOSE low_stock_cursor;
    
    -- Return results
    SELECT * FROM temp_alerts;
    DROP TEMPORARY TABLE temp_alerts;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 7: ERROR HANDLING
-- ============================================================================

DELIMITER //

CREATE PROCEDURE safe_transfer(
    IN p_from_account INT,
    IN p_to_account INT,
    IN p_amount DECIMAL(15,2),
    OUT p_status VARCHAR(100)
)
BEGIN
    DECLARE v_from_balance DECIMAL(15,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_status = 'ERROR: Transaction failed';
    END;
    
    DECLARE EXIT HANDLER FOR SQLWARNING
    BEGIN
        ROLLBACK;
        SET p_status = 'WARNING: Transaction rolled back';
    END;
    
    START TRANSACTION;
    
    -- Check balance
    SELECT balance INTO v_from_balance 
    FROM accounts WHERE account_id = p_from_account FOR UPDATE;
    
    IF v_from_balance IS NULL THEN
        SET p_status = 'ERROR: Source account not found';
        ROLLBACK;
    ELSEIF v_from_balance < p_amount THEN
        SET p_status = 'ERROR: Insufficient funds';
        ROLLBACK;
    ELSE
        -- Perform transfer
        UPDATE accounts SET balance = balance - p_amount 
        WHERE account_id = p_from_account;
        
        UPDATE accounts SET balance = balance + p_amount 
        WHERE account_id = p_to_account;
        
        -- Log transaction
        INSERT INTO transactions (from_account, to_account, amount, transaction_date)
        VALUES (p_from_account, p_to_account, p_amount, NOW());
        
        COMMIT;
        SET p_status = CONCAT('SUCCESS: Transferred ', p_amount);
    END IF;
END //

DELIMITER ;

-- Custom error with SIGNAL
DELIMITER //

CREATE PROCEDURE validate_order(IN p_order_id INT)
BEGIN
    DECLARE v_total DECIMAL(15,2);
    DECLARE v_customer_credit DECIMAL(15,2);
    
    SELECT o.total_amount, c.credit_limit
    INTO v_total, v_customer_credit
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_id = p_order_id;
    
    IF v_total > v_customer_credit THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Order exceeds customer credit limit',
            MYSQL_ERRNO = 1644;
    END IF;
    
    SELECT 'Order validated successfully' AS result;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 8: PRACTICAL PROCEDURES
-- ============================================================================

-- Procedure: Create new order
DELIMITER //

CREATE PROCEDURE create_order(
    IN p_customer_id INT,
    IN p_items JSON,
    OUT p_order_id INT,
    OUT p_status VARCHAR(100)
)
BEGIN
    DECLARE v_item_count INT;
    DECLARE v_total DECIMAL(15,2) DEFAULT 0;
    DECLARE v_i INT DEFAULT 0;
    DECLARE v_product_id INT;
    DECLARE v_quantity INT;
    DECLARE v_unit_price DECIMAL(15,2);
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_order_id = NULL;
        SET p_status = 'ERROR: Order creation failed';
    END;
    
    START TRANSACTION;
    
    -- Create order header
    INSERT INTO orders (customer_id, order_date, status, total_amount)
    VALUES (p_customer_id, NOW(), 'pending', 0);
    
    SET p_order_id = LAST_INSERT_ID();
    
    -- Process items from JSON array
    SET v_item_count = JSON_LENGTH(p_items);
    
    WHILE v_i < v_item_count DO
        SET v_product_id = JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].product_id'));
        SET v_quantity = JSON_EXTRACT(p_items, CONCAT('$[', v_i, '].quantity'));
        
        -- Get current price
        SELECT price INTO v_unit_price FROM products WHERE product_id = v_product_id;
        
        -- Check stock
        IF (SELECT stock_quantity FROM products WHERE product_id = v_product_id) < v_quantity THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient stock';
        END IF;
        
        -- Insert order item
        INSERT INTO order_items (order_id, product_id, quantity, unit_price)
        VALUES (p_order_id, v_product_id, v_quantity, v_unit_price);
        
        -- Update stock
        UPDATE products SET stock_quantity = stock_quantity - v_quantity
        WHERE product_id = v_product_id;
        
        SET v_total = v_total + (v_unit_price * v_quantity);
        SET v_i = v_i + 1;
    END WHILE;
    
    -- Update order total
    UPDATE orders SET total_amount = v_total WHERE order_id = p_order_id;
    
    COMMIT;
    SET p_status = CONCAT('SUCCESS: Order ', p_order_id, ' created with total ', v_total);
END //

DELIMITER ;

-- Procedure: Monthly report generation
DELIMITER //

CREATE PROCEDURE generate_monthly_report(IN p_year INT, IN p_month INT)
BEGIN
    -- Sales summary
    SELECT 
        'Sales Summary' AS report_section,
        COUNT(*) AS total_orders,
        SUM(total_amount) AS total_revenue,
        AVG(total_amount) AS avg_order_value
    FROM orders
    WHERE YEAR(order_date) = p_year AND MONTH(order_date) = p_month;
    
    -- Top products
    SELECT 
        'Top Products' AS report_section,
        p.product_name,
        SUM(oi.quantity) AS units_sold,
        SUM(oi.quantity * oi.unit_price) AS revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN products p ON oi.product_id = p.product_id
    WHERE YEAR(o.order_date) = p_year AND MONTH(o.order_date) = p_month
    GROUP BY p.product_id
    ORDER BY revenue DESC
    LIMIT 10;
    
    -- Sales by region
    SELECT 
        'Sales by Region' AS report_section,
        c.district,
        COUNT(*) AS orders,
        SUM(o.total_amount) AS revenue
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE YEAR(o.order_date) = p_year AND MONTH(o.order_date) = p_month
    GROUP BY c.district
    ORDER BY revenue DESC;
    
    -- Employee performance
    SELECT 
        'Employee Performance' AS report_section,
        e.emp_name,
        COUNT(*) AS orders_handled,
        SUM(o.total_amount) AS revenue_generated
    FROM orders o
    JOIN employees e ON o.salesperson_id = e.emp_id
    WHERE YEAR(o.order_date) = p_year AND MONTH(o.order_date) = p_month
    GROUP BY e.emp_id
    ORDER BY revenue_generated DESC;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 9: PROCEDURE MANAGEMENT
-- ============================================================================

-- Show all procedures
SHOW PROCEDURE STATUS WHERE Db = DATABASE();

-- Show procedure definition
SHOW CREATE PROCEDURE generate_monthly_report;

-- Drop procedure
DROP PROCEDURE IF EXISTS old_procedure;

-- Alter procedure (must recreate in MySQL)
-- DROP and CREATE with new definition

-- Show all functions
SHOW FUNCTION STATUS WHERE Db = DATABASE();

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Create procedures for:
a) Get customer order history with pagination
b) Update product prices by category (percentage increase)
c) Process batch of pending orders
d) Archive old records to history tables

EXERCISE 2: Create functions for:
a) Calculate age from birth date
b) Generate order number (prefix + year + sequence)
c) Calculate shipping cost based on weight and destination
d) Validate Uganda phone number format

EXERCISE 3: Implement cursor-based procedures for:
a) Send renewal reminders (process each customer)
b) Calculate and update customer loyalty points
c) Generate personalized recommendations
d) Recalculate all order totals

EXERCISE 4: Error handling procedures:
a) Safe money transfer with full validation
b) Inventory adjustment with audit trail
c) Customer account merge with conflict resolution
d) Data import with error logging

EXERCISE 5: Complex business procedures:
a) End-of-day processing (close orders, update stats)
b) Subscription billing with proration calculation
c) Inventory reorder automation
d) Customer credit limit review and adjustment

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

