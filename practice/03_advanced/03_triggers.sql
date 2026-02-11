-- ============================================================================
-- SQL TRIGGERS: AUTOMATED DATABASE ACTIONS
-- Module 14: Event-Driven Database Programming
-- Goal: Master triggers for data integrity, auditing, and automation
-- ============================================================================

-- ============================================================================
-- SECTION 1: TRIGGER BASICS
-- ============================================================================

/*
TRIGGERS:
- Automatic procedures executed on table events
- Events: INSERT, UPDATE, DELETE
- Timing: BEFORE or AFTER the event
- Access to OLD and NEW row values

Use Cases:
- Maintain audit trails
- Enforce complex business rules
- Synchronize related tables
- Auto-calculate derived values
- Prevent invalid operations
*/

-- Setup: Sample tables
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100),
    price DECIMAL(10,2),
    stock_quantity INT,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE product_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT,
    action_type VARCHAR(10),
    old_price DECIMAL(10,2),
    new_price DECIMAL(10,2),
    old_stock INT,
    new_stock INT,
    changed_by VARCHAR(50),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE stock_alerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT,
    alert_type VARCHAR(50),
    message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SECTION 2: AFTER INSERT TRIGGER
-- ============================================================================

DELIMITER //

-- Log new product creation
CREATE TRIGGER after_product_insert
AFTER INSERT ON products
FOR EACH ROW
BEGIN
    INSERT INTO product_audit (
        product_id, 
        action_type, 
        new_price, 
        new_stock, 
        changed_by
    )
    VALUES (
        NEW.product_id,
        'INSERT',
        NEW.price,
        NEW.stock_quantity,
        USER()
    );
    
    -- Check if initial stock is low
    IF NEW.stock_quantity < 10 THEN
        INSERT INTO stock_alerts (product_id, alert_type, message)
        VALUES (
            NEW.product_id,
            'LOW_INITIAL_STOCK',
            CONCAT('New product ', NEW.product_name, ' added with low stock: ', NEW.stock_quantity)
        );
    END IF;
END //

DELIMITER ;

-- Test it
INSERT INTO products (product_name, price, stock_quantity) VALUES ('Laptop', 4000000, 5);
SELECT * FROM product_audit;
SELECT * FROM stock_alerts;

-- ============================================================================
-- SECTION 3: BEFORE INSERT TRIGGER
-- ============================================================================

DELIMITER //

-- Validate and modify data before insert
CREATE TRIGGER before_product_insert
BEFORE INSERT ON products
FOR EACH ROW
BEGIN
    -- Ensure positive values
    IF NEW.price < 0 THEN
        SET NEW.price = 0;
    END IF;
    
    IF NEW.stock_quantity < 0 THEN
        SET NEW.stock_quantity = 0;
    END IF;
    
    -- Auto-capitalize product name
    SET NEW.product_name = CONCAT(
        UPPER(LEFT(NEW.product_name, 1)), 
        LOWER(SUBSTRING(NEW.product_name, 2))
    );
    
    -- Set timestamp
    SET NEW.last_updated = NOW();
END //

DELIMITER ;

-- ============================================================================
-- SECTION 4: AFTER UPDATE TRIGGER
-- ============================================================================

DELIMITER //

