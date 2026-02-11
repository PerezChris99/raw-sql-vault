-- ============================================================================
-- SQL CONSTRAINTS: DATA INTEGRITY FUNDAMENTALS
-- Module 03: Mastering Constraints
-- Goal: Ensure data quality and integrity through constraints
-- ============================================================================

-- ============================================================================
-- SECTION 1: PRIMARY KEY CONSTRAINT
-- ============================================================================

/*
PRIMARY KEY:
- Uniquely identifies each row in a table
- Cannot contain NULL values
- Only ONE primary key per table
- Can be single column or composite (multiple columns)
*/

-- Single column primary key
CREATE TABLE students (
    student_id INT PRIMARY KEY,
    student_name VARCHAR(100)
);

-- Alternative syntax
CREATE TABLE teachers (
    teacher_id INT,
    teacher_name VARCHAR(100),
    PRIMARY KEY (teacher_id)
);

-- Auto-increment primary key (most common)
CREATE TABLE courses (
    course_id INT AUTO_INCREMENT PRIMARY KEY,
    course_name VARCHAR(100) NOT NULL
);

-- Composite primary key (multiple columns)
CREATE TABLE enrollments (
    student_id INT,
    course_id INT,
    enrollment_date DATE,
    grade VARCHAR(2),
    PRIMARY KEY (student_id, course_id)  -- Combination must be unique
);

-- ============================================================================
-- SECTION 2: FOREIGN KEY CONSTRAINT
-- ============================================================================

/*
FOREIGN KEY:
- Links two tables together
- Enforces referential integrity
- Value must exist in the referenced (parent) table
- Can be NULL (unless also NOT NULL)
*/

-- Parent table
CREATE TABLE departments (
    dept_id INT AUTO_INCREMENT PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL,
    location VARCHAR(100)
);

-- Child table with foreign key
CREATE TABLE employees (
    emp_id INT AUTO_INCREMENT PRIMARY KEY,
    emp_name VARCHAR(100) NOT NULL,
    dept_id INT,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

-- Foreign key with ON DELETE and ON UPDATE actions
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATE,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE CASCADE       -- Delete orders when customer is deleted
        ON UPDATE CASCADE       -- Update orders when customer_id changes
);

/*
FOREIGN KEY ACTIONS:
- CASCADE: Automatically delete/update child rows
- SET NULL: Set foreign key to NULL when parent is deleted/updated
- SET DEFAULT: Set to default value (if defined)
- RESTRICT: Prevent delete/update if child rows exist (default)
- NO ACTION: Same as RESTRICT
*/

-- Example with different actions
CREATE TABLE order_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE,      -- Delete items with order
    FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE RESTRICT      -- Prevent product deletion if ordered
);

-- Named foreign key constraints
CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    amount DECIMAL(12, 2),
    CONSTRAINT fk_payment_order 
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE SET NULL
);

-- ============================================================================
-- SECTION 3: UNIQUE CONSTRAINT
-- ============================================================================

/*
UNIQUE:
- Ensures all values in a column are different
- CAN contain NULL values (usually only one NULL is allowed)
- Multiple UNIQUE constraints allowed per table
*/

-- Unique constraint on single column
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    email VARCHAR(100) UNIQUE,
    phone VARCHAR(20) UNIQUE
);

-- Composite unique constraint
CREATE TABLE user_roles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    role_id INT,
    UNIQUE (user_id, role_id)  -- User can have each role only once
);

-- Named unique constraint
CREATE TABLE accounts (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    account_number VARCHAR(20),
    bank_code VARCHAR(10),
    CONSTRAINT uk_bank_account UNIQUE (bank_code, account_number)
);

-- ============================================================================
-- SECTION 4: NOT NULL CONSTRAINT
-- ============================================================================

/*
NOT NULL:
- Ensures a column cannot have NULL value
- Must provide a value during INSERT
- Can have DEFAULT value as alternative
*/

CREATE TABLE contacts (
    contact_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),              -- Can be NULL
    phone VARCHAR(20) NOT NULL,      -- Must have value
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- This will fail:
-- INSERT INTO contacts (first_name, phone) VALUES ('John', '0700123456');
-- Error: last_name cannot be NULL

-- This will succeed:
INSERT INTO contacts (first_name, last_name, phone) 
VALUES ('John', 'Doe', '0700123456');

-- ============================================================================
-- SECTION 5: DEFAULT CONSTRAINT
-- ============================================================================

/*
DEFAULT:
- Provides a default value when none is specified
- Used with NOT NULL for required fields with sensible defaults
- Can use functions like CURRENT_TIMESTAMP
*/

CREATE TABLE articles (
    article_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    status VARCHAR(20) DEFAULT 'draft',
    view_count INT DEFAULT 0,
    is_published BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    published_at TIMESTAMP NULL DEFAULT NULL
);

-- Insert with defaults
INSERT INTO articles (title, content) VALUES ('My First Article', 'Content here...');
-- status='draft', view_count=0, is_published=FALSE, created_at=NOW()

