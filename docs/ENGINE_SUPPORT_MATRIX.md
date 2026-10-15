# Engine Support and Compatibility Matrix

## Declared posture
PostgreSQL 15+ is the primary dialect declared by this repository. Other engines are supported only where a specific package/file names a tested variant and records execution evidence.

| Engine | Repository-wide claim | Evidence required for package verification |
|---|---|---|
| PostgreSQL 15+ | Primary target; not proof every package runs | Exact version, extensions, commands, output, limitations |
| MySQL 8 | Not comprehensively verified repository-wide | Execute package on a declared MySQL 8 release and inspect semantic differences |
| SQL Server 2019 | Not comprehensively verified repository-wide | Execute package on SQL Server 2019 and inspect T-SQL behaviour |
| Other versions | Unsupported unless explicitly stated | Package-specific compatibility decision and tests |

Engines differ in procedural languages, identity/sequence behaviour, upsert syntax, JSON semantics, date/time handling, transaction behaviour, locking, partial indexes, generated columns, RLS, roles, query planners, extensions, and DDL locking. Syntax translation does not guarantee semantic equivalence.

Each package should state engine and tested version, required extensions/privileges, authoritative entry point, supported variants, incompatibilities, exact verification command, evidence location, and date.

Do not call a package portable if it uses engine-specific syntax. Mark an alternate dialect planned/unverified unless it was executed on its own engine. Track the full audit in [issue #84](https://github.com/PerezChris99/raw-sql-vault/issues/84).