-- Comprehensive update auditing
CREATE TRIGGER after_product_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    -- Always log the update
    INSERT INTO product_audit (
        product_id,
        action_type,
        old_price,
        new_price,
        old_stock,
        new_stock,
        changed_by
    )
    VALUES (
        NEW.product_id,
        'UPDATE',
        OLD.price,
        NEW.price,
        OLD.stock_quantity,
        NEW.stock_quantity,
        USER()
    );
    
    -- Alert on significant price changes (>20%)
    IF OLD.price > 0 AND ABS(NEW.price - OLD.price) / OLD.price > 0.20 THEN
        INSERT INTO stock_alerts (product_id, alert_type, message)
        VALUES (
            NEW.product_id,
            'PRICE_CHANGE',
            CONCAT('Significant price change on ', NEW.product_name, 
                   ': ', OLD.price, ' -> ', NEW.price)
        );
    END IF;
    
    -- Alert when stock falls below threshold
    IF OLD.stock_quantity >= 10 AND NEW.stock_quantity < 10 THEN
        INSERT INTO stock_alerts (product_id, alert_type, message)
        VALUES (
            NEW.product_id,
            'LOW_STOCK',
            CONCAT('Low stock alert for ', NEW.product_name, ': ', NEW.stock_quantity, ' remaining')
        );
    END IF;
    
    -- Alert when out of stock
    IF OLD.stock_quantity > 0 AND NEW.stock_quantity = 0 THEN
        INSERT INTO stock_alerts (product_id, alert_type, message)
        VALUES (
            NEW.product_id,
            'OUT_OF_STOCK',
            CONCAT(NEW.product_name, ' is now OUT OF STOCK!')
        );
    END IF;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 5: BEFORE UPDATE TRIGGER
-- ============================================================================

DELIMITER //

-- Validate updates and enforce business rules
CREATE TRIGGER before_product_update
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
    -- Update timestamp
    SET NEW.last_updated = NOW();
    
    -- Prevent negative values
    IF NEW.price < 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Price cannot be negative';
    END IF;
    
    IF NEW.stock_quantity < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock quantity cannot be negative';
    END IF;
    
    -- Prevent price increase of more than 50% at once
    IF NEW.price > OLD.price * 1.5 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Price increase cannot exceed 50% at once';
    END IF;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 6: DELETE TRIGGERS
-- ============================================================================

DELIMITER //

-- Prevent deletion and log attempts
CREATE TRIGGER before_product_delete
BEFORE DELETE ON products
FOR EACH ROW
BEGIN
    -- Check if product has been ordered
    DECLARE v_order_count INT;
    
    SELECT COUNT(*) INTO v_order_count
    FROM order_items
    WHERE product_id = OLD.product_id;
    
    IF v_order_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot delete product with existing orders. Archive instead.';
    END IF;
END //

CREATE TRIGGER after_product_delete
AFTER DELETE ON products
FOR EACH ROW
BEGIN
    -- Log the deletion
    INSERT INTO product_audit (
        product_id,
        action_type,
        old_price,
        old_stock,
        changed_by
    )
    VALUES (
        OLD.product_id,
        'DELETE',
        OLD.price,
        OLD.stock_quantity,
        USER()
    );
END //

DELIMITER ;

-- ============================================================================
-- SECTION 7: PRACTICAL TRIGGER EXAMPLES
-- ============================================================================

-- Example 1: Auto-calculate order totals
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    subtotal DECIMAL(12,2) DEFAULT 0,
    tax DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'pending'
);

CREATE TABLE order_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    unit_price DECIMAL(10,2),
    line_total DECIMAL(12,2)
);

DELIMITER //

CREATE TRIGGER after_order_item_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE orders
    SET 
        subtotal = (SELECT COALESCE(SUM(line_total), 0) FROM order_items WHERE order_id = NEW.order_id),
        tax = (SELECT COALESCE(SUM(line_total), 0) FROM order_items WHERE order_id = NEW.order_id) * 0.18,
        total = (SELECT COALESCE(SUM(line_total), 0) FROM order_items WHERE order_id = NEW.order_id) * 1.18
    WHERE order_id = NEW.order_id;
END //

CREATE TRIGGER before_order_item_insert
BEFORE INSERT ON order_items
FOR EACH ROW
BEGIN
    SET NEW.line_total = NEW.quantity * NEW.unit_price;
END //

DELIMITER ;

-- Example 2: Maintain account balance
CREATE TABLE accounts (
    account_id INT PRIMARY KEY,
    account_name VARCHAR(100),
    balance DECIMAL(15,2) DEFAULT 0
);