-- Override defaults
INSERT INTO articles (title, content, status, is_published)
VALUES ('Published Article', 'Content...', 'published', TRUE);

-- ============================================================================
-- SECTION 6: CHECK CONSTRAINT
-- ============================================================================

/*
CHECK:
- Ensures values meet a specific condition
- Can reference multiple columns
- Enforces business rules at database level
*/

-- Simple check constraints
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    price DECIMAL(10, 2) CHECK (price >= 0),
    quantity INT CHECK (quantity >= 0),
    discount_percent DECIMAL(5, 2) CHECK (discount_percent BETWEEN 0 AND 100),
    status VARCHAR(20) CHECK (status IN ('active', 'inactive', 'discontinued'))
);

-- Named check constraints
CREATE TABLE employees_v2 (
    emp_id INT AUTO_INCREMENT PRIMARY KEY,
    emp_name VARCHAR(100) NOT NULL,
    salary DECIMAL(12, 2),
    bonus DECIMAL(12, 2),
    hire_date DATE,
    termination_date DATE,
    
    CONSTRAINT chk_salary_positive CHECK (salary > 0),
    CONSTRAINT chk_bonus_valid CHECK (bonus >= 0 AND bonus <= salary),
    CONSTRAINT chk_dates_valid CHECK (termination_date IS NULL OR termination_date > hire_date)
);

-- Complex check with multiple columns
CREATE TABLE promotions (
    promo_id INT AUTO_INCREMENT PRIMARY KEY,
    promo_name VARCHAR(100),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    min_purchase DECIMAL(10, 2) DEFAULT 0,
    discount_amount DECIMAL(10, 2),
    discount_percent DECIMAL(5, 2),
    
    -- End date must be after start date
    CONSTRAINT chk_promo_dates CHECK (end_date > start_date),
    
    -- Must have either discount amount or percent, not both
    CONSTRAINT chk_discount_type CHECK (
        (discount_amount IS NOT NULL AND discount_percent IS NULL) OR
        (discount_amount IS NULL AND discount_percent IS NOT NULL)
    )
);

-- ============================================================================
-- SECTION 7: INDEX (Performance Constraint)
-- ============================================================================

/*
INDEX:
- Improves query performance
- Not a data integrity constraint, but essential for optimization
- Types: B-tree (default), Hash, Full-text, Spatial
*/

-- Create index on single column
CREATE INDEX idx_email ON users(email);

-- Create index on multiple columns
CREATE INDEX idx_name ON users(last_name, first_name);

-- Create unique index (same as UNIQUE constraint)
CREATE UNIQUE INDEX idx_username ON users(username);

-- Create index during table creation
CREATE TABLE transactions (
    txn_id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT,
    txn_date DATE,
    amount DECIMAL(12, 2),
    txn_type VARCHAR(20),
    
    INDEX idx_account (account_id),
    INDEX idx_date (txn_date),
    INDEX idx_account_date (account_id, txn_date)  -- Composite index
);

-- Full-text index for text searching
CREATE TABLE articles_v2 (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(200),
    body TEXT,
    FULLTEXT INDEX idx_content (title, body)
);

-- Search using full-text index
SELECT * FROM articles_v2 
WHERE MATCH(title, body) AGAINST('Uganda technology' IN NATURAL LANGUAGE MODE);

-- ============================================================================
-- SECTION 8: ADDING AND REMOVING CONSTRAINTS
-- ============================================================================

-- Add primary key to existing table
ALTER TABLE existing_table ADD PRIMARY KEY (id);

-- Add foreign key
ALTER TABLE orders 
ADD CONSTRAINT fk_customer 
FOREIGN KEY (customer_id) REFERENCES customers(customer_id);

-- Add unique constraint
ALTER TABLE users ADD CONSTRAINT uk_email UNIQUE (email);

-- Add check constraint
ALTER TABLE products ADD CONSTRAINT chk_price CHECK (price > 0);

-- Add NOT NULL (requires modifying column)
ALTER TABLE users MODIFY COLUMN email VARCHAR(100) NOT NULL;

-- Add default
ALTER TABLE users ALTER COLUMN status SET DEFAULT 'active';

-- Remove/Drop constraints
ALTER TABLE orders DROP FOREIGN KEY fk_customer;
ALTER TABLE users DROP INDEX uk_email;
ALTER TABLE products DROP CHECK chk_price;

-- ============================================================================
-- SECTION 9: COMPREHENSIVE EXAMPLE - UGANDA E-COMMERCE DATABASE
-- ============================================================================

-- Drop tables if exist (for clean slate)
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS districts;

-- Districts reference table
CREATE TABLE districts (
    district_id INT AUTO_INCREMENT PRIMARY KEY,
    district_name VARCHAR(100) NOT NULL UNIQUE,
    region ENUM('Central', 'Eastern', 'Northern', 'Western') NOT NULL
);

