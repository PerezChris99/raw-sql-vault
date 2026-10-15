#!/usr/bin/env bash
# Create a compressed logical backup plus checksum and non-secret manifest.
# Plain language: a backup is useful only if completeness and identity can be checked.
# Technical: custom format supports selective restore; the manifest never records
# DATABASE_URL or credential material.
set -euo pipefail
umask 077
for cmd in pg_dump pg_restore psql sha256sum awk sed; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: $cmd is required." >&2; exit 127; }
done
: "${DATABASE_URL:?Set DATABASE_URL to the PostgreSQL database to back up.}"
BACKUP_DIR="${BACKUP_DIR:-backups/postgres}"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
database_name="$(psql "$DATABASE_URL" -X -A -t -v ON_ERROR_STOP=1 -c 'SELECT current_database()' | tr -d '\r')"
if [[ -z "$database_name" || "$database_name" == *$'\n'* ]]; then
  echo "ERROR: Could not determine a single database name." >&2; exit 2
fi
safe_database_name="$(printf '%s' "$database_name" | tr -c 'A-Za-z0-9._-' '_')"
base="raw-sql-vault-${safe_database_name}-${timestamp}"
final_file="$BACKUP_DIR/$base.dump"
manifest="$BACKUP_DIR/$base.manifest"
tmp_file="$(mktemp "$BACKUP_DIR/.backup.XXXXXX")"
tmp_manifest="$(mktemp "$BACKUP_DIR/.manifest.XXXXXX")"
cleanup() { rm -f "$tmp_file" "$tmp_manifest"; }
trap cleanup EXIT INT TERM
echo "Creating logical backup for database '$database_name' (connection details are not logged)."
pg_dump --format=custom --no-owner --no-acl --file="$tmp_file" "$DATABASE_URL"
pg_restore --list "$tmp_file" >/dev/null
checksum="$(sha256sum "$tmp_file" | awk '{print $1}')"
server_version="$(psql "$DATABASE_URL" -X -A -t -v ON_ERROR_STOP=1 -c 'SHOW server_version' | tr -d '\r')"
pg_dump_version="$(pg_dump --version | sed 's/[[:space:]]\+/ /g')"
{
  printf 'format=postgres-custom\n'
  printf 'created_utc=%s\n' "$timestamp"
  printf 'source_database=%s\n' "$database_name"
  printf 'server_version=%s\n' "$server_version"
  printf 'pg_dump_version=%s\n' "$pg_dump_version"
  printf 'sha256=%s\n' "$checksum"
} > "$tmp_manifest"
chmod 600 "$tmp_file" "$tmp_manifest"
mv "$tmp_file" "$final_file"
mv "$tmp_manifest" "$manifest"
trap - EXIT INT TERM
echo "Backup archive: $final_file"
echo "Manifest:       $manifest"
echo "SHA-256:        $checksum"
echo "Archive-list verification passed. A restore drill is still required."
