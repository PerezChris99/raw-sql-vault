-- ============================================================================
-- SQL JSON AND MODERN DATA TYPES
-- Module 18: Working with JSON and Semi-Structured Data
-- Goal: Master modern SQL features for flexible data handling
-- ============================================================================

-- ============================================================================
-- SECTION 1: JSON COLUMN BASICS
-- ============================================================================

/*
JSON in MySQL (5.7+):
- Native JSON data type
- Automatic validation
- Binary storage format
- Rich function support

Use Cases:
- Flexible schemas
- Configuration storage
- API response caching
- Document-style data
*/

-- Create table with JSON column
CREATE TABLE products_extended (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100),
    base_price DECIMAL(10,2),
    attributes JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert JSON data
INSERT INTO products_extended (product_name, base_price, attributes)
VALUES (
    'Smartphone X',
    1500000,
    '{
        "brand": "TechCo",
        "color": "black",
        "storage_gb": 128,
        "features": ["5G", "Dual SIM", "Face ID"],
        "dimensions": {
            "height": 150,
            "width": 75,
            "depth": 8
        }
    }'
);

-- Insert using JSON_OBJECT and JSON_ARRAY functions
INSERT INTO products_extended (product_name, base_price, attributes)
VALUES (
    'Laptop Pro',
    4500000,
    JSON_OBJECT(
        'brand', 'CompuTech',
        'specs', JSON_OBJECT(
            'ram_gb', 16,
            'cpu', 'Intel i7',
            'ssd_gb', 512
        ),
        'ports', JSON_ARRAY('USB-C', 'HDMI', 'USB 3.0')
    )
);

-- ============================================================================
-- SECTION 2: EXTRACTING JSON DATA
-- ============================================================================

-- Using -> operator (returns JSON)
SELECT 
    product_name,
    attributes->'$.brand' AS brand_json,
    attributes->'$.storage_gb' AS storage_json
FROM products_extended;

-- Using ->> operator (returns text, unquoted)
SELECT 
    product_name,
    attributes->>'$.brand' AS brand,
    attributes->>'$.storage_gb' AS storage
FROM products_extended;

-- JSON_EXTRACT function (same as ->)
SELECT 
    product_name,
    JSON_EXTRACT(attributes, '$.brand') AS brand,
    JSON_EXTRACT(attributes, '$.dimensions.height') AS height,
    JSON_EXTRACT(attributes, '$.features[0]') AS first_feature
FROM products_extended;

-- JSON_UNQUOTE (removes quotes)
SELECT 
    product_name,
    JSON_UNQUOTE(JSON_EXTRACT(attributes, '$.brand')) AS brand
FROM products_extended;

-- Extract nested values
SELECT 
    product_name,
    attributes->>'$.specs.ram_gb' AS ram,
    attributes->>'$.specs.cpu' AS cpu,
    attributes->'$.ports[0]' AS first_port
FROM products_extended;

-- ============================================================================
-- SECTION 3: JSON PATH EXPRESSIONS
-- ============================================================================

/*
JSON PATH SYNTAX:
$ - Root document
.key - Object member
[n] - Array element (0-indexed)
[*] - All array elements
.* - All object members
** - Recursive descent
*/

-- Example data
SET @json = '{
    "store": {
        "name": "Kampala Tech Store",
        "address": {
            "street": "Kampala Road",
            "city": "Kampala"
        },
        "inventory": [
            {"item": "phone", "price": 1500000, "quantity": 50},
            {"item": "laptop", "price": 4000000, "quantity": 20},
            {"item": "tablet", "price": 2000000, "quantity": 30}
        ]
    }
}';

-- Path examples
SELECT JSON_EXTRACT(@json, '$.store.name');           -- Store name
SELECT JSON_EXTRACT(@json, '$.store.address.city');   -- City
SELECT JSON_EXTRACT(@json, '$.store.inventory[0]');   -- First inventory item
SELECT JSON_EXTRACT(@json, '$.store.inventory[*].item'); -- All item names
SELECT JSON_EXTRACT(@json, '$.store.inventory[1].price'); -- Second item price

-- ============================================================================
-- SECTION 4: JSON MODIFICATION FUNCTIONS
-- ============================================================================

