-- ============================================================================
--                     SQL MASTERY VAULT - UGANDA EDITION
--                         LEARNING PATH & GUIDE
-- ============================================================================

/*
 ██████╗ ██████╗ ██╗         ██╗   ██╗ █████╗ ██╗   ██╗██╗  ████████╗
██╔════╝██╔═══██╗██║         ██║   ██║██╔══██╗██║   ██║██║  ╚══██╔══╝
███████╗██║   ██║██║         ██║   ██║███████║██║   ██║██║     ██║   
╚════██║██║▄▄ ██║██║         ╚██╗ ██╔╝██╔══██║██║   ██║██║     ██║   
███████║╚██████╔╝███████╗     ╚████╔╝ ██║  ██║╚██████╔╝███████╗██║   
╚══════╝ ╚══▀▀═╝ ╚══════╝      ╚═══╝  ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝   

Your Journey to Becoming the Best SQL Programmer in Uganda Starts Here!
*/

-- ============================================================================
-- WHAT'S INSIDE THIS VAULT
-- ============================================================================

/*
This vault contains comprehensive SQL learning materials organized into
progressive difficulty levels. Each module includes:
- Detailed explanations in comments
- Working code examples
- Uganda-specific context (UGX currency, local names, districts)
- Practice exercises
- Best practices and tips

FOLDER STRUCTURE:
================

📁 practice/
├── 📁 00_getting_started/
│   ├── 01_sql_basics.sql           ← SELECT, INSERT, UPDATE, DELETE basics
│   ├── 02_data_types.sql           ← All SQL data types explained
│   └── 03_constraints.sql          ← PRIMARY KEY, FOREIGN KEY, UNIQUE, etc.
│
├── 📁 01_fundamentals/
│   ├── 01_joins_complete.sql       ← All JOIN types with examples
│   ├── 02_aggregation_groupby.sql  ← COUNT, SUM, GROUP BY, HAVING
│   ├── 03_subqueries_ctes.sql      ← Subqueries and Common Table Expressions
│   └── 04_set_operations.sql       ← UNION, INTERSECT, EXCEPT
│
├── 📁 02_intermediate/
│   ├── 01_window_functions.sql     ← ROW_NUMBER, RANK, LAG, LEAD, etc.
│   ├── 02_string_functions.sql     ← Text manipulation mastery
│   ├── 03_date_time_functions.sql  ← Date/time operations
│   └── 04_conditional_logic.sql    ← CASE, IF, COALESCE, NULL handling
│
├── 📁 03_advanced/
│   ├── 01_views.sql                ← Virtual tables and data abstraction
│   ├── 02_stored_procedures.sql    ← Procedural SQL programming
│   ├── 03_triggers.sql             ← Automated database actions
│   ├── 04_transactions.sql         ← ACID, locks, concurrency
│   ├── 05_performance_optimization.sql ← Query tuning and indexing
│   ├── 06_security_permissions.sql ← Users, roles, SQL injection prevention
│   ├── 07_json_data.sql            ← JSON and semi-structured data
│   ├── 08_recursive_queries.sql    ← Hierarchical data processing
│   └── 09_database_administration.sql ← Backup, recovery, maintenance
│
└── 📁 04_exercises/
    ├── 01_comprehensive_exercises.sql ← 50+ exercises with solutions
    ├── 02_sql_cheat_sheet.sql         ← Quick reference for all SQL
    └── 03_real_world_projects.sql     ← Business scenarios & analytics

*/

-- ============================================================================
-- RECOMMENDED LEARNING PATH
-- ============================================================================

/*
WEEK 1-2: FOUNDATIONS
---------------------
□ Complete all files in 00_getting_started/
□ Practice basic SELECT, INSERT, UPDATE, DELETE
□ Understand data types and when to use them
□ Learn constraints for data integrity

WEEK 3-4: CORE SQL SKILLS
-------------------------
□ Master all JOIN types (01_fundamentals/01_joins_complete.sql)
□ Learn aggregation and grouping
□ Understand subqueries and CTEs
□ Practice set operations

WEEK 5-6: INTERMEDIATE TECHNIQUES
---------------------------------
□ Dive into window functions (game-changer for analytics!)
□ Master string and date manipulation
□ Perfect conditional logic

WEEK 7-8: ADVANCED SKILLS
-------------------------
□ Learn views for data abstraction
□ Create stored procedures for automation
□ Understand triggers for event handling
□ Master transactions for data integrity

WEEK 9-10: EXPERT LEVEL
-----------------------
□ Performance optimization and indexing
□ Security and access control
□ JSON data handling
□ Recursive queries for hierarchical data
□ Database administration basics

WEEK 11-12: PRACTICE & PROJECTS
-------------------------------
□ Complete all exercises in 04_exercises/
□ Build real-world projects
□ Create your own database designs
□ Keep the cheat sheet handy!

*/

-- ============================================================================
-- HOW TO USE THIS VAULT
-- ============================================================================

/*
1. SETUP YOUR ENVIRONMENT
   - Install MySQL, PostgreSQL, or use online SQL editors
   - Recommended: MySQL Workbench, DBeaver, or VS Code with SQL extensions

2. FOLLOW THE ORDER
   - Start with 00_getting_started, then progress through the folders
   - Each module builds on previous knowledge

3. RUN THE CODE
   - Every SQL statement in these files is runnable
   - Copy-paste into your SQL environment and execute

4. DO THE EXERCISES
   - Don't skip practice exercises at the end of each module
   - Try solving before looking at solutions

5. BUILD PROJECTS
   - Use 03_real_world_projects.sql for inspiration
   - Create your own databases for topics you care about

6. REFER BACK
   - Keep 02_sql_cheat_sheet.sql as your quick reference
   - Revisit modules when you need to refresh

*/

-- ============================================================================
-- TIPS FOR SUCCESS
-- ============================================================================

/*
1. PRACTICE DAILY
   Even 30 minutes of SQL practice daily beats 5 hours once a week.

2. TYPE THE CODE
   Don't copy-paste when learning. Typing helps memory.

3. BREAK THINGS
   Experiment! Change the queries, see what happens.

4. UNDERSTAND, DON'T MEMORIZE
   Focus on understanding WHY, not just HOW.

5. WORK ON REAL DATA
   Apply SQL to data you care about (your business, hobby, etc.)

6. JOIN COMMUNITIES
   - Stack Overflow
   - Reddit r/SQL
   - Local tech meetups in Uganda
   - LinkedIn SQL groups

7. BUILD A PORTFOLIO
   Document your learning journey and projects.

*/

-- ============================================================================
-- DATABASES USED IN EXAMPLES
-- ============================================================================

/*
Examples use these scenario databases:

1. SHOP DATABASE (E-commerce)
   - customers, products, orders, order_items
   - employees, categories, suppliers

2. BANK DATABASE (Financial)
   - accounts, transactions, loans
   - customers, branches

3. ORGANIZATION DATABASE (HR)
   - employees, departments, salaries
   - manager hierarchies

All examples use Uganda-specific context:
- Currency: UGX (Uganda Shillings)
- Names: Common Ugandan names
- Locations: Ugandan districts and cities
- Business context: East African scenarios

*/

-- ============================================================================
-- QUICK START - YOUR FIRST QUERY
-- ============================================================================

-- Welcome! Start by running these simple queries:

-- 1. Your first SELECT
SELECT 'Hello, Uganda! Welcome to SQL!' AS greeting;

-- 2. Basic math
SELECT 1500000 * 0.18 AS vat_on_item;

-- 3. Current date and time
SELECT NOW() AS current_timestamp, CURDATE() AS today;

-- 4. Simple calculation
SELECT 
    'Monthly Salary' AS description,
    2500000 AS gross_salary_ugx,
    2500000 * 0.30 AS paye_tax,
    2500000 * 0.05 AS nssf_contribution,
    2500000 - (2500000 * 0.30) - (2500000 * 0.05) AS net_salary;

-- Now you're ready! Head to 00_getting_started/01_sql_basics.sql

-- ============================================================================
-- GOOD LUCK ON YOUR SQL JOURNEY!
-- ============================================================================

/*
Remember: Every expert was once a beginner.

"The best time to learn SQL was 10 years ago. 
The second best time is now."

Go make Uganda proud! 🇺🇬

Created with ❤️ for aspiring SQL programmers in Uganda
*/

