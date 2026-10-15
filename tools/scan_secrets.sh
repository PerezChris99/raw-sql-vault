#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "ERROR: gitleaks is required. Install a trusted, current release and rerun." >&2
  exit 127
fi

echo "Scanning the current working tree for likely secrets..."
gitleaks dir --redact --verbose .

echo "Scanning commits reachable from local refs (including all refs fetched locally)..."
gitleaks git --redact --verbose --log-opts="--all" .

echo "PASS: gitleaks reported no findings in the scanned working tree and reachable local history."
echo "IMPORTANT: this is not proof of no secrets. Ensure all remote refs/history were fetched, review findings, and rotate any exposed credential."
