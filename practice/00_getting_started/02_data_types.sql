-- ============================================================================
-- SQL DATA TYPES: COMPREHENSIVE GUIDE
-- Module 02: Understanding Data Types
-- Goal: Master all SQL data types for optimal database design
-- ============================================================================

-- ============================================================================
-- SECTION 1: NUMERIC DATA TYPES
-- ============================================================================

/*
INTEGER TYPES:
- TINYINT: -128 to 127 (1 byte)
- SMALLINT: -32,768 to 32,767 (2 bytes)
- MEDIUMINT: -8,388,608 to 8,388,607 (3 bytes)
- INT/INTEGER: -2,147,483,648 to 2,147,483,647 (4 bytes)
- BIGINT: -9,223,372,036,854,775,808 to 9,223,372,036,854,775,807 (8 bytes)

UNSIGNED versions double the positive range (no negative numbers)
*/

CREATE TABLE numeric_examples (
    -- Integer types
    tiny_col TINYINT,                    -- Small numbers like age, rating
    small_col SMALLINT,                  -- Medium numbers
    medium_col MEDIUMINT,                -- Larger counts
    int_col INT,                         -- Standard integer
    big_col BIGINT,                      -- Very large numbers (e.g., phone numbers)
    
    -- Decimal/Fixed-point (exact precision - use for money!)
    price DECIMAL(10, 2),                -- 10 total digits, 2 after decimal
    salary DECIMAL(15, 2),               -- Up to 999,999,999,999.99
    tax_rate DECIMAL(5, 4),              -- Like 0.1850 (18.50%)
    
    -- Floating-point (approximate - use for scientific calculations)
    float_col FLOAT,                     -- 4 bytes, ~7 decimal digits precision
    double_col DOUBLE,                   -- 8 bytes, ~15 decimal digits precision
    
    -- Boolean (stored as TINYINT(1) in MySQL)
    is_active BOOLEAN,                   -- TRUE/FALSE or 1/0
    
    id INT PRIMARY KEY AUTO_INCREMENT
);

-- IMPORTANT: Always use DECIMAL for money, never FLOAT!
-- FLOAT can cause rounding errors in financial calculations

INSERT INTO numeric_examples (tiny_col, price, is_active)
VALUES (25, 1500000.50, TRUE);

-- ============================================================================
-- SECTION 2: STRING/TEXT DATA TYPES
-- ============================================================================

CREATE TABLE string_examples (
    id INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Fixed-length string (always uses specified space)
    country_code CHAR(2),                -- 'UG', 'KE', 'TZ'
    phone_prefix CHAR(4),                -- '+256'
    
    -- Variable-length string (uses only needed space + 1-2 bytes)
    first_name VARCHAR(50),              -- Up to 50 characters
    email VARCHAR(255),                  -- Standard email length
    description VARCHAR(1000),           -- Longer text
    
    -- Text types (for large amounts of text)
    short_bio TINYTEXT,                  -- Up to 255 characters
    article TEXT,                        -- Up to 65,535 characters
    full_book MEDIUMTEXT,                -- Up to 16,777,215 characters
    massive_data LONGTEXT,               -- Up to 4,294,967,295 characters
    
    -- Binary data
    small_binary BINARY(16),             -- Fixed-length binary (like UUIDs)
    variable_binary VARBINARY(255),      -- Variable-length binary
    file_data BLOB,                      -- Binary Large Object
    
    -- Enum (predefined list of values)
    status ENUM('active', 'inactive', 'pending', 'suspended'),
    
    -- Set (can have multiple values from list)
    permissions SET('read', 'write', 'delete', 'admin')
);

-- VARCHAR vs CHAR
-- Use CHAR for fixed-length data (country codes, phone prefixes)
-- Use VARCHAR for variable-length data (names, emails)

INSERT INTO string_examples (country_code, first_name, email, status, permissions)
VALUES ('UG', 'Amina', 'amina@example.ug', 'active', 'read,write');

-- ============================================================================
-- SECTION 3: DATE AND TIME DATA TYPES
-- ============================================================================

CREATE TABLE datetime_examples (
    id INT PRIMARY KEY AUTO_INCREMENT,
    
    -- Date only (YYYY-MM-DD)
    birth_date DATE,                     -- '2000-05-15'
    
    -- Time only (HH:MM:SS)
    work_start TIME,                     -- '08:30:00'
    
    -- Date and time combined
    created_at DATETIME,                 -- '2024-05-15 14:30:00'
    
    -- Timestamp (auto-updates, timezone aware)
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Year only
    graduation_year YEAR                 -- 2024
);

-- Date/Time Functions
INSERT INTO datetime_examples (birth_date, work_start, created_at)
VALUES ('1995-08-20', '09:00:00', NOW());

-- Current date and time functions
SELECT 
    CURRENT_DATE() AS today,
    CURRENT_TIME() AS current_time,
    NOW() AS date_and_time,
    CURDATE() AS also_today,
    CURTIME() AS also_current_time;

-- Date arithmetic
SELECT 
    DATE_ADD('2024-01-15', INTERVAL 30 DAY) AS thirty_days_later,
    DATE_SUB('2024-01-15', INTERVAL 1 MONTH) AS one_month_before,
    DATEDIFF('2024-12-31', '2024-01-01') AS days_in_year;

-- Extract parts of date
SELECT 
    YEAR(NOW()) AS current_year,
    MONTH(NOW()) AS current_month,
    DAY(NOW()) AS current_day,
    DAYNAME(NOW()) AS day_name,
    MONTHNAME(NOW()) AS month_name,
    QUARTER(NOW()) AS current_quarter,
    WEEK(NOW()) AS week_of_year;