-- JSON_SET: Set values (creates if not exists)
SELECT JSON_SET(
    '{"name": "test", "value": 100}',
    '$.value', 200,           -- Update existing
    '$.new_key', 'new value'  -- Add new
);

-- JSON_REPLACE: Replace existing values only
SELECT JSON_REPLACE(
    '{"name": "test", "value": 100}',
    '$.value', 200,           -- Updates
    '$.new_key', 'ignored'    -- Ignored (doesn't exist)
);

-- JSON_INSERT: Insert new values only
SELECT JSON_INSERT(
    '{"name": "test", "value": 100}',
    '$.value', 200,           -- Ignored (exists)
    '$.new_key', 'added'      -- Added
);

-- JSON_REMOVE: Remove keys
SELECT JSON_REMOVE(
    '{"a": 1, "b": 2, "c": 3}',
    '$.b'
);

-- JSON_ARRAY_APPEND: Add to array
SELECT JSON_ARRAY_APPEND(
    '{"features": ["wifi", "bluetooth"]}',
    '$.features', '5G'
);

-- JSON_ARRAY_INSERT: Insert at position
SELECT JSON_ARRAY_INSERT(
    '{"items": ["a", "c"]}',
    '$.items[1]', 'b'  -- Insert 'b' at position 1
);

-- Update JSON column in table
UPDATE products_extended
SET attributes = JSON_SET(attributes, '$.on_sale', true, '$.discount_percent', 10)
WHERE product_id = 1;

-- ============================================================================
-- SECTION 5: JSON QUERY FUNCTIONS
-- ============================================================================

-- JSON_CONTAINS: Check if value exists
SELECT product_name
FROM products_extended
WHERE JSON_CONTAINS(attributes, '"5G"', '$.features');

SELECT product_name
FROM products_extended
WHERE JSON_CONTAINS(attributes->'$.features', '"5G"');

-- JSON_CONTAINS_PATH: Check if path exists
SELECT product_name
FROM products_extended
WHERE JSON_CONTAINS_PATH(attributes, 'one', '$.dimensions', '$.specs');

-- 'one': At least one path exists
-- 'all': All paths must exist

-- JSON_SEARCH: Find path to value
SELECT JSON_SEARCH(
    '{"items": ["apple", "banana", "cherry"]}',
    'one',    -- Return first match
    'banana'
);

-- JSON_KEYS: Get all keys
SELECT JSON_KEYS(attributes) FROM products_extended;
SELECT JSON_KEYS(attributes, '$.dimensions') FROM products_extended WHERE product_id = 1;

-- JSON_LENGTH: Count elements
SELECT 
    product_name,
    JSON_LENGTH(attributes) AS top_level_keys,
    JSON_LENGTH(attributes->'$.features') AS feature_count
FROM products_extended;

-- JSON_TYPE: Get JSON value type
SELECT JSON_TYPE('{"a": 1}');           -- OBJECT
SELECT JSON_TYPE('[1, 2, 3]');          -- ARRAY
SELECT JSON_TYPE('"hello"');             -- STRING
SELECT JSON_TYPE('123');                 -- INTEGER
SELECT JSON_TYPE('true');                -- BOOLEAN

-- JSON_VALID: Check if valid JSON
SELECT JSON_VALID('{"valid": true}');    -- 1
SELECT JSON_VALID('not json');           -- 0

-- ============================================================================
-- SECTION 6: JSON TABLE (MySQL 8.0+)
-- ============================================================================

-- Convert JSON array to rows
SELECT * FROM JSON_TABLE(
    '[
        {"name": "Alice", "age": 30},
        {"name": "Bob", "age": 25},
        {"name": "Carol", "age": 35}
    ]',
    '$[*]' COLUMNS (
        name VARCHAR(50) PATH '$.name',
        age INT PATH '$.age'
    )
) AS people;

-- JSON_TABLE with nested arrays
SELECT * FROM JSON_TABLE(
    '{
        "order_id": 1001,
        "items": [
            {"product": "Phone", "qty": 2, "price": 1500000},
            {"product": "Case", "qty": 2, "price": 50000}
        ]
    }',
    '$.items[*]' COLUMNS (
        product VARCHAR(50) PATH '$.product',
        quantity INT PATH '$.qty',
        unit_price DECIMAL(10,2) PATH '$.price'
    )
) AS order_items;

