-- ============================================================================
-- SQL DATE AND TIME FUNCTIONS: TEMPORAL DATA MASTERY
-- Module 10: Complete Date/Time Operations
-- Goal: Expert manipulation of temporal data for analytics and reporting
-- ============================================================================

-- ============================================================================
-- SECTION 1: CURRENT DATE/TIME FUNCTIONS
-- ============================================================================

SELECT 
    -- Current date and time
    NOW() AS now_datetime,                  -- 2024-05-15 14:30:45
    CURRENT_TIMESTAMP() AS curr_timestamp,  -- Same as NOW()
    SYSDATE() AS system_datetime,           -- Evaluated at execution time
    
    -- Date only
    CURDATE() AS current_date,              -- 2024-05-15
    CURRENT_DATE() AS curr_date,            -- Same as CURDATE()
    
    -- Time only
    CURTIME() AS current_time,              -- 14:30:45
    CURRENT_TIME() AS curr_time,            -- Same as CURTIME()
    
    -- Unix timestamp
    UNIX_TIMESTAMP() AS unix_ts,            -- 1715783445
    FROM_UNIXTIME(UNIX_TIMESTAMP()) AS from_unix;

-- Difference: NOW() vs SYSDATE()
-- NOW() is evaluated once per statement
-- SYSDATE() is evaluated at actual execution time
SELECT NOW(), SLEEP(2), NOW();       -- Both NOW() show same time
SELECT SYSDATE(), SLEEP(2), SYSDATE(); -- Second SYSDATE() is 2 seconds later

-- ============================================================================
-- SECTION 2: DATE/TIME EXTRACTION FUNCTIONS
-- ============================================================================

SELECT 
    NOW() AS full_datetime,
    
    -- Date parts
    YEAR(NOW()) AS year,                    -- 2024
    MONTH(NOW()) AS month,                  -- 5
    DAY(NOW()) AS day,                      -- 15
    DAYOFMONTH(NOW()) AS day_of_month,      -- 15 (same as DAY)
    
    -- Week-related
    WEEK(NOW()) AS week_number,             -- 20
    WEEKOFYEAR(NOW()) AS week_of_year,      -- 20
    YEARWEEK(NOW()) AS year_week,           -- 202420
    DAYOFWEEK(NOW()) AS day_of_week,        -- 4 (1=Sunday, 7=Saturday)
    WEEKDAY(NOW()) AS weekday,              -- 2 (0=Monday, 6=Sunday)
    DAYNAME(NOW()) AS day_name,             -- Wednesday
    
    -- Year-related
    DAYOFYEAR(NOW()) AS day_of_year,        -- 136
    QUARTER(NOW()) AS quarter,              -- 2
    
    -- Time parts
    HOUR(NOW()) AS hour,                    -- 14
    MINUTE(NOW()) AS minute,                -- 30
    SECOND(NOW()) AS second,                -- 45
    MICROSECOND(NOW()) AS microseconds,     -- 0
    
    -- Combined extractions
    MONTHNAME(NOW()) AS month_name,         -- May
    LAST_DAY(NOW()) AS last_day_of_month;   -- 2024-05-31

-- EXTRACT function (SQL standard)
SELECT 
    EXTRACT(YEAR FROM NOW()) AS year,
    EXTRACT(MONTH FROM NOW()) AS month,
    EXTRACT(DAY FROM NOW()) AS day,
    EXTRACT(HOUR FROM NOW()) AS hour,
    EXTRACT(MINUTE FROM NOW()) AS minute,
    EXTRACT(SECOND FROM NOW()) AS second,
    EXTRACT(WEEK FROM NOW()) AS week,
    EXTRACT(QUARTER FROM NOW()) AS quarter;

-- ============================================================================
-- SECTION 3: DATE/TIME CONSTRUCTION
-- ============================================================================

