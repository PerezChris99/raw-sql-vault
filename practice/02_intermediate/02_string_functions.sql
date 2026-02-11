-- ============================================================================
-- SQL STRING FUNCTIONS: TEXT MANIPULATION MASTERY
-- Module 09: Complete String Functions Reference
-- Goal: Transform, parse, and analyze text data expertly
-- ============================================================================

-- ============================================================================
-- SECTION 1: STRING LENGTH AND SIZE FUNCTIONS
-- ============================================================================

SELECT 
    -- LENGTH: Number of bytes
    LENGTH('Hello') AS length_hello,           -- 5
    LENGTH('Café') AS length_cafe,             -- 5 (é is 2 bytes in UTF8)
    
    -- CHAR_LENGTH / CHARACTER_LENGTH: Number of characters
    CHAR_LENGTH('Hello') AS char_length_hello, -- 5
    CHAR_LENGTH('Café') AS char_length_cafe,   -- 4
    
    -- BIT_LENGTH: Number of bits
    BIT_LENGTH('Hello') AS bit_length;         -- 40 (5 chars × 8 bits)

-- Practical example: Validate string lengths
CREATE TABLE user_profiles (
    username VARCHAR(50),
    bio TEXT
);

INSERT INTO user_profiles VALUES
('john_mukasa', 'Senior developer from Kampala with 10 years experience'),
('sarah_n', 'Marketing specialist'),
('peter_o', 'Engineer specializing in renewable energy solutions for East Africa');

SELECT 
    username,
    CHAR_LENGTH(bio) AS bio_length,
    CASE 
        WHEN CHAR_LENGTH(bio) > 50 THEN 'Long bio'
        WHEN CHAR_LENGTH(bio) > 20 THEN 'Medium bio'
        ELSE 'Short bio'
    END AS bio_category
FROM user_profiles;

-- ============================================================================
-- SECTION 2: CASE CONVERSION FUNCTIONS
-- ============================================================================

SELECT 
    UPPER('hello world') AS uppercase,         -- HELLO WORLD
    LOWER('HELLO WORLD') AS lowercase,         -- hello world
    -- Some database have additional functions:
    -- INITCAP('hello world')                  -- Hello World (PostgreSQL)
    CONCAT(UPPER(LEFT('hello', 1)), LOWER(SUBSTRING('hello', 2))) AS title_case;

-- Practical: Standardize data entry
UPDATE customers
SET 
    first_name = CONCAT(UPPER(LEFT(first_name, 1)), LOWER(SUBSTRING(first_name, 2))),
    last_name = CONCAT(UPPER(LEFT(last_name, 1)), LOWER(SUBSTRING(last_name, 2))),
    email = LOWER(email);

-- Case-insensitive search (convert both sides)
SELECT * FROM customers
WHERE LOWER(email) = LOWER('John@Example.COM');

-- ============================================================================
-- SECTION 3: SUBSTRING AND EXTRACTION FUNCTIONS
-- ============================================================================

SELECT 
    -- SUBSTRING / SUBSTR: Extract portion of string
    SUBSTRING('Hello World', 1, 5) AS sub1,    -- Hello (start, length)
    SUBSTRING('Hello World', 7) AS sub2,       -- World (start to end)
    SUBSTRING('Hello World', -5) AS sub3,      -- World (MySQL: from end)
    
    -- LEFT / RIGHT: Characters from start/end
    LEFT('Hello World', 5) AS left_5,          -- Hello
    RIGHT('Hello World', 5) AS right_5,        -- World
    
    -- MID (MySQL alias for SUBSTRING)
    MID('Hello World', 1, 5) AS mid_result;    -- Hello

-- Extract parts of structured data
SELECT 
    email,
    SUBSTRING_INDEX(email, '@', 1) AS username,
    SUBSTRING_INDEX(email, '@', -1) AS domain
FROM customers;

-- Extract phone number parts (+256 XXX XXX XXX)
SELECT 
    phone,
    LEFT(phone, 4) AS country_code,
    SUBSTRING(phone, 5, 3) AS area_code,
    RIGHT(phone, 6) AS local_number
FROM customers;

-- ============================================================================
-- SECTION 4: STRING SEARCH AND POSITION FUNCTIONS
-- ============================================================================

SELECT 
    -- LOCATE / INSTR / POSITION: Find position of substring
    LOCATE('o', 'Hello World') AS locate_o,        -- 5 (first occurrence)
    LOCATE('o', 'Hello World', 6) AS locate_o_2,   -- 8 (search from position 6)
    INSTR('Hello World', 'World') AS instr_world,  -- 7
    
    -- FIND_IN_SET: Position in comma-separated list
    FIND_IN_SET('b', 'a,b,c,d') AS find_in_set;    -- 2