-- JSON_TABLE from column
SELECT 
    pe.product_name,
    features.feature
FROM products_extended pe,
JSON_TABLE(
    pe.attributes,
    '$.features[*]' COLUMNS (
        feature VARCHAR(50) PATH '$'
    )
) AS features
WHERE pe.product_id = 1;

-- ============================================================================
-- SECTION 7: JSON INDEXING
-- ============================================================================

-- Virtual (generated) column for indexing
ALTER TABLE products_extended
ADD COLUMN brand VARCHAR(50) 
GENERATED ALWAYS AS (attributes->>'$.brand') VIRTUAL;

CREATE INDEX idx_brand ON products_extended(brand);

-- Now this query uses the index
SELECT * FROM products_extended WHERE brand = 'TechCo';

-- Functional index (MySQL 8.0.13+)
CREATE INDEX idx_storage ON products_extended((CAST(attributes->>'$.storage_gb' AS UNSIGNED)));

-- Multi-valued index (MySQL 8.0.17+) for arrays
CREATE TABLE products_tags (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    tags JSON
);

INSERT INTO products_tags VALUES (1, 'Phone', '["electronics", "mobile", "smart"]');
INSERT INTO products_tags VALUES (2, 'Laptop', '["electronics", "computer", "portable"]');

ALTER TABLE products_tags ADD INDEX idx_tags ((CAST(tags AS CHAR(50) ARRAY)));

-- Query using multi-valued index
SELECT * FROM products_tags
WHERE 'electronics' MEMBER OF (tags);

-- ============================================================================
-- SECTION 8: PRACTICAL JSON PATTERNS
-- ============================================================================

-- Pattern 1: Flexible product attributes
CREATE TABLE products_flexible (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    base_info JSON NOT NULL,
    specifications JSON,
    pricing JSON,
    inventory JSON
);

INSERT INTO products_flexible VALUES (
    1,
    'Gaming Laptop',
    'Electronics',
    '{"brand": "TechBrand", "model": "GX-5000", "sku": "TB-GX5000-001"}',
    '{"processor": "Intel i9", "ram_gb": 32, "storage_tb": 1, "gpu": "RTX 4080"}',
    '{"base_price": 5500000, "currency": "UGX", "vat_rate": 0.18}',
    '{"warehouse_a": 10, "warehouse_b": 5, "reserved": 2}'
);

-- Query flexible data
SELECT 
    product_name,
    base_info->>'$.brand' AS brand,
    specifications->>'$.processor' AS cpu,
    specifications->>'$.ram_gb' AS ram,
    CAST(pricing->>'$.base_price' AS DECIMAL(12,2)) AS price,
    (CAST(inventory->>'$.warehouse_a' AS SIGNED) + 
     CAST(inventory->>'$.warehouse_b' AS SIGNED) - 
     CAST(inventory->>'$.reserved' AS SIGNED)) AS available_stock
FROM products_flexible;

-- Pattern 2: Event tracking
CREATE TABLE user_events (
    event_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    event_data JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_type (user_id, event_type),
    INDEX idx_created (created_at)
);

INSERT INTO user_events (user_id, event_type, event_data) VALUES
(1, 'page_view', '{"page": "/products", "referrer": "google.com", "duration_ms": 45000}'),
(1, 'add_to_cart', '{"product_id": 101, "quantity": 2, "price": 1500000}'),
(1, 'purchase', '{"order_id": 5001, "total": 3000000, "items": 2, "payment_method": "mobile_money"}');

-- Analyze user behavior
SELECT 
    user_id,
    COUNT(*) AS total_events,
    SUM(CASE WHEN event_type = 'page_view' THEN 1 ELSE 0 END) AS page_views,
    SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS cart_adds,
    SUM(CASE WHEN event_type = 'purchase' THEN 
        CAST(event_data->>'$.total' AS DECIMAL(12,2)) ELSE 0 END) AS total_spent
FROM user_events
GROUP BY user_id;