-- Format dates
SELECT DATE_FORMAT(NOW(), '%W, %M %d, %Y') AS formatted_date;
-- Output: "Wednesday, May 15, 2024"

-- ============================================================================
-- SECTION 4: JSON DATA TYPE (Modern SQL)
-- ============================================================================

CREATE TABLE json_examples (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_name VARCHAR(50),
    preferences JSON,
    metadata JSON
);

-- Insert JSON data
INSERT INTO json_examples (user_name, preferences, metadata)
VALUES (
    'joseph_k',
    '{"theme": "dark", "language": "en", "notifications": true}',
    '{"last_login": "2024-05-15", "login_count": 42, "devices": ["mobile", "desktop"]}'
);

-- Query JSON data (MySQL syntax)
SELECT 
    user_name,
    JSON_EXTRACT(preferences, '$.theme') AS theme,
    preferences->>'$.language' AS language,  -- Shorthand syntax
    JSON_EXTRACT(metadata, '$.devices[0]') AS first_device
FROM json_examples;

-- Update JSON data
UPDATE json_examples 
SET preferences = JSON_SET(preferences, '$.theme', 'light')
WHERE user_name = 'joseph_k';

-- ============================================================================
-- SECTION 5: SPATIAL DATA TYPES (For mapping/GIS)
-- ============================================================================

CREATE TABLE locations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    coordinates POINT,          -- Single point (latitude, longitude)
    area POLYGON,               -- Enclosed area
    route LINESTRING           -- Path/route
);

-- Insert a point (Kampala city center coordinates)
INSERT INTO locations (name, coordinates)
VALUES ('Kampala City Center', ST_GeomFromText('POINT(0.3476 32.5825)'));

-- Calculate distance between two points
SELECT ST_Distance_Sphere(
    ST_GeomFromText('POINT(0.3476 32.5825)'),  -- Kampala
    ST_GeomFromText('POINT(-1.2921 36.8219)')   -- Nairobi
) / 1000 AS distance_km;

-- ============================================================================
-- SECTION 6: UUID DATA TYPE
-- ============================================================================

CREATE TABLE uuid_examples (
    -- Using BINARY(16) for efficient storage
    id BINARY(16) PRIMARY KEY DEFAULT (UUID_TO_BIN(UUID())),
    name VARCHAR(100)
);

-- Or using CHAR(36) for human-readable storage
CREATE TABLE uuid_char_examples (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    name VARCHAR(100)
);

INSERT INTO uuid_char_examples (name) VALUES ('Test Record');

SELECT * FROM uuid_char_examples;

-- ============================================================================
-- SECTION 7: CHOOSING THE RIGHT DATA TYPE
-- ============================================================================

/*
BEST PRACTICES FOR DATA TYPE SELECTION:

1. INTEGERS
   - Use the smallest type that fits your data range
   - IDs: INT or BIGINT depending on expected records
   - Age: TINYINT UNSIGNED (0-255)
   - Year: YEAR or SMALLINT

2. MONEY/CURRENCY
   - ALWAYS use DECIMAL(precision, scale)
   - UGX: DECIMAL(15, 2) for amounts up to trillions
   - USD: DECIMAL(10, 2) for most applications
   - NEVER use FLOAT/DOUBLE for money!

3. STRINGS
   - Fixed values (codes): CHAR
   - Variable text: VARCHAR
   - Large text: TEXT types
   - Email: VARCHAR(255)
   - Phone: VARCHAR(20)
   - Names: VARCHAR(50-100)

4. DATES/TIMES
   - Date only: DATE
   - Time only: TIME
   - Both: DATETIME or TIMESTAMP
   - Timezone needed: TIMESTAMP

5. BOOLEAN
   - Use BOOLEAN (TINYINT(1))
   - Or ENUM('Y', 'N') for explicit values

6. IDs
   - Auto-increment: INT or BIGINT
   - UUID: BINARY(16) for distributed systems
*/

-- Example: Well-designed table for Uganda business
CREATE TABLE customers (
    customer_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    
    -- Personal info
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),                    -- +256 XXX XXX XXX
    national_id CHAR(14),                 -- Uganda NIN format
    
    -- Address
    district VARCHAR(50),
    city VARCHAR(50),
    address_line TEXT,
    
    -- Financial
    credit_limit DECIMAL(12, 2) DEFAULT 0,
    account_balance DECIMAL(15, 2) DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT TRUE,
    customer_type ENUM('individual', 'business', 'government') DEFAULT 'individual',
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Flexible data
    preferences JSON,
    
    -- Indexes
    INDEX idx_email (email),
    INDEX idx_phone (phone),
    INDEX idx_district (district)
);

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Create a table 'products' with appropriate data types:
- product_id (auto-increment)
- sku (exactly 8 characters)
- name (up to 200 chars)
- description (long text)
- price_ugx (Uganda shillings, 2 decimal places)
- weight_kg (decimal, 3 decimal places)
- stock_count (non-negative integer)
- is_available (true/false)
- category (one of: 'electronics', 'clothing', 'food', 'other')
- created_at (auto timestamp)
- attributes (flexible JSON for various product specs)

EXERCISE 2: Create a table 'transactions' for a mobile money system:
- transaction_id (UUID)
- sender_phone
- receiver_phone
- amount (precise money)
- transaction_type (send, withdraw, deposit, pay_bill)
- timestamp
- status (pending, completed, failed, reversed)
- location coordinates

EXERCISE 3: Insert sample data into both tables

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