-- Check if substring exists
SELECT 
    product_name,
    CASE WHEN LOCATE('Pro', product_name) > 0 THEN 'Pro Product' ELSE 'Standard' END AS tier
FROM products;

-- Find all occurrences (needs loop in application code, or recursive CTE)
WITH RECURSIVE positions AS (
    SELECT 
        'banana' AS str,
        'a' AS search_char,
        LOCATE('a', 'banana', 1) AS pos,
        1 AS occurrence
    
    UNION ALL
    
    SELECT 
        str,
        search_char,
        LOCATE(search_char, str, pos + 1),
        occurrence + 1
    FROM positions
    WHERE LOCATE(search_char, str, pos + 1) > 0
)
SELECT pos, occurrence FROM positions WHERE pos > 0;

-- ============================================================================
-- SECTION 5: STRING CONCATENATION
-- ============================================================================

SELECT 
    -- CONCAT: Join strings
    CONCAT('Hello', ' ', 'World') AS concat_result,           -- Hello World
    CONCAT(first_name, ' ', last_name) AS full_name,
    
    -- CONCAT_WS: Concatenate With Separator (ignores NULLs)
    CONCAT_WS(', ', city, district, 'Uganda') AS address,     -- city, district, Uganda
    CONCAT_WS(' | ', NULL, 'A', NULL, 'B') AS skip_nulls      -- A | B

FROM customers;

-- Build structured data
SELECT 
    product_id,
    CONCAT('[', product_id, '] ', UPPER(product_name), ' - ', 
           FORMAT(price, 0), ' UGX') AS product_label
FROM products;

-- Create JSON-like structure manually
SELECT 
    CONCAT('{"id":', customer_id, 
           ',"name":"', customer_name, 
           '","district":"', district, '"}') AS json_string
FROM customers;

-- ============================================================================
-- SECTION 6: STRING TRIMMING AND PADDING
-- ============================================================================

SELECT 
    -- TRIM: Remove leading/trailing spaces (or specified characters)
    TRIM('  Hello World  ') AS trim_spaces,          -- 'Hello World'
    TRIM(LEADING '0' FROM '00123') AS ltrim_zeros,   -- '123'
    TRIM(TRAILING '.' FROM 'Hello...') AS rtrim_dots,-- 'Hello'
    TRIM(BOTH 'x' FROM 'xxxHelloxxx') AS trim_x,     -- 'Hello'
    
    -- LTRIM / RTRIM: Left/Right trim only
    LTRIM('  Hello') AS ltrim_result,                -- 'Hello'
    RTRIM('Hello  ') AS rtrim_result,                -- 'Hello'
    
    -- LPAD / RPAD: Pad to specific length
    LPAD('123', 6, '0') AS lpad_zeros,               -- '000123'
    RPAD('Hello', 10, '.') AS rpad_dots,             -- 'Hello.....'
    LPAD(5, 3, '0') AS leading_zeros;                -- '005'

-- Practical: Clean user input
UPDATE customers
SET 
    first_name = TRIM(first_name),
    last_name = TRIM(last_name),
    phone = TRIM(phone);

-- Format order numbers with leading zeros
SELECT 
    order_id,
    CONCAT('ORD-', LPAD(order_id, 8, '0')) AS order_number
FROM orders;

-- ============================================================================
-- SECTION 7: STRING REPLACEMENT AND MODIFICATION
-- ============================================================================

SELECT 
    -- REPLACE: Replace all occurrences
    REPLACE('Hello World', 'World', 'Uganda') AS replace_ex,  -- Hello Uganda
    REPLACE('banana', 'a', 'o') AS replace_all,               -- bonono
    
    -- INSERT: Insert/overwrite at position
    INSERT('Hello World', 7, 5, 'Uganda') AS insert_ex,       -- Hello Uganda
    INSERT('Hello World', 7, 0, 'Beautiful ') AS insert_only, -- Hello Beautiful World
    
    -- REVERSE: Reverse string
    REVERSE('Hello') AS reversed,                              -- olleH
    
    -- REPEAT: Repeat string N times
    REPEAT('*', 10) AS stars,                                  -- **********
    REPEAT('La', 3) AS la_la_la;                              -- LaLaLa

-- Clean phone numbers (remove formatting)
SELECT 
    phone,
    REPLACE(REPLACE(REPLACE(phone, '-', ''), ' ', ''), '+', '') AS clean_phone
FROM customers;

-- Mask sensitive data
SELECT 
    email,
    CONCAT(
        LEFT(SUBSTRING_INDEX(email, '@', 1), 2),
        REPEAT('*', CHAR_LENGTH(SUBSTRING_INDEX(email, '@', 1)) - 2),
        '@',
        SUBSTRING_INDEX(email, '@', -1)
    ) AS masked_email