-- Pattern 3: Configuration storage
CREATE TABLE app_config (
    config_key VARCHAR(100) PRIMARY KEY,
    config_value JSON NOT NULL,
    description VARCHAR(255),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

INSERT INTO app_config VALUES 
('email_settings', '{"smtp_host": "mail.example.com", "port": 587, "use_tls": true}', 'Email configuration', NOW()),
('payment_gateways', '{"enabled": ["mobile_money", "card", "bank"], "default": "mobile_money"}', 'Payment options', NOW()),
('feature_flags', '{"new_checkout": true, "beta_dashboard": false, "ai_recommendations": true}', 'Feature toggles', NOW());

-- Check feature flag
SELECT 
    CASE WHEN config_value->>'$.new_checkout' = 'true' THEN 1 ELSE 0 END AS new_checkout_enabled
FROM app_config 
WHERE config_key = 'feature_flags';

-- ============================================================================
-- SECTION 9: JSON AGGREGATION
-- ============================================================================

-- JSON_ARRAYAGG: Aggregate into array
SELECT JSON_ARRAYAGG(product_name) AS all_products
FROM products_extended;

-- JSON_OBJECTAGG: Aggregate into object
SELECT JSON_OBJECTAGG(product_name, base_price) AS product_prices
FROM products_extended;

-- Complex aggregation
SELECT 
    category,
    JSON_ARRAYAGG(
        JSON_OBJECT(
            'name', product_name,
            'price', base_price
        )
    ) AS products
FROM products_flexible
GROUP BY category;

-- Build complete JSON document
SELECT JSON_OBJECT(
    'report_date', CURDATE(),
    'total_products', COUNT(*),
    'categories', JSON_ARRAYAGG(DISTINCT category),
    'products', JSON_ARRAYAGG(
        JSON_OBJECT(
            'id', product_id,
            'name', product_name,
            'category', category
        )
    )
) AS report
FROM products_flexible;

-- ============================================================================
-- SECTION 10: JSON VS RELATIONAL DESIGN
-- ============================================================================

/*
WHEN TO USE JSON:
+ Highly variable attributes
+ Nested/hierarchical data
+ Data from external APIs
+ Configuration/settings
+ Denormalized read models
+ Rapid prototyping

WHEN TO AVOID JSON:
- Data needs to be indexed/queried frequently
- Data has consistent structure
- Relationships between JSON elements
- Heavy reporting requirements
- Need referential integrity

HYBRID APPROACH (Best Practice):
- Fixed, frequently-queried data: Regular columns
- Variable, occasional data: JSON column
*/

-- Hybrid design example
CREATE TABLE orders_hybrid (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,           -- Regular: Frequently joined
    order_date DATE NOT NULL,           -- Regular: Frequently filtered
    status VARCHAR(20) NOT NULL,        -- Regular: Frequently filtered
    total_amount DECIMAL(12,2) NOT NULL, -- Regular: Aggregated
    shipping_address JSON,              -- JSON: Complex, variable
    items JSON,                         -- JSON: Variable length
    metadata JSON,                      -- JSON: Optional/variable
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    INDEX idx_customer (customer_id),
    INDEX idx_date (order_date),
    INDEX idx_status (status)
);

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: JSON basics
a) Create a table storing user profiles with JSON preferences
b) Insert sample data with nested JSON structures
c) Query specific JSON fields at various levels
d) Update nested JSON values

EXERCISE 2: JSON querying
a) Find all products containing specific feature
b) Extract and flatten JSON arrays into rows
c) Aggregate data into JSON reports
d) Search JSON for specific patterns

EXERCISE 3: JSON indexing
a) Create generated columns from JSON fields
b) Build functional index on JSON data
c) Create multi-valued index on JSON array
d) Optimize queries using these indexes

EXERCISE 4: Real-world scenarios
a) Design event logging with flexible JSON payload
b) Build configuration management with JSON
c) Create audit trail with JSON change history
d) Implement EAV (Entity-Attribute-Value) with JSON

EXERCISE 5: JSON best practices
a) Design hybrid schema for e-commerce product catalog
b) Create JSON schema validation using CHECK constraints
c) Build JSON merge/patch procedure
d) Optimize JSON queries for performance

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

