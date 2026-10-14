# SQL Example Audit Notes

This document tracks correctness and teaching-quality checks discovered while reviewing the entry guide and selected examples. It is a review checklist, not a claim that every SQL file in the repository has been executed.

## Confirmed review targets

1. **Dialect clarity:** The vault names PostgreSQL as the primary database, but `practice/04_exercises/03_real_world_projects.sql` contains MySQL-specific syntax such as `USE`, `CURDATE()`, `DATE_SUB()`, `YEARWEEK()`, `DATE_FORMAT()`, and `WITH ROLLUP`. Add an engine/version header to each file and provide equivalents where portability is a learning goal.
2. **Sales metric consistency:** The sales overview starts with a filtered `daily_sales` CTE, but the displayed scalar subqueries do not use it and do not consistently filter order statuses. Define whether each metric means booked, shipped, or completed sales, and apply the same definition throughout.
3. **Monthly top-product denominator:** The numerator filters by month but not year, and the denominator has the same missing year constraint. Use `order_date >= month_start AND order_date < next_month_start`, bind those dates once, and apply the same status policy to numerator and denominator.
4. **Product movement date logic:** The 30-day order filter appears in a LEFT JOIN condition, which preserves products without recent sales as intended, but `MIN(o.order_date)` must be understood as the minimum of the filtered joined rows and the query must avoid dividing by zero. Include all nonaggregated selected columns in GROUP BY according to the target engine.
5. **RFM scoring:** A customer with no orders has NULL recency. Define a deliberate no-purchase segment before applying NTILE; document recency direction so that the best recency receives the highest score.
6. **Boda accident quartiles:** Use a CTE to aggregate accident counts first, then apply `NTILE(4) OVER (ORDER BY accident_count)`. Decide whether larger counts mean higher risk and name the quartiles accordingly. Verify target-dialect support.
7. **Fishery quota window:** `ROWS 30 PRECEDING` means up to 31 rows including the current row, not 30 calendar days. The current partitioning by month alone also mixes fishers unless fisher/species are included. Define quota period, entity, species, date ties, and whether the rule is rolling rows or rolling calendar days.
8. **Tea price median:** `PERCENTILE_CONT` ordered-set/window syntax is dialect-specific. State the target engine and test the exact syntax; also define comparisons by grade, date window, unit, and sample size.
9. **Land parcel overlaps:** Comparing every pair can return each overlap twice. Use a stable pair condition such as `p1.id < p2.id`, filter invalid/empty geometries, and use the correct spatial predicate for the question. Intersecting geometries is a review signal, not proof of legal ownership or a final dispute decision.
10. **Batch inserts in database discipline:** A procedure using `LIMIT` without deterministic ordering or a robust claim/marking strategy can reprocess rows or behave unpredictably under concurrent workers. `SLEEP` does not make it safe. Demonstrate transaction boundaries, stable keys, idempotency, error handling, worker coordination, and checkpointing before presenting a production batch pattern.
11. **Index recommendations:** Do not promise that an index or EXISTS is always faster. Compare actual plans, representative row counts, write overhead, and workload.
12. **Salary/tax arithmetic:** Treat the entry guide's percentages as arbitrary arithmetic only. Do not present them as current Uganda PAYE/NSSF rules. For a real payroll project, link to authoritative current guidance and obtain qualified review.
13. **Runnable claims:** The learning guide says every statement is runnable, but many examples assume a particular schema/database, use engine-specific syntax, or are intentionally illustrative. Mark prerequisites and expected output and separate executable labs from pseudocode/placeholders.

## Standard for resolving a finding

For each issue: reproduce on the declared engine/version, create a focused correction, add an explanatory comment and regression case, run the relevant checks, inspect the diff, and submit a pull request. Do not mass-rewrite dialects or project schemas without verifying downstream dependencies.
