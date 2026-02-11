-- ============================================================================
-- SQL TRANSACTIONS AND CONCURRENCY CONTROL
-- Module 15: ACID Properties and Transaction Management
-- Goal: Master transaction handling for data integrity
-- ============================================================================

-- ============================================================================
-- SECTION 1: TRANSACTION FUNDAMENTALS
-- ============================================================================

/*
ACID PROPERTIES:

Atomicity: All operations succeed or all fail
Consistency: Database moves from one valid state to another
Isolation: Concurrent transactions don't interfere
Durability: Committed changes persist

TRANSACTION COMMANDS:
- START TRANSACTION / BEGIN
- COMMIT
- ROLLBACK
- SAVEPOINT
- ROLLBACK TO SAVEPOINT
*/

-- Basic transaction structure
START TRANSACTION;

-- Multiple operations
INSERT INTO accounts (account_id, balance) VALUES (1, 1000000);
INSERT INTO accounts (account_id, balance) VALUES (2, 500000);
UPDATE accounts SET balance = balance - 100000 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 100000 WHERE account_id = 2;

COMMIT;  -- Make changes permanent

-- Transaction with rollback
START TRANSACTION;

UPDATE accounts SET balance = balance - 1000000 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 1000000 WHERE account_id = 2;

-- Oops, wrong amount!
ROLLBACK;  -- Undo all changes

-- ============================================================================
-- SECTION 2: SAVEPOINTS
-- ============================================================================

START TRANSACTION;

INSERT INTO orders (customer_id, total_amount, status) VALUES (1, 500000, 'pending');
SET @order_id = LAST_INSERT_ID();

SAVEPOINT order_created;

INSERT INTO order_items (order_id, product_id, quantity, unit_price) 
VALUES (@order_id, 1, 2, 100000);

INSERT INTO order_items (order_id, product_id, quantity, unit_price) 
VALUES (@order_id, 2, 1, 300000);

SAVEPOINT items_added;

-- Try to add another item
INSERT INTO order_items (order_id, product_id, quantity, unit_price) 
VALUES (@order_id, 999, 1, 50000);  -- Product 999 doesn't exist

-- This would fail, so rollback to savepoint
ROLLBACK TO SAVEPOINT items_added;

-- Continue with other operations
UPDATE orders SET status = 'confirmed' WHERE order_id = @order_id;

COMMIT;

-- ============================================================================
-- SECTION 3: PRACTICAL TRANSACTION EXAMPLES
-- ============================================================================

-- Example 1: Money Transfer
DELIMITER //

