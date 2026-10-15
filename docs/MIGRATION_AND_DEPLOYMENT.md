# Migration and Deployment Safety

## Deployment principle
Treat versioned migrations as authoritative schema history. Instructional numbered SQL files may be useful for learning or demonstrations, but each package must state which entry point is authoritative. Avoid conflicting schema definitions.

## Before deployment
Confirm engine/version, extensions, collation, timezone, encoding, privileges, and settings. Inspect destructive/data-transforming statements. Do not run application traffic as a superuser. Estimate locks, table rewrites, backfills, disk use, replication impact, and compatibility. Test against representative staging data, verify backups/recovery, and define stop conditions and accountable operators.

## Immutable history
Once a migration has been applied in a shared environment, do not rewrite its historical meaning. Correct defects with a forward migration. Reconcile actual schema state before applying fixes to an environment with uncertain migration history.

## Expand, migrate, contract
For changes needing low downtime, consider a staged process: add backward-compatible structures; deploy code that supports old/new shapes; backfill in bounded batches; validate counts and constraints; switch reads/writes after compatibility is proven; remove old structures only in a later release after rollback no longer depends on them.

## Locks and transactions
Review DDL transaction support, lock levels/duration, statement/lock timeouts, long transactions, and replication lag. Do not assume a migration is non-blocking because it is quick on a small development database. Large backfills may need checkpoints and bounded transactions.

## Data migration controls
Use deterministic mappings, explicit NULL/invalid/orphan handling, reconciliation, duplicate detection, resumable batches, and owner approval for destructive changes. Test recovery on disposable data.

## Rollback versus roll-forward
A down migration may not restore deleted data or external side effects. Document whether a change is reversible, needs a forward fix, or needs restore. Test recovery for destructive operations.

## Post-deployment
Check migration version, constraints, grants, RLS, representative reads/writes, row counts, errors, locks, plans, storage, replication, and maintenance. Define stop criteria before rollout. This guidance does not prove every migration has been tested on every engine or at production scale.