SELECT 
    -- Make date from parts
    MAKEDATE(2024, 100) AS day_100,         -- 2024-04-09 (100th day of 2024)
    MAKETIME(14, 30, 45) AS time_made,      -- 14:30:45
    
    -- STR_TO_DATE: Parse string to date
    STR_TO_DATE('15-05-2024', '%d-%m-%Y') AS parsed_date,
    STR_TO_DATE('May 15, 2024', '%M %d, %Y') AS parsed_date2,
    STR_TO_DATE('15/05/24 2:30 PM', '%d/%m/%y %h:%i %p') AS parsed_datetime,
    
    -- Create timestamp
    TIMESTAMP('2024-05-15', '14:30:45') AS combined_timestamp,
    
    -- From components
    CONCAT(2024, '-', LPAD(5, 2, '0'), '-', LPAD(15, 2, '0')) AS constructed_date;

-- ============================================================================
-- SECTION 4: DATE/TIME FORMATTING
-- ============================================================================

/*
FORMAT SPECIFIERS:
%Y - 4-digit year     %y - 2-digit year
%M - Month name       %m - Month number (01-12)
%D - Day with suffix  %d - Day (01-31)
%H - Hour 24h         %h - Hour 12h
%i - Minutes          %s - Seconds
%p - AM/PM            %W - Weekday name
%a - Abbreviated day  %b - Abbreviated month
*/

SELECT 
    NOW() AS original,
    
    -- Common formats
    DATE_FORMAT(NOW(), '%Y-%m-%d') AS iso_date,           -- 2024-05-15
    DATE_FORMAT(NOW(), '%d/%m/%Y') AS uk_format,          -- 15/05/2024
    DATE_FORMAT(NOW(), '%m/%d/%Y') AS us_format,          -- 05/15/2024
    DATE_FORMAT(NOW(), '%d %M %Y') AS long_date,          -- 15 May 2024
    DATE_FORMAT(NOW(), '%W, %M %d, %Y') AS full_date,     -- Wednesday, May 15, 2024
    
    -- Time formats
    DATE_FORMAT(NOW(), '%H:%i:%s') AS time_24h,           -- 14:30:45
    DATE_FORMAT(NOW(), '%h:%i %p') AS time_12h,           -- 02:30 PM
    
    -- Combined
    DATE_FORMAT(NOW(), '%d %b %Y %H:%i') AS datetime_short, -- 15 May 2024 14:30
    
    -- Custom
    DATE_FORMAT(NOW(), 'Date: %d-%m-%Y | Time: %H:%i') AS custom;

-- TIME_FORMAT for time-only values
SELECT 
    TIME_FORMAT('14:30:45', '%h:%i %p') AS formatted_time;  -- 02:30 PM

-- ============================================================================
-- SECTION 5: DATE ARITHMETIC
-- ============================================================================

SELECT 
    CURDATE() AS today,
    
    -- Add/subtract intervals
    DATE_ADD(CURDATE(), INTERVAL 7 DAY) AS week_later,
    DATE_ADD(CURDATE(), INTERVAL 1 MONTH) AS month_later,
    DATE_ADD(CURDATE(), INTERVAL 1 YEAR) AS year_later,
    DATE_SUB(CURDATE(), INTERVAL 30 DAY) AS thirty_days_ago,
    
    -- Alternative syntax
    CURDATE() + INTERVAL 7 DAY AS plus_7_days,
    CURDATE() - INTERVAL 1 MONTH AS minus_1_month,
    
    -- Complex intervals
    DATE_ADD(NOW(), INTERVAL '1:30' HOUR_MINUTE) AS plus_1h30m,
    DATE_ADD(CURDATE(), INTERVAL '1-6' YEAR_MONTH) AS plus_1y6m,
    
    -- Add time
    ADDTIME(NOW(), '02:30:00') AS plus_2h30m,
    SUBTIME(NOW(), '01:00:00') AS minus_1h;

