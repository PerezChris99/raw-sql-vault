-- ============================================================================
-- SQL SECURITY AND PERMISSIONS
-- Module 17: Database Access Control and Security Best Practices
-- Goal: Secure your database against unauthorized access and attacks
-- ============================================================================

-- ============================================================================
-- SECTION 1: USER MANAGEMENT FUNDAMENTALS
-- ============================================================================

/*
AUTHENTICATION: Who are you?
AUTHORIZATION: What can you do?

User account format: 'username'@'host'
Examples:
- 'admin'@'localhost' - Local connections only
- 'app'@'%' - Any host
- 'user'@'192.168.1.%' - Specific network
*/

-- Create users
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'SecureP@ssw0rd123!';
CREATE USER 'app_user'@'192.168.1.%' IDENTIFIED BY 'SecureP@ssw0rd123!';
CREATE USER 'readonly'@'%' IDENTIFIED BY 'ReadOnlyP@ss!';

-- View existing users
SELECT User, Host, authentication_string FROM mysql.user;

-- Change password
ALTER USER 'app_user'@'localhost' IDENTIFIED BY 'NewSecureP@ss456!';

-- Password expiration
ALTER USER 'app_user'@'localhost' PASSWORD EXPIRE;
ALTER USER 'app_user'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'app_user'@'localhost' PASSWORD EXPIRE NEVER;

-- Lock/Unlock accounts
ALTER USER 'app_user'@'localhost' ACCOUNT LOCK;
ALTER USER 'app_user'@'localhost' ACCOUNT UNLOCK;

-- Drop users
DROP USER 'old_user'@'localhost';
DROP USER IF EXISTS 'temp_user'@'%';

-- ============================================================================
-- SECTION 2: PRIVILEGES (AUTHORIZATION)
-- ============================================================================

/*
PRIVILEGE LEVELS:
1. Global: *.*
2. Database: database_name.*
3. Table: database_name.table_name
4. Column: Specific columns
5. Routine: Stored procedures/functions

COMMON PRIVILEGES:
- SELECT: Read data
- INSERT: Add data
- UPDATE: Modify data
- DELETE: Remove data
- CREATE: Create database objects
- DROP: Remove database objects
- ALTER: Modify structure
- INDEX: Create/drop indexes
- EXECUTE: Run stored routines
- GRANT OPTION: Grant privileges to others
*/

-- Grant basic privileges
GRANT SELECT ON shop_db.* TO 'readonly'@'%';
GRANT SELECT, INSERT, UPDATE ON shop_db.orders TO 'sales_app'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_db.* TO 'app_user'@'localhost';

-- Grant all privileges on database
GRANT ALL PRIVILEGES ON shop_db.* TO 'admin_user'@'localhost';

-- Grant column-level privileges
GRANT SELECT (customer_id, customer_name, email) ON shop_db.customers TO 'support'@'%';
GRANT UPDATE (email, phone) ON shop_db.customers TO 'support'@'%';

-- Grant with GRANT OPTION (can grant to others)
GRANT SELECT ON shop_db.* TO 'team_lead'@'localhost' WITH GRANT OPTION;

-- Grant execute privilege on stored procedures
GRANT EXECUTE ON PROCEDURE shop_db.create_order TO 'app_user'@'localhost';
GRANT EXECUTE ON FUNCTION shop_db.calculate_tax TO 'app_user'@'localhost';

-- View grants for user
SHOW GRANTS FOR 'app_user'@'localhost';
SHOW GRANTS FOR CURRENT_USER;

-- Revoke privileges
REVOKE INSERT, UPDATE ON shop_db.orders FROM 'temp_user'@'%';
REVOKE ALL PRIVILEGES ON shop_db.* FROM 'old_admin'@'localhost';

-- Apply privilege changes
FLUSH PRIVILEGES;

-- ============================================================================
-- SECTION 3: ROLE-BASED ACCESS CONTROL (MySQL 8.0+)
-- ============================================================================

-- Create roles
CREATE ROLE 'read_only', 'read_write', 'admin';

-- Grant privileges to roles
GRANT SELECT ON shop_db.* TO 'read_only';
GRANT SELECT, INSERT, UPDATE, DELETE ON shop_db.* TO 'read_write';
GRANT ALL PRIVILEGES ON shop_db.* TO 'admin';

