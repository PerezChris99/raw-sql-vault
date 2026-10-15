#!/usr/bin/env bash
# Restore a verified custom-format dump into a confirmed, empty recovery database.
# This is deliberately non-destructive: no --clean and no DROP statements.
set -euo pipefail
umask 077
for cmd in psql pg_restore sha256sum awk grep sed; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd is required." >&2; exit 127; }
done
BACKUP_FILE="${1:-}"
if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
  echo "Usage: RESTORE_DATABASE_URL=... RESTORE_CONFIRM_TARGET=target_db $0 path/to/backup.dump" >&2; exit 2
fi
: "${RESTORE_DATABASE_URL:?Set RESTORE_DATABASE_URL to a dedicated, empty recovery database.}"
: "${RESTORE_CONFIRM_TARGET:?Set RESTORE_CONFIRM_TARGET to the exact target database name.}"
manifest="${BACKUP_FILE%.dump}.manifest"
[[ -f "$manifest" ]] || { echo "ERROR: Required manifest not found: $manifest" >&2; exit 2; }
expected="$(sed -n 's/^sha256=//p' "$manifest")"
actual="$(sha256sum "$BACKUP_FILE" | awk '{print $1}')"
if [[ -z "$expected" || "$expected" != "$actual" ]]; then
  echo "ERROR: Backup checksum mismatch; refusing restore." >&2; exit 3
fi
grep -qx 'format=postgres-custom' "$manifest" || { echo "ERROR: Unsupported backup format." >&2; exit 3; }
pg_restore --list "$BACKUP_FILE" >/dev/null
target_db="$(psql "$RESTORE_DATABASE_URL" -X -A -t -v ON_ERROR_STOP=1 -c 'SELECT current_database()' | tr -d '\r')"
[[ "$target_db" == "$RESTORE_CONFIRM_TARGET" ]] || { echo "ERROR: Target database name confirmation mismatch." >&2; exit 4; }
if [[ "$target_db" != *_restore && "$target_db" != *_recovery && "${RESTORE_ALLOW_OTHER_DATABASE_NAME:-NO}" != "YES" ]]; then
  echo "ERROR: Target must end in _restore or _recovery. A reviewed exception requires RESTORE_ALLOW_OTHER_DATABASE_NAME=YES." >&2; exit 4
fi
existing_objects="$(psql "$RESTORE_DATABASE_URL" -X -A -t -v ON_ERROR_STOP=1 -c "
SELECT count(*) FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND n.nspname NOT LIKE 'pg_toast%'
  AND c.relkind IN ('r','p','v','m','S','f')
")"
if [[ ! "$existing_objects" =~ ^[0-9]+$ || "$existing_objects" -ne 0 ]]; then
  echo "ERROR: Target is not empty (user relation count: $existing_objects). Recreate an isolated database." >&2; exit 5
fi
echo "Restoring verified archive into confirmed empty database '$target_db'."
pg_restore --exit-on-error --no-owner --no-acl --dbname="$RESTORE_DATABASE_URL" "$BACKUP_FILE"
echo "pg_restore completed. Run application smoke tests, reconciliation, privilege/RLS checks, and measure recovery time before calling this verified."