-- Categories with self-reference (for subcategories)
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    parent_category_id INT NULL,
    
    CONSTRAINT fk_parent_category 
        FOREIGN KEY (parent_category_id) REFERENCES categories(category_id)
        ON DELETE SET NULL,
    
    CONSTRAINT uk_category_name UNIQUE (category_name)
);

-- Customers
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL,
    district_id INT,
    address TEXT,
    customer_type ENUM('individual', 'business') DEFAULT 'individual',
    credit_limit DECIMAL(12, 2) DEFAULT 0,
    is_verified BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_customer_district 
        FOREIGN KEY (district_id) REFERENCES districts(district_id)
        ON DELETE SET NULL,
    
    CONSTRAINT chk_credit_limit CHECK (credit_limit >= 0),
    CONSTRAINT chk_phone_format CHECK (phone REGEXP '^\\+256[0-9]{9}$'),
    
    INDEX idx_email (email),
    INDEX idx_phone (phone),
    INDEX idx_district (district_id)
);

-- Products
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(20) NOT NULL UNIQUE,
    product_name VARCHAR(200) NOT NULL,
    description TEXT,
    category_id INT,
    price DECIMAL(12, 2) NOT NULL,
    cost_price DECIMAL(12, 2),
    stock_quantity INT DEFAULT 0,
    reorder_level INT DEFAULT 10,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_product_category 
        FOREIGN KEY (category_id) REFERENCES categories(category_id)
        ON DELETE SET NULL,
    
    CONSTRAINT chk_price_positive CHECK (price > 0),
    CONSTRAINT chk_cost_valid CHECK (cost_price IS NULL OR cost_price > 0),
    CONSTRAINT chk_stock_valid CHECK (stock_quantity >= 0),
    CONSTRAINT chk_price_vs_cost CHECK (cost_price IS NULL OR price >= cost_price),
    
    INDEX idx_category (category_id),
    INDEX idx_sku (sku),
    FULLTEXT INDEX idx_search (product_name, description)
);

-- Orders
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    order_number VARCHAR(20) NOT NULL UNIQUE,
    customer_id INT NOT NULL,
    order_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    required_date DATE,
    shipped_date DATE,
    status ENUM('pending', 'confirmed', 'processing', 'shipped', 'delivered', 'cancelled') 
           DEFAULT 'pending',
    subtotal DECIMAL(12, 2) DEFAULT 0,
    tax_amount DECIMAL(12, 2) DEFAULT 0,
    shipping_cost DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(12, 2) GENERATED ALWAYS AS (subtotal + tax_amount + shipping_cost) STORED,
    notes TEXT,
    
    CONSTRAINT fk_order_customer 
        FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
        ON DELETE RESTRICT,
    
    CONSTRAINT chk_dates CHECK (
        shipped_date IS NULL OR shipped_date >= DATE(order_date)
    ),
    CONSTRAINT chk_amounts CHECK (
        subtotal >= 0 AND tax_amount >= 0 AND shipping_cost >= 0
    ),
    
    INDEX idx_customer (customer_id),
    INDEX idx_status (status),
    INDEX idx_order_date (order_date)
);

-- Order Items
CREATE TABLE order_items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_price DECIMAL(12, 2) NOT NULL,
    discount_percent DECIMAL(5, 2) DEFAULT 0,
    line_total DECIMAL(12, 2) GENERATED ALWAYS AS (
        quantity * unit_price * (1 - discount_percent / 100)
    ) STORED,
    
    CONSTRAINT fk_item_order 
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
        ON DELETE CASCADE,
    
    CONSTRAINT fk_item_product 
        FOREIGN KEY (product_id) REFERENCES products(product_id)
        ON DELETE RESTRICT,
    
    CONSTRAINT uk_order_product UNIQUE (order_id, product_id),
    
    CONSTRAINT chk_quantity CHECK (quantity > 0),
    CONSTRAINT chk_unit_price CHECK (unit_price > 0),
    CONSTRAINT chk_discount CHECK (discount_percent BETWEEN 0 AND 100),
    
    INDEX idx_order (order_id),
    INDEX idx_product (product_id)
);

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Create a 'bank_accounts' table with:
- Unique account number
- Customer reference (foreign key)
- Account type (savings, current, fixed_deposit)
- Balance (must be >= minimum_balance)
- minimum_balance (based on account type rules)
- Interest rate (between 0 and 30)
- Status (active, dormant, frozen, closed)
- Opening date and closing date (closing must be after opening)

EXERCISE 2: Create an 'transfers' table with:
- From account and to account (both foreign keys)
- Amount (must be positive)
- Transfer type (internal, domestic, international)
- Fee (calculated based on type)
- Constraint: from_account cannot equal to_account

EXERCISE 3: Add appropriate indexes to both tables

EXERCISE 4: Write ALTER statements to:
a) Add a new check constraint
b) Add a new foreign key
c) Remove an existing constraint

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