-- Grant roles to users
GRANT 'read_only' TO 'analyst'@'localhost';
GRANT 'read_write' TO 'app_user'@'localhost';
GRANT 'admin' TO 'dba'@'localhost';

-- Set default roles for users
SET DEFAULT ROLE 'read_write' TO 'app_user'@'localhost';
SET DEFAULT ROLE ALL TO 'app_user'@'localhost';

-- Activate roles in session
SET ROLE 'read_only';
SET ROLE DEFAULT;
SET ROLE NONE;

-- View current roles
SELECT CURRENT_ROLE();

-- View role grants
SHOW GRANTS FOR 'read_only';

-- Revoke roles
REVOKE 'read_write' FROM 'temp_user'@'localhost';

-- Drop roles
DROP ROLE 'obsolete_role';

-- ============================================================================
-- SECTION 4: SQL INJECTION PREVENTION
-- ============================================================================

/*
SQL INJECTION: Malicious SQL inserted through user input

VULNERABLE CODE (Never do this!):
query = "SELECT * FROM users WHERE username = '" + username + "'"

If username = "admin' OR '1'='1"
Query becomes: SELECT * FROM users WHERE username = 'admin' OR '1'='1'
Returns ALL users!

PREVENTION:
1. Parameterized queries (prepared statements)
2. Input validation
3. Least privilege principle
4. Web Application Firewall
*/

-- Prepared statements (the RIGHT way)
PREPARE stmt FROM 'SELECT * FROM customers WHERE customer_id = ?';
SET @cust_id = 5;
EXECUTE stmt USING @cust_id;
DEALLOCATE PREPARE stmt;

-- Stored procedure with parameters (safe)
DELIMITER //

CREATE PROCEDURE get_customer_safe(IN p_customer_id INT)
BEGIN
    SELECT customer_id, customer_name, email
    FROM customers
    WHERE customer_id = p_customer_id;
END //

DELIMITER ;

-- Input validation in stored procedure
DELIMITER //