CREATE PROCEDURE transfer_money(
    IN p_from_account INT,
    IN p_to_account INT,
    IN p_amount DECIMAL(15,2),
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE v_from_balance DECIMAL(15,2);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'ERROR: Transfer failed';
    END;
    
    START TRANSACTION;
    
    -- Lock the rows for update
    SELECT balance INTO v_from_balance
    FROM accounts
    WHERE account_id = p_from_account
    FOR UPDATE;
    
    -- Check sufficient funds
    IF v_from_balance < p_amount THEN
        ROLLBACK;
        SET p_result = 'ERROR: Insufficient funds';
    ELSE
        -- Debit source account
        UPDATE accounts SET balance = balance - p_amount
        WHERE account_id = p_from_account;
        
        -- Credit destination account
        UPDATE accounts SET balance = balance + p_amount
        WHERE account_id = p_to_account;
        
        -- Record transaction
        INSERT INTO transactions (from_account, to_account, amount, txn_type, txn_date)
        VALUES (p_from_account, p_to_account, p_amount, 'transfer', NOW());
        
        COMMIT;
        SET p_result = 'SUCCESS: Transfer completed';
    END IF;
END //

DELIMITER ;

-- Example 2: Order Processing with Inventory Check
DELIMITER //

CREATE PROCEDURE process_order(
    IN p_order_id INT,
    OUT p_result VARCHAR(200)
)
BEGIN
    DECLARE v_product_id INT;
    DECLARE v_quantity INT;
    DECLARE v_stock INT;
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    
    DECLARE item_cursor CURSOR FOR
        SELECT product_id, quantity
        FROM order_items
        WHERE order_id = p_order_id;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'ERROR: Order processing failed';
    END;
    
    START TRANSACTION;
    
    OPEN item_cursor;
    
    item_loop: LOOP
        FETCH item_cursor INTO v_product_id, v_quantity;
        
        IF v_done THEN
            LEAVE item_loop;
        END IF;
        
        -- Lock and check stock
        SELECT stock_quantity INTO v_stock
        FROM products
        WHERE product_id = v_product_id
        FOR UPDATE;
        
        IF v_stock < v_quantity THEN
            CLOSE item_cursor;
            ROLLBACK;
            SET p_result = CONCAT('ERROR: Insufficient stock for product ', v_product_id);
            LEAVE item_loop;
        END IF;
        
        -- Reduce stock
        UPDATE products
        SET stock_quantity = stock_quantity - v_quantity
        WHERE product_id = v_product_id;
    END LOOP;
    
    CLOSE item_cursor;
    
    -- Update order status
    UPDATE orders SET status = 'processing' WHERE order_id = p_order_id;
    
    COMMIT;
    SET p_result = 'SUCCESS: Order processed';
END //

DELIMITER ;

-- Example 3: Multi-table insert with consistency
DELIMITER //

CREATE PROCEDURE create_customer_with_account(
    IN p_name VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_initial_deposit DECIMAL(15,2),
    OUT p_customer_id INT,
    OUT p_account_id INT
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_customer_id = NULL;
        SET p_account_id = NULL;
    END;
    
    START TRANSACTION;
    
    -- Create customer
    INSERT INTO customers (customer_name, email, created_at)
    VALUES (p_name, p_email, NOW());
    SET p_customer_id = LAST_INSERT_ID();
    
    -- Create account
    INSERT INTO accounts (customer_id, balance, account_type, created_at)
    VALUES (p_customer_id, p_initial_deposit, 'savings', NOW());
    SET p_account_id = LAST_INSERT_ID();
    
    -- Record initial deposit
    INSERT INTO transactions (account_id, txn_type, amount, txn_date)
    VALUES (p_account_id, 'deposit', p_initial_deposit, NOW());
    
    COMMIT;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 4: ISOLATION LEVELS
-- ============================================================================

/*
ISOLATION LEVELS (lowest to highest):

1. READ UNCOMMITTED
   - Can read uncommitted changes from other transactions
   - Dirty reads possible
   
2. READ COMMITTED (default in many databases)
   - Only reads committed data
   - Non-repeatable reads possible
   
3. REPEATABLE READ (MySQL InnoDB default)
   - Same query returns same results within transaction
   - Phantom reads possible
   
4. SERIALIZABLE
   - Highest isolation
   - Transactions execute as if serial
   - Most locks, lowest concurrency
*/

-- Check current isolation level
SELECT @@transaction_isolation;

-- Set isolation level for session
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;

-- Set for single transaction
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
-- ... operations ...
COMMIT;

-- ============================================================================
-- SECTION 5: LOCKING STRATEGIES
-- ============================================================================

/*
LOCK TYPES:

1. Shared Lock (S): Multiple transactions can read
2. Exclusive Lock (X): Only one transaction can write
3. Row-level locks: Lock specific rows
4. Table-level locks: Lock entire table
*/

-- Row-level locking with FOR UPDATE
START TRANSACTION;

-- Lock specific rows for update
SELECT * FROM accounts WHERE account_id = 1 FOR UPDATE;
-- Other transactions wait to modify this row

UPDATE accounts SET balance = 500000 WHERE account_id = 1;

COMMIT;

-- FOR SHARE (shared lock, allows other reads)
START TRANSACTION;

SELECT * FROM products WHERE category = 'Electronics' FOR SHARE;
-- Can read, changes by others wait

-- ... do something with the data ...

COMMIT;

-- Table-level locks
LOCK TABLES accounts WRITE;
-- Exclusive access to accounts table
-- ... perform operations ...
UNLOCK TABLES;

LOCK TABLES products READ, orders WRITE;
-- Can read products, write to orders
-- ... operations ...
UNLOCK TABLES;

-- Skip locked rows (MySQL 8.0+)
SELECT * FROM jobs WHERE status = 'pending' 
FOR UPDATE SKIP LOCKED
LIMIT 1;

-- NOWAIT - fail immediately if locked
SELECT * FROM accounts WHERE account_id = 1
FOR UPDATE NOWAIT;

-- ============================================================================
-- SECTION 6: DEADLOCK HANDLING
-- ============================================================================

/*
DEADLOCK:
When two transactions wait for each other's locks.

Transaction 1: Locks A, needs B
Transaction 2: Locks B, needs A
Both wait forever (deadlock)

MySQL detects and rolls back one transaction.
*/

-- Deadlock-prone pattern (avoid this!)
-- Transaction 1:
/*
START TRANSACTION;
UPDATE accounts SET balance = 100 WHERE id = 1;  -- Locks row 1
UPDATE accounts SET balance = 200 WHERE id = 2;  -- Waits for row 2
COMMIT;
*/

-- Transaction 2 (concurrent):
/*
START TRANSACTION;
UPDATE accounts SET balance = 300 WHERE id = 2;  -- Locks row 2
UPDATE accounts SET balance = 400 WHERE id = 1;  -- Waits for row 1 (DEADLOCK!)
COMMIT;
*/

-- Solution: Consistent lock ordering
-- Always update in same order (e.g., by account_id ascending)
DELIMITER //

CREATE PROCEDURE safe_transfer(
    IN p_account1 INT,
    IN p_account2 INT,
    IN p_amount DECIMAL(15,2)
)
BEGIN
    DECLARE v_first INT;
    DECLARE v_second INT;
    
    -- Always lock in same order (smaller ID first)
    IF p_account1 < p_account2 THEN
        SET v_first = p_account1;
        SET v_second = p_account2;
    ELSE
        SET v_first = p_account2;
        SET v_second = p_account1;
    END IF;
    
    START TRANSACTION;
    
    -- Lock in consistent order
    SELECT * FROM accounts WHERE account_id = v_first FOR UPDATE;
    SELECT * FROM accounts WHERE account_id = v_second FOR UPDATE;
    
    -- Now safe to update
    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_account1;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_account2;
    
    COMMIT;
END //

DELIMITER ;

-- Check for deadlocks
SHOW ENGINE INNODB STATUS;

-- ============================================================================
-- SECTION 7: OPTIMISTIC VS PESSIMISTIC LOCKING
-- ============================================================================

-- PESSIMISTIC LOCKING: Lock before reading
START TRANSACTION;
SELECT * FROM products WHERE product_id = 1 FOR UPDATE;  -- Lock immediately
UPDATE products SET stock_quantity = stock_quantity - 1 WHERE product_id = 1;
COMMIT;

-- OPTIMISTIC LOCKING: Version check at update time
ALTER TABLE products ADD COLUMN version INT DEFAULT 1;

-- Read without lock
SELECT product_id, stock_quantity, version FROM products WHERE product_id = 1;
-- Returns: product_id=1, stock_quantity=100, version=5

-- Update with version check
UPDATE products 
SET stock_quantity = stock_quantity - 1, version = version + 1
WHERE product_id = 1 AND version = 5;

-- If 0 rows affected, someone else modified it - retry!
-- This is better for high-read, low-write scenarios

-- Stored procedure with optimistic locking
DELIMITER //

CREATE PROCEDURE update_stock_optimistic(
    IN p_product_id INT,
    IN p_new_quantity INT,
    IN p_expected_version INT,
    OUT p_success BOOLEAN
)
BEGIN
    DECLARE v_rows_affected INT;
    
    UPDATE products 
    SET stock_quantity = p_new_quantity, version = version + 1
    WHERE product_id = p_product_id AND version = p_expected_version;
    
    SET v_rows_affected = ROW_COUNT();
    
    IF v_rows_affected = 1 THEN
        SET p_success = TRUE;
    ELSE
        SET p_success = FALSE;  -- Conflict detected, caller should retry
    END IF;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 8: TRANSACTION PATTERNS FOR COMMON SCENARIOS
-- ============================================================================

-- Pattern 1: Idempotent operations
-- Create unique transaction ID to prevent duplicate processing
CREATE TABLE processed_transactions (
    txn_ref VARCHAR(50) PRIMARY KEY,
    processed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

CREATE PROCEDURE process_payment_idempotent(
    IN p_txn_ref VARCHAR(50),
    IN p_account_id INT,
    IN p_amount DECIMAL(15,2),
    OUT p_result VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_result = 'ERROR';
    END;
    
    START TRANSACTION;
    
    -- Check if already processed
    IF EXISTS (SELECT 1 FROM processed_transactions WHERE txn_ref = p_txn_ref) THEN
        SET p_result = 'ALREADY_PROCESSED';
        COMMIT;
    ELSE
        -- Process payment
        UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_account_id;
        
        -- Mark as processed
        INSERT INTO processed_transactions (txn_ref) VALUES (p_txn_ref);
        
        COMMIT;
        SET p_result = 'SUCCESS';
    END IF;
END //

DELIMITER ;

-- Pattern 2: Compensating transaction (saga pattern)
CREATE TABLE saga_log (
    saga_id VARCHAR(50),
    step_number INT,
    action VARCHAR(50),
    status VARCHAR(20),
    compensation_data JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (saga_id, step_number)
);

DELIMITER //

CREATE PROCEDURE execute_saga_step(
    IN p_saga_id VARCHAR(50),
    IN p_step_number INT,
    IN p_action VARCHAR(50),
    IN p_compensation_data JSON
)
BEGIN
    -- Log the step for potential compensation
    INSERT INTO saga_log (saga_id, step_number, action, status, compensation_data)
    VALUES (p_saga_id, p_step_number, p_action, 'COMPLETED', p_compensation_data);
END //

CREATE PROCEDURE compensate_saga(IN p_saga_id VARCHAR(50))
BEGIN
    DECLARE v_step INT;
    DECLARE v_action VARCHAR(50);
    DECLARE v_data JSON;
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    
    DECLARE comp_cursor CURSOR FOR
        SELECT step_number, action, compensation_data
        FROM saga_log
        WHERE saga_id = p_saga_id AND status = 'COMPLETED'
        ORDER BY step_number DESC;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    
    OPEN comp_cursor;
    
    comp_loop: LOOP
        FETCH comp_cursor INTO v_step, v_action, v_data;
        IF v_done THEN LEAVE comp_loop; END IF;
        
        -- Execute compensation based on action type
        CASE v_action
            WHEN 'debit_account' THEN
                -- Reverse: credit the account
                UPDATE accounts 
                SET balance = balance + JSON_EXTRACT(v_data, '$.amount')
                WHERE account_id = JSON_EXTRACT(v_data, '$.account_id');
            WHEN 'reserve_inventory' THEN
                -- Reverse: release inventory
                UPDATE products
                SET stock_quantity = stock_quantity + JSON_EXTRACT(v_data, '$.quantity')
                WHERE product_id = JSON_EXTRACT(v_data, '$.product_id');
            -- Add more compensation actions as needed
        END CASE;
        
        -- Mark step as compensated
        UPDATE saga_log SET status = 'COMPENSATED' 
        WHERE saga_id = p_saga_id AND step_number = v_step;
    END LOOP;
    
    CLOSE comp_cursor;
END //

DELIMITER ;

-- ============================================================================
-- SECTION 9: MONITORING TRANSACTIONS
-- ============================================================================

-- View current transactions
SELECT * FROM information_schema.INNODB_TRX;

-- View locks
SELECT * FROM information_schema.INNODB_LOCKS;

-- View lock waits
SELECT * FROM information_schema.INNODB_LOCK_WAITS;

-- Performance schema (MySQL 8.0+)
SELECT * FROM performance_schema.events_transactions_current;

-- Check for long-running transactions
SELECT 
    trx_id,
    trx_state,
    trx_started,
    TIMESTAMPDIFF(SECOND, trx_started, NOW()) AS duration_seconds,
    trx_query
FROM information_schema.INNODB_TRX
WHERE TIMESTAMPDIFF(SECOND, trx_started, NOW()) > 60;  -- Over 1 minute

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Basic transactions
a) Write a transaction to transfer money between accounts with proper validation
b) Create a procedure that creates an order with multiple items atomically  
c) Implement a stock adjustment with audit trail
d) Create a transaction that handles customer credit purchase

EXERCISE 2: Isolation and locking
a) Demonstrate dirty read with READ UNCOMMITTED
b) Show how REPEATABLE READ prevents non-repeatable reads
c) Implement optimistic locking for inventory updates
d) Create a procedure that handles lock timeouts gracefully

EXERCISE 3: Deadlock handling
a) Identify and fix potential deadlock in given code
b) Implement consistent lock ordering
c) Create retry logic for deadlock victims
d) Build monitoring query for deadlock frequency

EXERCISE 4: Advanced patterns
a) Implement idempotent payment processing
b) Create a two-phase commit simulation
c) Build a saga pattern with compensating transactions
d) Implement distributed transaction coordinator

EXERCISE 5: Monitoring and troubleshooting
a) Create a view showing long-running transactions
b) Build alerting for blocked transactions
c) Create a procedure to kill stuck transactions safely
d) Implement transaction logging for debugging

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