-- INTERVAL types available:
-- MICROSECOND, SECOND, MINUTE, HOUR, DAY, WEEK, MONTH, QUARTER, YEAR
-- SECOND_MICROSECOND, MINUTE_MICROSECOND, MINUTE_SECOND
-- HOUR_MICROSECOND, HOUR_SECOND, HOUR_MINUTE
-- DAY_MICROSECOND, DAY_SECOND, DAY_MINUTE, DAY_HOUR
-- YEAR_MONTH

-- ============================================================================
-- SECTION 6: DATE DIFFERENCES AND COMPARISONS
-- ============================================================================

SELECT 
    -- Date differences
    DATEDIFF('2024-12-31', '2024-01-01') AS days_in_year,    -- 365
    DATEDIFF(CURDATE(), '2024-01-01') AS days_since_jan1,
    
    -- Time differences
    TIMEDIFF('18:00:00', '09:00:00') AS work_hours,          -- 09:00:00
    TIMEDIFF(NOW(), DATE_SUB(NOW(), INTERVAL 3 HOUR)) AS hours_diff,
    
    -- Period differences (for YYYYMM format)
    PERIOD_DIFF(202412, 202401) AS months_diff,              -- 11
    
    -- Timestamp differences
    TIMESTAMPDIFF(YEAR, '2000-05-15', CURDATE()) AS age_years,
    TIMESTAMPDIFF(MONTH, '2024-01-01', CURDATE()) AS months_since,
    TIMESTAMPDIFF(DAY, '2024-01-01', CURDATE()) AS days_since,
    TIMESTAMPDIFF(HOUR, '2024-05-15 00:00:00', NOW()) AS hours_since;

-- Practical age calculation
SELECT 
    birth_date,
    TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) AS age,
    CASE 
        WHEN DATE_FORMAT(birth_date, '%m-%d') = DATE_FORMAT(CURDATE(), '%m-%d')
        THEN 'Birthday today!'
        WHEN DATE_FORMAT(birth_date, '%m-%d') > DATE_FORMAT(CURDATE(), '%m-%d')
        THEN CONCAT('Birthday in ', DATEDIFF(
            CONCAT(YEAR(CURDATE()), '-', DATE_FORMAT(birth_date, '%m-%d')),
            CURDATE()
        ), ' days')
        ELSE CONCAT('Birthday was ', DATEDIFF(
            CURDATE(),
            CONCAT(YEAR(CURDATE()), '-', DATE_FORMAT(birth_date, '%m-%d'))
        ), ' days ago')
    END AS birthday_status
FROM employees;

-- ============================================================================
-- SECTION 7: DATE ROUNDING AND TRUNCATION
-- ============================================================================

-- Get start/end of periods
SELECT 
    NOW() AS current,
    
    -- Start of current year
    DATE_FORMAT(NOW(), '%Y-01-01') AS year_start,
    MAKEDATE(YEAR(NOW()), 1) AS year_start_alt,
    
    -- Start of current month
    DATE_FORMAT(NOW(), '%Y-%m-01') AS month_start,
    DATE_SUB(CURDATE(), INTERVAL DAYOFMONTH(CURDATE()) - 1 DAY) AS month_start_alt,
    
    -- Start of current week (Monday)
    DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY) AS week_start_monday,
    
    -- Start of current week (Sunday)
    DATE_SUB(CURDATE(), INTERVAL DAYOFWEEK(CURDATE()) - 1 DAY) AS week_start_sunday,
    
    -- End of current month
    LAST_DAY(NOW()) AS month_end,
    
    -- End of current year
    DATE_FORMAT(NOW(), '%Y-12-31') AS year_end,
    
    -- Truncate time (get date only)
    DATE(NOW()) AS date_only,
    
    -- Truncate to hour
    DATE_FORMAT(NOW(), '%Y-%m-%d %H:00:00') AS hour_truncated;

-- ============================================================================
-- SECTION 8: TIME ZONES
-- ============================================================================

-- Get current timezone
SELECT @@global.time_zone, @@session.time_zone;