CREATE PROCEDURE search_products_safe(IN p_search VARCHAR(100))
BEGIN
    -- Validate input
    IF p_search IS NULL OR LENGTH(TRIM(p_search)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Search term cannot be empty';
    END IF;
    
    IF LENGTH(p_search) > 100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Search term too long';
    END IF;
    
    -- Remove potential dangerous characters
    SET p_search = REPLACE(p_search, ';', '');
    SET p_search = REPLACE(p_search, '--', '');
    SET p_search = REPLACE(p_search, '/*', '');
    SET p_search = REPLACE(p_search, '*/', '');
    
    -- Safe query using parameter
    SELECT product_id, product_name, price
    FROM products
    WHERE product_name LIKE CONCAT('%', p_search, '%');
END //

DELIMITER ;

-- ============================================================================
-- SECTION 5: DATA ENCRYPTION
-- ============================================================================

-- Built-in encryption functions
-- AES encryption (symmetric)
SELECT AES_ENCRYPT('secret data', 'encryption_key_123');
SELECT AES_DECRYPT(AES_ENCRYPT('secret data', 'encryption_key_123'), 'encryption_key_123');

-- Store encrypted data
CREATE TABLE sensitive_data (
    id INT PRIMARY KEY,
    customer_id INT,
    credit_card_encrypted VARBINARY(255)
);

-- Insert encrypted
INSERT INTO sensitive_data (id, customer_id, credit_card_encrypted)
VALUES (1, 100, AES_ENCRYPT('4111111111111111', 'my_secret_key'));

-- Read decrypted
SELECT id, customer_id, 
       CAST(AES_DECRYPT(credit_card_encrypted, 'my_secret_key') AS CHAR) AS credit_card
FROM sensitive_data;

-- One-way hashing (for passwords)
SELECT SHA2('password123', 256);
SELECT MD5('password123');  -- Not recommended, use SHA2

-- Password hashing comparison
CREATE TABLE users (
    user_id INT PRIMARY KEY,
    username VARCHAR(50),
    password_hash VARCHAR(64),  -- SHA2-256 produces 64 chars
    salt VARCHAR(32)
);

-- Store password with salt
INSERT INTO users (user_id, username, password_hash, salt)
VALUES (
    1, 
    'nakato', 
    SHA2(CONCAT('user_password', 'random_salt_value'), 256),
    'random_salt_value'
);

-- Verify password
SELECT user_id FROM users
WHERE username = 'nakato'
  AND password_hash = SHA2(CONCAT('user_password', salt), 256);

-- ============================================================================
-- SECTION 6: AUDIT LOGGING
-- ============================================================================

-- Comprehensive audit table
CREATE TABLE audit_log (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    event_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_name VARCHAR(100),
    host_name VARCHAR(100),
    action_type ENUM('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'DDL', 'GRANT', 'REVOKE'),
    object_schema VARCHAR(64),
    object_name VARCHAR(64),
    statement_text TEXT,
    rows_affected INT,
    client_ip VARCHAR(45),
    INDEX idx_event_time (event_time),
    INDEX idx_user_name (user_name),
    INDEX idx_action_type (action_type)
);

-- Procedure to log actions
DELIMITER //

CREATE PROCEDURE log_audit(
    IN p_action VARCHAR(20),
    IN p_schema VARCHAR(64),
    IN p_object VARCHAR(64),
    IN p_statement TEXT,
    IN p_rows INT
)
BEGIN
    INSERT INTO audit_log (
        user_name, host_name, action_type, 
        object_schema, object_name, statement_text, rows_affected
    )
    VALUES (
        USER(), 
        SUBSTRING_INDEX(USER(), '@', -1),
        p_action,
        p_schema,
        p_object,
        p_statement,
        p_rows
    );
END //

DELIMITER ;

-- Trigger-based auditing
CREATE TABLE customers_audit (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    action ENUM('INSERT', 'UPDATE', 'DELETE'),
    old_data JSON,
    new_data JSON,
    changed_by VARCHAR(100),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

DELIMITER //

CREATE TRIGGER customers_audit_insert
AFTER INSERT ON customers
FOR EACH ROW
BEGIN
    INSERT INTO customers_audit (customer_id, action, new_data, changed_by)
    VALUES (
        NEW.customer_id,
        'INSERT',
        JSON_OBJECT(
            'customer_name', NEW.customer_name,
            'email', NEW.email,
            'phone', NEW.phone
        ),
        USER()
    );
END //

CREATE TRIGGER customers_audit_update
AFTER UPDATE ON customers
FOR EACH ROW
BEGIN
    INSERT INTO customers_audit (customer_id, action, old_data, new_data, changed_by)
    VALUES (
        NEW.customer_id,
        'UPDATE',
        JSON_OBJECT(
            'customer_name', OLD.customer_name,
            'email', OLD.email,
            'phone', OLD.phone
        ),
        JSON_OBJECT(
            'customer_name', NEW.customer_name,
            'email', NEW.email,
            'phone', NEW.phone
        ),
        USER()
    );
END //

CREATE TRIGGER customers_audit_delete
AFTER DELETE ON customers
FOR EACH ROW
BEGIN
    INSERT INTO customers_audit (customer_id, action, old_data, changed_by)
    VALUES (
        OLD.customer_id,
        'DELETE',
        JSON_OBJECT(
            'customer_name', OLD.customer_name,
            'email', OLD.email,
            'phone', OLD.phone
        ),
        USER()
    );
END //

DELIMITER ;

-- ============================================================================
-- SECTION 7: ROW-LEVEL SECURITY (Simulation)
-- ============================================================================

/*
MySQL doesn't have built-in row-level security like PostgreSQL.
We can simulate it using views and stored procedures.
*/

-- Setup: Multi-tenant table
CREATE TABLE tenant_data (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tenant_id INT NOT NULL,
    data_value VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create tenant-specific views
CREATE VIEW tenant_1_data AS
SELECT * FROM tenant_data WHERE tenant_id = 1;

CREATE VIEW tenant_2_data AS
SELECT * FROM tenant_data WHERE tenant_id = 2;

-- Dynamic tenant filtering using session variable
CREATE VIEW current_tenant_data AS
SELECT * FROM tenant_data 
WHERE tenant_id = @current_tenant_id;

-- Set tenant before queries
SET @current_tenant_id = 1;
SELECT * FROM current_tenant_data;

-- Stored procedure with built-in tenant filtering
DELIMITER //

CREATE PROCEDURE get_tenant_data()
BEGIN
    DECLARE v_tenant_id INT;
    
    -- Get tenant from session or user mapping
    SELECT tenant_id INTO v_tenant_id
    FROM user_tenant_mapping
    WHERE user_name = CURRENT_USER();
    
    IF v_tenant_id IS NULL THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'No tenant mapping found for current user';
    END IF;
    
    SELECT * FROM tenant_data WHERE tenant_id = v_tenant_id;
END //

DELIMITER ;

-- User-tenant mapping table
CREATE TABLE user_tenant_mapping (
    user_name VARCHAR(100) PRIMARY KEY,
    tenant_id INT NOT NULL
);

INSERT INTO user_tenant_mapping VALUES ('app_user@localhost', 1);
INSERT INTO user_tenant_mapping VALUES ('other_user@localhost', 2);

-- ============================================================================
-- SECTION 8: SECURITY BEST PRACTICES
-- ============================================================================

/*
SECURITY CHECKLIST:

1. AUTHENTICATION
   - Strong passwords (min 12 chars, mixed case, numbers, symbols)
   - Password expiration
   - Account lockout after failed attempts
   - Use SSL/TLS connections

2. AUTHORIZATION
   - Principle of least privilege
   - Use roles for group permissions
   - Regular permission audits
   - Separate accounts for different purposes

3. DATA PROTECTION
   - Encrypt sensitive data at rest
   - Use TLS for data in transit
   - Proper key management
   - Regular backups with encryption

4. MONITORING
   - Enable audit logging
   - Monitor failed login attempts
   - Alert on suspicious activities
   - Regular security reviews

5. APPLICATION SECURITY
   - Use parameterized queries always
   - Validate all input
   - Sanitize output
   - Use web application firewall
*/

-- Check for users with weak permissions
SELECT User, Host, 
       Super_priv, 
       Grant_priv,
       Create_user_priv,
       File_priv
FROM mysql.user
WHERE Super_priv = 'Y' OR Grant_priv = 'Y';

-- Find users with no password
SELECT User, Host FROM mysql.user 
WHERE authentication_string = '' OR authentication_string IS NULL;

-- Check for users from all hosts
SELECT User, Host FROM mysql.user WHERE Host = '%';

-- List all privileges by user
SELECT grantee, privilege_type, is_grantable 
FROM information_schema.user_privileges
WHERE grantee LIKE "'app%";

-- ============================================================================
-- SECTION 9: SSL/TLS CONNECTIONS
-- ============================================================================

-- Check SSL status
SHOW VARIABLES LIKE '%ssl%';

-- Require SSL for user
CREATE USER 'secure_user'@'%' 
IDENTIFIED BY 'SecureP@ss!'
REQUIRE SSL;

-- Require specific cipher
CREATE USER 'crypto_user'@'%' 
IDENTIFIED BY 'SecureP@ss!'
REQUIRE CIPHER 'ECDHE-RSA-AES128-SHA256';

-- Require client certificate
CREATE USER 'cert_user'@'%' 
IDENTIFIED BY 'SecureP@ss!'
REQUIRE X509;

-- Check current connection security
SHOW STATUS LIKE 'Ssl_cipher';
SELECT USER(), @@ssl_cipher;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: User and role management
a) Create a complete role hierarchy (admin, manager, employee, customer)
b) Assign appropriate privileges to each role
c) Create users and assign roles
d) Test privilege restrictions

EXERCISE 2: Security implementation
a) Create a secure login procedure with attempt limiting
b) Implement password hashing with salt
c) Build a sensitive data masking view
d) Create audit triggers for all critical tables

EXERCISE 3: SQL injection prevention
a) Identify vulnerabilities in given code samples
b) Rewrite queries using prepared statements
c) Create input validation procedures
d) Build a parameterized search function

EXERCISE 4: Encryption
a) Design encrypted storage for payment cards
b) Create encryption key rotation procedure
c) Implement field-level encryption for PII
d) Build secure password reset flow

EXERCISE 5: Compliance and auditing
a) Create comprehensive audit logging
b) Build report of all user activities
c) Implement data retention with secure deletion
d) Create security violation alerts

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

