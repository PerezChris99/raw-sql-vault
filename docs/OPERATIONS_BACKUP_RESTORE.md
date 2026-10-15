# Operations: Backup, Restore, and Recovery

This document describes reusable PostgreSQL logical-backup tooling. It does not certify a deployment until an isolated restore drill and application-level checks succeed.

## Recovery objectives

Set deployment-specific recovery-point objective (RPO), recovery-time objective (RTO), retention, legal holds, recovery-point lag, availability expectations, backup ownership, key custody, and escalation contacts.

## Executable logical backup

Requirements: PostgreSQL client tools (pg_dump, pg_restore, psql), shell utilities, and a connection to the intended source database.

```bash
export DATABASE_URL='postgresql://USER:PASSWORD@HOST:PORT/DATABASE'
export BACKUP_DIR='/secure/off-host-staging/raw-sql-vault'
bash tools/backup_postgres.sh
```

The script creates a compressed custom-format dump, SHA-256 checksum in a non-secret manifest, and restrictive local permissions. It checks that the archive can be listed before publishing output files. It never writes the connection URL to the manifest or console. Transfer artifacts to separately controlled, encrypted, preferably immutable/off-site storage according to deployment policy. The local output directory alone is not a disaster-recovery strategy.

Do not put production passwords in shell history; use an approved secret manager or a restrictive .pgpass file. The URL above is only a placeholder.

The logical dump uses --no-owner and --no-acl: roles, grants, tablespaces, server configuration, extensions, and external objects need a separately reviewed provisioning procedure. A logical dump alone may not meet point-in-time recovery objectives; evaluate physical backups and WAL archiving where RPO/RTO require them.

## Guarded restore

Restore only into a newly provisioned, isolated, empty recovery database. The script verifies the manifest checksum and archive format, requires exact database-name confirmation, normally requires the target name to end in _restore or _recovery, and refuses to write if user relations already exist. It does not drop or clean existing objects.

```bash
export RESTORE_DATABASE_URL='postgresql://USER:PASSWORD@HOST:PORT/raw_sql_vault_restore'
export RESTORE_CONFIRM_TARGET='raw_sql_vault_restore'
bash tools/restore_postgres.sh /secure/off-host-staging/raw-sql-vault/raw-sql-vault-DATABASE-YYYYMMDDTHHMMSSZ.dump
```

The matching .manifest file must be beside the dump. For a reviewed exception to the target-name suffix, set RESTORE_ALLOW_OTHER_DATABASE_NAME=YES; exact confirmation remains mandatory. Never point this script at production or a valuable database. If restore fails partway, discard and recreate the isolated target before retrying.

## Restore verification (required)

1. Record backup timestamp, source, checksum, and expected recovery point.
2. Restore into an isolated environment using the guarded script.
3. Provision required roles/extensions and external dependencies through a reviewed least-privilege process.
4. Check integrity, migration state, row counts, and domain reconciliation queries.
5. Run package smoke tests and critical queries.
6. Verify privileges, RLS, cross-tenant denial, and application connectivity using real tenant roles.
7. Measure elapsed time against deployment RTO and compare recovered point against RPO.
8. Record commit, source/target engine versions, commands, exit codes, evidence, reviewer, defects, and next drill date without recording secrets.

A successful backup command or checksum check is not proof of recoverability. A backup is verified only after restore and application-level checks succeed. No restore drill has been run by this source change.

## Disaster planning

Assess locks, rewrites, backfill size, disk headroom, replication lag, compatibility, and recovery options before migrations. Plan for accidental deletion, bad migrations, application defects, credential compromise, storage exhaustion, corruption, provider outage, and unavailable encryption keys. Keep backups isolated from primary credentials and failure domains where feasible.