-- Convert between timezones
SELECT 
    NOW() AS local_time,
    CONVERT_TZ(NOW(), '+03:00', '+00:00') AS utc_time,      -- EAT to UTC
    CONVERT_TZ(NOW(), '+03:00', '-05:00') AS new_york_time, -- EAT to EST
    CONVERT_TZ(NOW(), 'Africa/Kampala', 'America/New_York') AS named_tz;

-- UTC functions
SELECT 
    UTC_DATE() AS utc_date,
    UTC_TIME() AS utc_time,
    UTC_TIMESTAMP() AS utc_timestamp;

-- ============================================================================
-- SECTION 9: PRACTICAL DATE SCENARIOS
-- ============================================================================

-- Scenario 1: Generate date series (for reports with all dates)
WITH RECURSIVE date_series AS (
    SELECT '2024-01-01' AS date
    UNION ALL
    SELECT DATE_ADD(date, INTERVAL 1 DAY)
    FROM date_series
    WHERE date < '2024-01-31'
)
SELECT date FROM date_series;

-- Scenario 2: Business days calculation (exclude weekends)
WITH RECURSIVE date_series AS (
    SELECT '2024-01-01' AS date
    UNION ALL
    SELECT DATE_ADD(date, INTERVAL 1 DAY)
    FROM date_series
    WHERE date < '2024-01-31'
)
SELECT 
    COUNT(*) AS total_days,
    SUM(CASE WHEN DAYOFWEEK(date) NOT IN (1, 7) THEN 1 ELSE 0 END) AS business_days,
    SUM(CASE WHEN DAYOFWEEK(date) IN (1, 7) THEN 1 ELSE 0 END) AS weekend_days
FROM date_series;

-- Scenario 3: Fiscal year calculations (July - June)
SELECT 
    order_date,
    CASE 
        WHEN MONTH(order_date) >= 7 THEN YEAR(order_date)
        ELSE YEAR(order_date) - 1
    END AS fiscal_year,
    CASE 
        WHEN MONTH(order_date) >= 7 THEN MONTH(order_date) - 6
        ELSE MONTH(order_date) + 6
    END AS fiscal_month,
    CEIL(
        CASE 
            WHEN MONTH(order_date) >= 7 THEN MONTH(order_date) - 6
            ELSE MONTH(order_date) + 6
        END / 3.0
    ) AS fiscal_quarter
FROM orders;

-- Scenario 4: Age groups
SELECT 
    customer_name,
    birth_date,
    TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) AS age,
    CASE 
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 18 THEN 'Minor'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 25 THEN 'Young Adult'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 35 THEN 'Adult'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 50 THEN 'Middle Age'
        WHEN TIMESTAMPDIFF(YEAR, birth_date, CURDATE()) < 65 THEN 'Senior'
        ELSE 'Elder'
    END AS age_group
FROM customers
WHERE birth_date IS NOT NULL;

-- Scenario 5: Tenure calculations
SELECT 
    employee_name,
    hire_date,
    TIMESTAMPDIFF(YEAR, hire_date, CURDATE()) AS years,
    TIMESTAMPDIFF(MONTH, hire_date, CURDATE()) % 12 AS months,
    CONCAT(
        TIMESTAMPDIFF(YEAR, hire_date, CURDATE()), ' years, ',
        TIMESTAMPDIFF(MONTH, hire_date, CURDATE()) % 12, ' months'
    ) AS tenure
FROM employees;

-- Scenario 6: Upcoming anniversaries (next 30 days)
SELECT 
    employee_name,
    hire_date,
    CONCAT(YEAR(CURDATE()), '-', DATE_FORMAT(hire_date, '%m-%d')) AS this_year_anniversary,
    DATEDIFF(
        CONCAT(YEAR(CURDATE()), '-', DATE_FORMAT(hire_date, '%m-%d')),
        CURDATE()
    ) AS days_until