FROM customers;

-- ============================================================================
-- SECTION 8: PATTERN MATCHING (LIKE, REGEXP)
-- ============================================================================

-- LIKE patterns
SELECT * FROM products WHERE product_name LIKE 'Laptop%';     -- Starts with
SELECT * FROM products WHERE product_name LIKE '%Pro';        -- Ends with
SELECT * FROM products WHERE product_name LIKE '%Office%';    -- Contains
SELECT * FROM products WHERE product_name LIKE 'L_ptop%';     -- Single char wildcard
SELECT * FROM products WHERE product_name LIKE '[LM]%';       -- SQL Server: starts with L or M

-- REGEXP / RLIKE: Regular expression matching (MySQL)
SELECT * FROM products WHERE product_name REGEXP '^[A-M]';    -- Starts with A-M
SELECT * FROM products WHERE product_name REGEXP 'Pro$';      -- Ends with Pro
SELECT * FROM products WHERE product_name REGEXP '[0-9]';     -- Contains digit
SELECT * FROM products WHERE product_name REGEXP '^(Laptop|Phone)'; -- Starts with Laptop or Phone

-- Validate email format
SELECT 
    email,
    CASE 
        WHEN email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' 
        THEN 'Valid'
        ELSE 'Invalid'
    END AS email_status
FROM customers;

-- Validate Uganda phone number (+256XXXXXXXXX)
SELECT 
    phone,
    CASE 
        WHEN phone REGEXP '^\\+256[0-9]{9}$' THEN 'Valid'
        WHEN phone REGEXP '^0[0-9]{9}$' THEN 'Valid (Local)'
        ELSE 'Invalid'
    END AS phone_status
FROM customers;

-- ============================================================================
-- SECTION 9: STRING SPLITTING AND PARSING
-- ============================================================================

-- SUBSTRING_INDEX: Split by delimiter
SELECT 
    'John,Mukasa,Kampala,Uganda' AS full_string,
    SUBSTRING_INDEX('John,Mukasa,Kampala,Uganda', ',', 1) AS first,      -- John
    SUBSTRING_INDEX('John,Mukasa,Kampala,Uganda', ',', 2) AS first_two,  -- John,Mukasa
    SUBSTRING_INDEX('John,Mukasa,Kampala,Uganda', ',', -1) AS last,      -- Uganda
    SUBSTRING_INDEX('John,Mukasa,Kampala,Uganda', ',', -2) AS last_two;  -- Kampala,Uganda

-- Extract middle element (by removing before and after)
SELECT 
    SUBSTRING_INDEX(
        SUBSTRING_INDEX('John,Mukasa,Kampala,Uganda', ',', 3), 
        ',', 
        -1
    ) AS third_element;  -- Kampala

-- Parse URL components
SELECT 
    url,
    SUBSTRING_INDEX(SUBSTRING_INDEX(url, '://', -1), '/', 1) AS domain,
    SUBSTRING_INDEX(url, '/', -1) AS page
FROM (SELECT 'https://www.example.ug/products/laptop' AS url) t;

-- Split into rows (MySQL 8.0+)
WITH RECURSIVE split_string AS (
    SELECT 
        1 AS n,
        SUBSTRING_INDEX('apple,banana,cherry,date', ',', 1) AS value,
        'apple,banana,cherry,date' AS remaining
    
    UNION ALL
    
    SELECT 
        n + 1,
        SUBSTRING_INDEX(SUBSTRING_INDEX(remaining, ',', n + 1), ',', -1),
        remaining
    FROM split_string
    WHERE n < LENGTH(remaining) - LENGTH(REPLACE(remaining, ',', '')) + 1
)
SELECT n, value FROM split_string;

-- ============================================================================
-- SECTION 10: ENCODING AND SPECIAL FUNCTIONS
-- ============================================================================

SELECT 
    -- ASCII / CHAR: Character codes
    ASCII('A') AS ascii_a,                    -- 65
    CHAR(65) AS char_65,                      -- A
    
    -- HEX / UNHEX: Hexadecimal conversion
    HEX('ABC') AS hex_abc,                    -- 414243
    UNHEX('414243') AS unhex_result,          -- ABC
    
    -- BASE64 encoding (MySQL 5.6+)
    TO_BASE64('Hello World') AS base64_encoded,
    FROM_BASE64(TO_BASE64('Hello World')) AS base64_decoded,
    
    -- SOUNDEX: Phonetic encoding
    SOUNDEX('Robert') AS soundex_robert,      -- R163
    SOUNDEX('Rupert') AS soundex_rupert,      -- R163 (same!)
    
    -- MD5/SHA: Hash functions
    MD5('password') AS md5_hash,
    SHA1('password') AS sha1_hash,
    SHA2('password', 256) AS sha256_hash;

