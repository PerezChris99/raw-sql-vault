# Public Release Readiness Checklist

**Current decision: do not change repository visibility until blocking owner and validation gates are resolved.**

## Ownership, licence, provenance
- [ ] Owner selected license(s) for SQL/code and documentation.
- [ ] License text and reuse policy are consistent.
- [ ] Third-party snippets, diagrams, and datasets have provenance and reuse rights.
- [ ] No unsupported official-endorsement or compliance claims.

## Secret and data safety
- [ ] Current tree and full reachable history scanned for secrets.
- [ ] Exposed credentials rotated and history remediation assessed.
- [ ] Fixtures synthetic or approved for redistribution.
- [ ] No personal, confidential, regulated, or operationally sensitive data exposed.
- [ ] Dumps, logs, screenshots, and generated artifacts reviewed.

## Engineering evidence
- [ ] Static checks run and results recorded.
- [ ] Integrated SQL suite executed on disposable PostgreSQL with engine/extensions recorded.
- [ ] Failures fixed or clearly listed as blockers.
- [ ] Representative concurrency, idempotency, rollback, and negative-path tests executed.
- [ ] Security/RLS/role tests executed for representative packages.
- [ ] Performance baselines recorded for critical claims.
- [ ] Backup/restore tested for packages described as operationally approved.
- [ ] Alternate-engine claims tested or marked unverified.

## Documentation and governance
- [ ] README and disclaimer are accurate and visible.
- [ ] Maturity labels distinguish implemented, verified, and operationally approved.
- [ ] Setup identifies destructive steps and safe test environments.
- [ ] Dependencies, limitations, and unsupported assumptions are documented.
- [ ] Security reporting and contribution paths are clear.
- [ ] Intended durable branches are present and no unreviewed changes remain.
- [ ] No CI workflow was added contrary to owner policy.
- [ ] Final diff and secret scan reviewed.

## Explicit release authorization
- [ ] Owner reviewed remaining limitations and accepted release scope.
- [ ] Owner explicitly authorizes changing visibility to public.
- [ ] License and disclaimer are committed.
- [ ] Release notes state verified versus unverified packages.

A checked box requires evidence, not intent. Unknown remains open. Do not claim “100% production-ready” or “cannot crash/slow down.” Public visibility is not certification. Track gates in [issues #72–#84](https://github.com/PerezChris99/raw-sql-vault/issues/72).
