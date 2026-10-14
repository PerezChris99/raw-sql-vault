# SQL Curriculum Supplement — Beginner to Practitioner

This supplements, rather than replaces, the existing practice lessons. Work against synthetic data on the stated database engine.

## Module 1 — Foundations and mental models

A database is an organised collection of data; a DBMS stores and manages it; SQL declares queries and data changes. Tables describe relations, rows describe records, and columns describe attributes. Learn keys and relationships before complex reporting.

Exercise: draw customer → order → order_items and explain the primary and foreign keys.

## Module 2 — NULL and three-valued logic

NULL means unknown, missing or not applicable. Comparisons with NULL evaluate to UNKNOWN. Use IS NULL, IS NOT NULL, COALESCE, NULLIF and, in PostgreSQL, IS DISTINCT FROM where appropriate. Watch NOT IN subqueries that may return NULL.

Exercise: create a row with no phone number and retrieve it. Explain why it differs from an empty string or zero.

## Module 3 — Keys and relationships

Distinguish candidate keys, primary keys, surrogate keys, unique constraints and foreign keys. Understand 1:1, 1:N and M:N cardinality; represent many-to-many relationships with a junction table. Choose delete rules intentionally.

Exercise: make an order-item table with a composite key and positive quantity check.

## Module 4 — Normalisation

- 1NF: represent each value at the chosen level of meaning.
- 2NF: non-key attributes depend on the whole candidate key, not part of a composite key.
- 3NF: non-key attributes do not depend transitively on the key through another non-key attribute.
- BCNF: each determinant of a non-trivial functional dependency is a candidate key.

Normalisation reduces duplicate facts and update anomalies. Denormalise only when measurement justifies the consistency cost.

## Module 5 — Joins and set logic

Learn INNER, LEFT, RIGHT, FULL, CROSS and self joins; then anti-joins with NOT EXISTS, semi-joins with EXISTS, subqueries, CTEs and set operations. Understand how a filter in WHERE can remove unmatched rows preserved by a LEFT JOIN.

Exercise: return every customer, including those with zero orders; count a nullable right-side key rather than COUNT(*).

## Module 6 — Transactions and concurrency

Understand ACID, commit/rollback, isolation levels, locks, deadlocks, lost updates, retries and idempotency. Learn SELECT FOR UPDATE and when it is appropriate. A transaction does not make incorrect business logic correct.

Exercise: create a stock-movement function that refuses an outgoing movement when it would make the balance negative.

## Module 7 — Dialect boundaries

| Feature | PostgreSQL 15+ | MySQL 8 | SQL Server 2019 |
|---|---|---|---|
| Boolean | native boolean | commonly TINYINT(1) | BIT |
| Upsert | ON CONFLICT | ON DUPLICATE KEY UPDATE | MERGE or a reviewed transactional pattern |
| Pagination | LIMIT/OFFSET or cursor | LIMIT/OFFSET | OFFSET/FETCH or cursor |
| JSON | json/jsonb | JSON | JSON functions over text |
| Identity | GENERATED AS IDENTITY | AUTO_INCREMENT | IDENTITY |

This is not an exhaustive compatibility matrix. Test variants on the declared engine/version.

## Module 8 — Secure application queries

Bind values through the actual database driver. Do not concatenate SQL strings. Values can be parameterized; identifiers require allow-listing and safe quoting. Use least-privilege roles, rotate exposed credentials, and never put secrets or real personal data in Git.

## Module 9 — Testing and operational discipline

Learn migration ordering, clean installs, upgrades, regression assertions, synthetic fixtures, query-plan measurement, backup/restore drills, monitoring and incident runbooks.

Mastery check: predict the output, run the query, test NULL/duplicates/boundaries/permissions, and add an assertion before calling a lesson complete.

## Recommended order

1. Existing practice/00_getting_started/
2. This supplement, Modules 1–5
3. Existing practice/01_fundamentals/ and practice/02_intermediate/
4. This supplement, Modules 6–9
5. Existing advanced lessons
6. Run tools/run_sql_tests.sh against a dedicated PostgreSQL 15+ / PostGIS test database
7. Build one documented domain package at a time per docs/ROADMAP.md