CREATE TABLE transactions (
    txn_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    txn_type VARCHAR(10),  -- 'credit' or 'debit'
    amount DECIMAL(15,2),
    txn_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

CREATE TRIGGER after_transaction_insert
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
    IF NEW.txn_type = 'credit' THEN
        UPDATE accounts 
        SET balance = balance + NEW.amount 
        WHERE account_id = NEW.account_id;
    ELSEIF NEW.txn_type = 'debit' THEN
        UPDATE accounts 
        SET balance = balance - NEW.amount 
        WHERE account_id = NEW.account_id;
    END IF;
END //

CREATE TRIGGER before_transaction_insert
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    DECLARE v_balance DECIMAL(15,2);
    
    IF NEW.txn_type = 'debit' THEN
        SELECT balance INTO v_balance 
        FROM accounts 
        WHERE account_id = NEW.account_id;
        
        IF v_balance < NEW.amount THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient funds';
        END IF;
    END IF;
END //

DELIMITER ;

-- Example 3: Customer lifetime value tracking
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    total_orders INT DEFAULT 0,
    lifetime_value DECIMAL(15,2) DEFAULT 0,
    last_order_date TIMESTAMP,
    customer_tier VARCHAR(20) DEFAULT 'Bronze'
);

DELIMITER //

CREATE TRIGGER after_order_insert
AFTER INSERT ON orders
FOR EACH ROW
BEGIN
    -- Update customer statistics
    UPDATE customers
    SET 
        total_orders = total_orders + 1,
        lifetime_value = lifetime_value + NEW.total,
        last_order_date = NOW(),
        customer_tier = CASE 
            WHEN lifetime_value + NEW.total >= 50000000 THEN 'Platinum'
            WHEN lifetime_value + NEW.total >= 20000000 THEN 'Gold'
            WHEN lifetime_value + NEW.total >= 5000000 THEN 'Silver'
            ELSE 'Bronze'
        END
    WHERE customer_id = NEW.customer_id;
END //

DELIMITER ;