-- Find similar-sounding names
SELECT c1.customer_name, c2.customer_name
FROM customers c1
JOIN customers c2 ON SOUNDEX(c1.customer_name) = SOUNDEX(c2.customer_name)
                  AND c1.customer_id < c2.customer_id;

-- ============================================================================
-- SECTION 11: FORMATTING FUNCTIONS
-- ============================================================================

SELECT 
    -- FORMAT: Number formatting with thousands separator
    FORMAT(1234567.89, 2) AS formatted_number,     -- 1,234,567.89
    FORMAT(1234567.89, 0) AS no_decimals,          -- 1,234,568
    
    -- SPACE: Generate spaces
    CONCAT('|', SPACE(5), '|') AS spaces,          -- |     |
    
    -- QUOTE: Escape for SQL
    QUOTE('Hello "World"') AS quoted;              -- 'Hello \"World\"'

-- Currency formatting (Uganda Shillings)
SELECT 
    product_name,
    price,
    CONCAT('UGX ', FORMAT(price, 0)) AS formatted_price
FROM products;

-- ============================================================================
-- SECTION 12: PRACTICAL STRING FUNCTION APPLICATIONS
-- ============================================================================

-- Application 1: Generate slug from title
SELECT 
    title,
    LOWER(
        REPLACE(
            REPLACE(
                TRIM(title), 
                ' ', '-'
            ),
            '--', '-'
        )
    ) AS slug
FROM articles;

-- Application 2: Extract initials
SELECT 
    customer_name,
    CONCAT(
        LEFT(SUBSTRING_INDEX(customer_name, ' ', 1), 1),
        LEFT(SUBSTRING_INDEX(customer_name, ' ', -1), 1)
    ) AS initials
FROM customers;

-- Application 3: Parse full name into parts
SELECT 
    full_name,
    CASE 
        WHEN CHAR_LENGTH(full_name) - CHAR_LENGTH(REPLACE(full_name, ' ', '')) = 0 
        THEN full_name   -- Single name
        ELSE SUBSTRING_INDEX(full_name, ' ', 1) 
    END AS first_name,
    CASE 
        WHEN CHAR_LENGTH(full_name) - CHAR_LENGTH(REPLACE(full_name, ' ', '')) = 0 
        THEN NULL
        ELSE SUBSTRING_INDEX(full_name, ' ', -1) 
    END AS last_name
FROM (
    SELECT 'John Mukasa' AS full_name
    UNION SELECT 'Madonna'
    UNION SELECT 'Sarah Jane Nalwoga'
) names;

-- Application 4: Clean and standardize product codes
SELECT 
    raw_code,
    UPPER(
        TRIM(
            REPLACE(
                REPLACE(raw_code, ' ', ''),
                '-', ''
            )
        )
    ) AS clean_code
FROM (
    SELECT 'ABC-123' AS raw_code
    UNION SELECT 'def 456'
    UNION SELECT '  GHI-789  '
) codes;

-- Application 5: Generate random string (for passwords, tokens)
SELECT 
    SUBSTRING(MD5(RAND()), 1, 16) AS random_token,
    CONCAT(
        CHAR(FLOOR(65 + RAND() * 26)),  -- Random uppercase
        CHAR(FLOOR(97 + RAND() * 26)),  -- Random lowercase
        CHAR(FLOOR(48 + RAND() * 10)),  -- Random digit
        SUBSTRING(MD5(RAND()), 1, 5)
    ) AS random_password;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: String extraction and parsing
a) Extract domain from email addresses
b) Parse phone numbers into country code, area code, and local number
c) Extract first word from product names
d) Get file extension from filenames

EXERCISE 2: String validation
a) Find emails with invalid formats
b) Find phone numbers not matching Uganda format
c) Find names containing numbers (data entry errors)
d) Find strings with leading/trailing spaces

EXERCISE 3: String transformation
a) Convert 'john doe' to 'John Doe' (title case)
b) Create email from first_name and last_name (john.doe@company.ug)
c) Mask credit card numbers (show only last 4 digits)
d) Create initials from full names

EXERCISE 4: String analysis
a) Find the longest product name
b) Count words in product descriptions
c) Find products where name contains multiple words
d) Identify duplicate content with different casing

EXERCISE 5: Advanced parsing
a) Parse CSV string into individual rows
b) Extract hashtags from social media posts
c) Parse URL query parameters
d) Split camelCase into separate words

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