FROM employees
WHERE DATEDIFF(
    CONCAT(YEAR(CURDATE()), '-', DATE_FORMAT(hire_date, '%m-%d')),
    CURDATE()
) BETWEEN 0 AND 30;

-- Scenario 7: Monthly reporting periods
SELECT 
    DATE_FORMAT(sale_date, '%Y-%m') AS month,
    DATE_FORMAT(MIN(sale_date), '%Y-%m-%d') AS first_sale,
    DATE_FORMAT(MAX(sale_date), '%Y-%m-%d') AS last_sale,
    COUNT(*) AS total_sales,
    SUM(amount) AS total_amount
FROM sales
GROUP BY DATE_FORMAT(sale_date, '%Y-%m')
ORDER BY month;

-- Scenario 8: Same day last year comparison
SELECT 
    s1.sale_date,
    s1.total_amount AS this_year,
    s2.total_amount AS last_year,
    s1.total_amount - COALESCE(s2.total_amount, 0) AS difference
FROM (
    SELECT sale_date, SUM(amount) AS total_amount
    FROM sales
    WHERE YEAR(sale_date) = YEAR(CURDATE())
    GROUP BY sale_date
) s1
LEFT JOIN (
    SELECT sale_date, SUM(amount) AS total_amount
    FROM sales
    WHERE YEAR(sale_date) = YEAR(CURDATE()) - 1
    GROUP BY sale_date
) s2 ON DATE_FORMAT(s1.sale_date, '%m-%d') = DATE_FORMAT(s2.sale_date, '%m-%d');

-- ============================================================================
-- SECTION 10: DATE VALIDATION AND EDGE CASES
-- ============================================================================

-- Validate date strings
SELECT 
    '2024-02-29' AS date_str,
    STR_TO_DATE('2024-02-29', '%Y-%m-%d') AS parsed,  -- Valid (leap year)
    STR_TO_DATE('2023-02-29', '%Y-%m-%d') AS invalid; -- Returns NULL (not leap year)

-- Check if year is leap year
SELECT 
    year,
    CASE 
        WHEN (year % 4 = 0 AND year % 100 != 0) OR (year % 400 = 0) 
        THEN 'Leap Year'
        ELSE 'Not Leap Year'
    END AS leap_year_status
FROM (
    SELECT 2020 AS year UNION SELECT 2023 UNION SELECT 2024 UNION SELECT 2100
) years;

-- Handle NULL dates
SELECT 
    COALESCE(order_date, CURDATE()) AS effective_date,
    IFNULL(shipped_date, 'Not Shipped') AS ship_status
FROM orders;

-- ============================================================================
-- PRACTICE EXERCISES
-- ============================================================================

/*
EXERCISE 1: Date extraction and formatting
a) Show orders with formatted date as "Mon, 15 May 2024"
b) Extract fiscal quarter (July-June fiscal year) for each sale
c) Show orders grouped by day of week with day names
d) Format datetime as "15-May-24 2:30 PM"

EXERCISE 2: Date arithmetic
a) Find orders placed in the last 7 days
b) Calculate employee age in years and months
c) Find orders due in the next 14 days
d) Add 45 business days to a date (exclude weekends)

EXERCISE 3: Date comparisons and ranges
a) Find same-month sales comparison (this month vs last month)
b) Show year-to-date sales by month with running total
c) Find customers who haven't ordered in 90+ days
d) Calculate average days between orders per customer

EXERCISE 4: Time analysis
a) Find peak sales hours (by hour of day)
b) Calculate average response time between order and shipment
c) Find orders placed outside business hours (9 AM - 6 PM)
d) Show sales by time of day (Morning, Afternoon, Evening, Night)

EXERCISE 5: Advanced scenarios
a) Generate a calendar table for the current year
b) Calculate business days between two dates (exclude weekends and holidays)
c) Find employees with anniversary in current month
d) Show month-over-month growth percentage

Write your solutions below:
*/

-- YOUR SOLUTIONS HERE:

