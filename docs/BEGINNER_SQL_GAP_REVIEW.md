# Raw SQL Vault: Beginner-First Gap Audit and Learning Supplements

## Why this supplement exists

The vault already contains substantial SQL material: foundations, joins, aggregation, subqueries/CTEs, set operations, window functions, date/string functions, conditional logic, views, routines, triggers, transactions, performance, security, JSON, recursion, administration, and database discipline. Do not replace those modules or assume every topic is missing.

This supplement addresses learning and engineering gaps visible from the current entry guide and selected examples: a true zero-assumption path, consistent dialect labeling, data-modelling before query complexity, NULL/three-valued logic, repeatable exercises, safe application integration, migration/testing/operations practices, and careful validation of examples that currently claim to be universally runnable.

## 1. First principles — assume you have never seen a database

A **database** is an organised collection of data. A **database management system (DBMS)** is software that stores, protects, queries, and changes that data. SQL is the language used to describe many of those operations.

A **table** is similar to a spreadsheet with defined columns. A **row** is one stored record. A **column** describes one property. A **schema** groups database objects. A **query** asks the database a question.

Imagine a shop in Kampala:

| customer_id | customer_name | district |
|---:|---|---|
| 1 | Amina | Wakiso |
| 2 | Daniel | Gulu |

The ID identifies a customer. The name and district describe that customer. An order should reference the customer's ID rather than copying the customer's name into every order row.

### Your first query

```sql
SELECT 'Hello, Uganda!' AS message;
```

Read it left to right:
- `SELECT` asks the database to return a result.
- The quoted text is a string value.
- `AS message` names the output column.
- The semicolon ends the statement.

Now try:

```sql
SELECT 1500000 * 0.18 AS illustrative_amount;
SELECT 'UGX' AS currency_code, 1500000 AS amount;
```

The arithmetic is an illustration, not tax advice or a statement of current Ugandan tax rules.

## 2. Understand the four basic SQL jobs

- **Read data:** `SELECT`
- **Add data:** `INSERT`
- **Change data:** `UPDATE`
- **Remove data:** `DELETE`

Structure is managed with commands such as `CREATE TABLE` and `ALTER TABLE`. Permissions and transaction commands have their own syntax and vary by engine.

```sql
CREATE TABLE learners (
    learner_id INTEGER PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(254) UNIQUE
);

INSERT INTO learners (learner_id, full_name, email)
VALUES (1, 'Amina Nansubuga', 'amina@example.test');

SELECT learner_id, full_name
FROM learners
WHERE learner_id = 1;
```

This uses broadly familiar SQL syntax; exact identity/auto-number syntax differs across PostgreSQL, MySQL, SQL Server, and SQLite. The `.test` email domain is reserved for examples.

## 3. Data types and NULL — do not skip these

A data type constrains what a column represents. Use numeric types for quantities and exact financial amounts, date/time types for dates and instants, and text for labels. Do not store money as formatted strings such as `'UGX 1,500,000'`; store the amount and currency separately.

`NULL` means unknown, missing, or not applicable; it is not zero, an empty string, or false. SQL uses three-valued logic: true, false, and unknown.

```sql
SELECT learner_id, full_name
FROM learners
WHERE email IS NULL;
```

Do not write `email = NULL`. Use `IS NULL`. Be careful with `NOT IN` if its subquery can return NULL; `NOT EXISTS` is often a clearer anti-join.

**Exercise:** Make a table with a nullable phone number. Insert one row with a number and one without. Query only the missing numbers. Explain why the two rows are still different records.

## 4. Keys, relationships, and normalisation before advanced queries

A **primary key** identifies a row. A **foreign key** requires a referenced row to exist. A **unique constraint** prevents duplicate values. A **check constraint** rejects values that violate a rule.

One customer can place many orders (one-to-many). Orders can contain many products, and a product can appear in many orders (many-to-many); represent this with an order-items junction table.

```sql
CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL
);

CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
    ordered_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    order_id INTEGER NOT NULL REFERENCES orders(order_id),
    line_number INTEGER NOT NULL,
    product_name VARCHAR(160) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(14,2) NOT NULL CHECK (unit_price >= 0),
    PRIMARY KEY (order_id, line_number)
);
```

The schema above is illustrative. Choose engine-appropriate timestamp, identity, and decimal definitions before deploying.

Normalisation reduces duplicate facts and update anomalies:
- **1NF:** each field stores one value at the chosen level of meaning; rows can be uniquely identified.
- **2NF:** non-key attributes depend on the whole candidate key, not only part of a composite key.
- **3NF:** non-key attributes do not depend transitively on a key through another non-key attribute.

Normalisation is not a contest to maximise table count. Model the facts correctly first; denormalise only for a measured reason and with a plan to maintain consistency.

**Exercise:** Explain why customer email should not be copied into every order. Draw customers → orders → order_items and identify each primary and foreign key.

## 5. Filtering, ordering, grouping, and joins

Learn in this order:
1. `WHERE` filters rows before grouping.
2. `ORDER BY` sorts output; add a unique tie-breaker for stable pagination.
3. `GROUP BY` makes groups; aggregates such as `COUNT` and `SUM` calculate over them.
4. `HAVING` filters groups after aggregation.
5. Joins combine related tables.

```sql
SELECT c.customer_id, c.full_name, COUNT(o.order_id) AS order_count
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name
ORDER BY order_count DESC, c.customer_id;
```

A LEFT JOIN retains customers who have no orders. Counting `o.order_id` returns zero for those customers; `COUNT(*)` would count the retained joined row and return one. Putting a right-table filter in `WHERE` can accidentally remove unmatched rows and make the query behave like an inner join.

## 6. Transactions and safe changes

A transaction groups changes into one logical unit. `COMMIT` makes them durable; `ROLLBACK` discards uncommitted work where supported.

```sql
BEGIN;
UPDATE inventory
SET quantity = quantity - 1
WHERE product_id = 10 AND quantity > 0;
-- Inspect the affected-row count in the client/application.
-- Commit only if exactly one intended row changed; otherwise roll back.
COMMIT;
```

Do not copy this fragment as a complete inventory checkout implementation. Real code must check affected rows, handle errors, account for concurrent transactions, and commit or roll back in application control flow. Syntax and transaction behaviour vary by engine and client.

Before a risky update or delete, run the matching SELECT first, check the expected row count, take an appropriate backup/snapshot when needed, and use a tested transaction or migration. Never run destructive examples against production.

## 7. SQL dialects: label the engine before running code

The vault describes PostgreSQL as its primary database while many practice files use MySQL syntax. Both are valid engines, but a single file should not imply all statements work everywhere.

| Feature | MySQL-style example | PostgreSQL-style equivalent |
|---|---|---|
| Current date | `CURDATE()` | `CURRENT_DATE` |
| Add one day | `DATE_ADD(d, INTERVAL 1 DAY)` | `d + INTERVAL '1 day'` |
| Limit rows | `LIMIT 10` | `LIMIT 10` |
| Auto-generated integer | `AUTO_INCREMENT` | identity column, e.g. `GENERATED BY DEFAULT AS IDENTITY` |
| Upsert | `ON DUPLICATE KEY UPDATE` | `ON CONFLICT (...) DO UPDATE` |
| Explain plan | `EXPLAIN` / MySQL-specific formats | `EXPLAIN` / `EXPLAIN (ANALYZE, BUFFERS)` |

These are examples, not a complete compatibility matrix. SQL Server and SQLite have their own differences too. Mark every code sample with its target engine/version and extension requirements; test it on that engine.

## 8. Important concepts to add to the study checklist

Some are touched on in advanced files but deserve explicit lessons and exercises:
- Entity-relationship modelling, cardinality, optionality, keys, functional dependencies, and normal forms.
- Three-valued logic, NULL pitfalls, collation, character sets, Unicode, and case sensitivity.
- Constraints as data-integrity guarantees and the trade-offs of cascading deletes.
- Safe parameterised queries, allow-listing dynamic identifiers, and least-privilege runtime roles.
- Isolation levels, row locks, deadlocks, optimistic concurrency, idempotency, and retry safety.
- Schema migrations, migration ordering, forward fixes, clean-install and upgrade tests.
- Unit/integration tests, deterministic fixtures, test isolation, and regression tests.
- Backups, restore drills, point-in-time recovery, RPO/RTO, and disaster-recovery runbooks.
- Observability: slow queries, lock waits, connection saturation, replication lag, storage, and alerting.
- Import pipelines, staging tables, reconciliation, data lineage, quality checks, and change data capture.
- Pagination under concurrent writes, time zones, daylight-saving assumptions, and timestamp semantics.
- Privacy by design, data minimisation, retention, anonymisation, export control, and audit trails.
- Analytical modelling: fact/dimension tables, star schemas, slowly changing dimensions, and OLTP/OLAP separation.
- Replication, pooling, partitioning, high availability, capacity planning, and explicit trade-offs.
- Accessibility and operational design for low-bandwidth and intermittent-connectivity environments.

## 9. Safe database application integration

Never concatenate user input into SQL text.

Python illustration (placeholder syntax depends on the driver):

```python
cursor.execute(
    "SELECT learner_id, full_name FROM learners WHERE email = %s",
    (email,),
)
```

Use the placeholder format documented by the actual driver. For example, SQLite commonly uses `?`, while psycopg uses `%s` for values. Values can be bound; table/column identifiers usually cannot, so dynamic identifiers must come from a strict allow-list and be quoted using driver/engine facilities.

The database connection should use a restricted application role, not an administrator account. Keep secrets out of Git, logs, error messages, screenshots, and test fixtures.

## 10. Practical learning loop

For every module:
1. Read the explanation and define every new word in your own language.
2. Predict the output before running the query.
3. Run it against synthetic data on the stated database engine.
4. Change one condition and explain how the result changes.
5. Test empty input, duplicates, NULL, invalid values, and boundary cases.
6. Write an exercise without looking at the solution.
7. Commit the work on a focused branch and open a pull request.

A module is not complete merely because its SQL parses. The expected results, assumptions, safety properties, and engine version must also be clear.

## 11. Review findings from the current material

These are concrete issues to review as the vault is expanded; do not treat the whole repository as broken:
- The entry guide says every statement is runnable, but examples include engine-specific syntax and assume particular databases/tables. State setup prerequisites and dialect per file.
- In the sample salary calculation, PAYE/NSSF percentages are illustrative placeholders. Clearly label them as non-authoritative arithmetic, not Uganda payroll guidance.
- In the real-world exercises, the sales overview defines a filtered CTE but its scalar subqueries do not consistently apply the same order-status filter. Align metric definitions and filters.
- In the top-products query, the monthly revenue denominator filters by month but does not constrain the year; use a half-open date range for the current month and use the same completed-order definition as the numerator.
- In the product movement query, the 30-day filter is in the LEFT JOIN condition, but the query's `MIN(o.order_date)` / day calculation needs to be based on the filtered sales and handle no-sales products deliberately.
- In the RFM example, recency scoring direction and customers with no orders need explicit treatment; NULL recency should not silently distort NTILE scores.
- In the boda accident sample, confirm the target dialect supports window functions over grouped aggregates as written and use a CTE for clarity/compatibility.
- In the fishery sample, `ROWS 30 PRECEDING` means up to 31 rows including the current row, not 30 calendar days; define whether the rule is row-based or date-based and partition by the correct quota period and fisher/species.
- In the tea price sample, ordered-set aggregate/window syntax is dialect-specific; test it against the declared engine.
- In the land parcel example, use a canonical pair condition (e.g. `p1.id < p2.id`) to avoid duplicate pairs and self-pairs, and document that geometry intersection does not itself resolve ownership.
- In the database-discipline file, the illustrative batch procedure must not be presented as generally safe: `LIMIT` without deterministic ordering/claiming, repeated selection of unprocessed rows, transaction boundaries, concurrent workers, and schema assumptions need to be handled. A pause alone does not make a bulk job safe.
- Indexing advice should be phrased as a hypothesis to measure, not an absolute guarantee. Indexes add storage and write costs; confirm plans and real workload.

## 12. Definition of done for a lesson

- Beginner-friendly definitions and a worked example.
- Declared engine/version, schema prerequisites, and extension requirements.
- Expected output or a clear way to verify it.
- Exercises with solutions separated from prompts.
- Edge cases: NULL, duplicates, empty sets, invalid values, and concurrency when relevant.
- Security and destructive-operation warnings where relevant.
- Links to the next lesson and prerequisite lessons.
