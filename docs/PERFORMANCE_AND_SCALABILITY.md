# Performance and Scalability Engineering

**Principle:** measure the target workload. No universal index or configuration guarantees zero slowdown or zero crashes.

## Workload assumptions
For each critical workflow document expected/max rows, read/write ratio, bursts, concurrency, transaction duration, freshness, latency percentiles, throughput, retention, growth, and resource limits. Targets are deployment decisions, not generic promises.

## Query analysis
1. Use representative synthetic data including skew and edge cases.
2. Refresh planner statistics as appropriate.
3. Capture EXPLAIN (ANALYZE, BUFFERS) in a safe test environment.
4. Review estimated/actual rows, scans, joins, sorts/hashes, buffer use, loops, and filtered rows.
5. Compare repeated runs and distinguish warm-cache from cold-cache behaviour.
6. Change one factor at a time and record environment and results.
7. Remember EXPLAIN ANALYZE executes the statement; mutating statements need a rollback-safe test design.

## Index discipline
Index based on actual predicates, joins, ordering, uniqueness, and measured plans. Evaluate composite-column order, selectivity, partial/expression/covering indexes where supported, write amplification, storage, vacuum work, and cache pressure. Avoid redundant or unused indexes. Do not assume every index improves every workload.

## Query and schema practice
Bound result sets, use stable pagination, project only needed columns, use suitable types, and review expensive recursion and fan-out. Normalisation protects integrity; denormalisation requires a documented source of truth, refresh strategy, and reconciliation.

## Concurrency and availability
Test lock contention, deadlocks, serialization failures, retries, duplicate delivery, long transactions, connection exhaustion, and partial failure. Set workload-appropriate timeouts. Retry only known retryable errors and make side effects idempotent. Advisory locks do not replace unique constraints and transactional invariants.

## Capacity and observability
Evaluate pooling, replicas, partitioning, archival, vacuum/autovacuum, replication lag, failover, storage, and backup load only against measured need. Partitioning adds complexity; replicas may be stale and do not remove write bottlenecks. Monitor latency, throughput, errors, saturation, connections, locks, deadlocks, growth, replication, and recovery health.

Record baseline/candidate results, environment, query plan, correctness results, trade-offs, thresholds, and reviewer. If not measured, state “not measured.” This guide does not claim every query is profiled or load-tested.