-- Example 4: Inventory management with history
CREATE TABLE inventory_history (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    product_id INT,
    change_type VARCHAR(50),
    quantity_change INT,
    old_quantity INT,
    new_quantity INT,
    reference_type VARCHAR(50),
    reference_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

CREATE TRIGGER after_product_stock_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    IF OLD.stock_quantity != NEW.stock_quantity THEN
        INSERT INTO inventory_history (
            product_id,
            change_type,
            quantity_change,
            old_quantity,
            new_quantity,
            reference_type
        )
        VALUES (
            NEW.product_id,
            CASE 
                WHEN NEW.stock_quantity > OLD.stock_quantity THEN 'INCREASE'
                ELSE 'DECREASE'
            END,
            NEW.stock_quantity - OLD.stock_quantity,
            OLD.stock_quantity,
            NEW.stock_quantity,
            'MANUAL_ADJUSTMENT'
        );
    END IF;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 8: TRIGGER MANAGEMENT
-- ============================================================================

-- Show all triggers
SHOW TRIGGERS;

-- Show triggers for specific table
SHOW TRIGGERS LIKE 'products';

-- Show trigger definition
SHOW CREATE TRIGGER after_product_insert;

-- Drop trigger
DROP TRIGGER IF EXISTS old_trigger;

-- Disable triggers temporarily (MySQL: not directly supported)
-- Workaround: Drop and recreate, or use variable flag

DELIMITER //

CREATE TRIGGER conditional_trigger
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
    -- Check if triggers should run
    IF @disable_triggers IS NULL OR @disable_triggers != TRUE THEN
        -- Trigger logic here
        SET NEW.last_updated = NOW();
    END IF;
END //

DELIMITER ;

-- Disable
SET @disable_triggers = TRUE;
UPDATE products SET price = 1000 WHERE product_id = 1;

-- Re-enable
SET @disable_triggers = NULL;

-- ============================================================================
-- SECTION 9: TRIGGER BEST PRACTICES
-- ============================================================================

/*
BEST PRACTICES:

1. Keep triggers simple and fast
   - Avoid complex queries
   - Don't call stored procedures with side effects

2. Be careful with recursive triggers
   - Trigger A updates table B, which triggers another action
   
3. Document trigger behavior
   - Team members need to know what happens automatically

4. Use for data integrity, not business logic
   - Complex rules belong in application layer

5. Consider performance impact
   - Triggers run on EVERY affected row
   - Batch operations can be slow

6. Test thoroughly
   - Test with NULL values
   - Test with edge cases
   - Test with bulk operations

7. Log trigger errors
   - Silent failures are dangerous

ANTI-PATTERNS:

- Calling external APIs from triggers
- Complex calculations on large datasets
- Triggers that trigger other triggers endlessly
- Business logic that should be in application
*/

-- ============================================================================
-- SECTION 10: ADVANCED TRIGGER PATTERNS
-- ============================================================================

-- Pattern: Soft delete with trigger
ALTER TABLE products ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;
ALTER TABLE products ADD COLUMN deleted_at TIMESTAMP NULL;

DELIMITER //

CREATE TRIGGER before_product_soft_delete
BEFORE UPDATE ON products
FOR EACH ROW
BEGIN
    IF NEW.is_deleted = TRUE AND OLD.is_deleted = FALSE THEN
        SET NEW.deleted_at = NOW();
    ELSEIF NEW.is_deleted = FALSE AND OLD.is_deleted = TRUE THEN
        SET NEW.deleted_at = NULL;
    END IF;
END //

DELIMITER ;

-- Pattern: Change data capture
CREATE TABLE cdc_log (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(50),
    record_id INT,
    operation VARCHAR(10),
    old_data JSON,
    new_data JSON,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

CREATE TRIGGER products_cdc_insert
AFTER INSERT ON products
FOR EACH ROW
BEGIN
    INSERT INTO cdc_log (table_name, record_id, operation, new_data)
    VALUES (
        'products',
        NEW.product_id,
        'INSERT',
        JSON_OBJECT(
            'product_name', NEW.product_name,
            'price', NEW.price,
            'stock_quantity', NEW.stock_quantity
        )
    );
END //

CREATE TRIGGER products_cdc_update
AFTER UPDATE ON products
FOR EACH ROW
BEGIN
    INSERT INTO cdc_log (table_name, record_id, operation, old_data, new_data)
    VALUES (
        'products',
        NEW.product_id,
        'UPDATE',
        JSON_OBJECT(
            'product_name', OLD.product_name,
            'price', OLD.price,
            'stock_quantity', OLD.stock_quantity
        ),
        JSON_OBJECT(
            'product_name', NEW.product_name,
            'price', NEW.price,
            'stock_quantity', NEW.stock_quantity
        )
    );
END //

DELIMITER ;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Create triggers for:
a) Auto-set created_at and updated_at timestamps
b) Prevent deletion of customers with pending orders
c) Log all login attempts (success and failure)
d) Maintain running balance in account statement

EXERCISE 2: Audit triggers:
a) Complete audit trail for customer table
b) Track all price changes with reason
c) Log user activity with IP address
d) Change history with rollback capability

EXERCISE 3: Business rule triggers:
a) Enforce minimum order value
b) Auto-apply loyalty discount
c) Stock reservation on order
d) Credit limit enforcement

EXERCISE 4: Data synchronization triggers:
a) Keep denormalized counter updated
b) Sync primary and backup tables
c) Update search index on change
d) Maintain materialized view equivalent

EXERCISE 5: Complex scenarios:
a) Implement approval workflow
b) Create bi-temporal history tracking
c) Build event sourcing pattern
d) Implement row-level security via triggers

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

