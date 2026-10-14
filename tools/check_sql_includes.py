#!/usr/bin/env python3
"""Validate recursive psql \\ir includes without needing a database."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INCLUDE = re.compile(r"^\s*\\ir\s+([^\s]+)\s*$")


def walk(path: Path, seen: set[Path], active: set[Path]) -> list[str]:
    errors: list[str] = []
    try:
        resolved = path.resolve(strict=True)
    except FileNotFoundError:
        return [f"missing include: {path.relative_to(ROOT) if path.is_relative_to(ROOT) else path}"]
    if not resolved.is_relative_to(ROOT):
        return [f"include escapes repository root: {resolved}"]
    if resolved in active:
        return [f"recursive include cycle: {resolved.relative_to(ROOT)}"]
    if resolved in seen:
        return errors

    seen.add(resolved)
    active.add(resolved)
    try:
        text = resolved.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        active.remove(resolved)
        return [f"cannot read {resolved.relative_to(ROOT)}: {exc}"]

    for number, line in enumerate(text.splitlines(), start=1):
        match = INCLUDE.match(line)
        if not match:
            continue
        include_name = match.group(1).strip("'\\"")
        included = (resolved.parent / include_name).resolve()
        try:
            included.relative_to(ROOT)
        except ValueError:
            errors.append(f"{resolved.relative_to(ROOT)}:{number}: include escapes repository root")
            continue
        if not included.exists():
            errors.append(f"{resolved.relative_to(ROOT)}:{number}: missing {include_name}")
            continue
        errors.extend(walk(included, seen, active))

    active.remove(resolved)
    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python3 tools/check_sql_includes.py <entry.sql>", file=sys.stderr)
        return 2
    entry = (ROOT / sys.argv[1]).resolve()
    seen: set[Path] = set()
    errors = walk(entry, seen, set())
    if errors:
        print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
        return 1
    print(f"PASS: {len(seen)} SQL/psql files reachable from {entry.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
