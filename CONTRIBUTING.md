# Contributing to Raw SQL Vault

This repository uses a strict two-branch workflow. Read this file before modifying or merging any unit.

## One-time local setup

Set the expected local identity:

```bash
git config user.name "Perez"
git config user.email "kweeziperez712@gmail.com"
```

Verify it before committing:

```bash
git config --get user.name
git config --get user.email
```

A local setting controls commits made by your local Git client. It does **not** retroactively change existing commits or guarantee the identity of commits created through a separate GitHub integration/API. Inspect GitHub commit metadata after any automated write.

## Branches — exactly two

- `main` — canonical branch; it should contain all accepted work.
- `perez` — the only working branch; all unit work is prepared here.
- Do not create additional branches. Do not force-push `main`.
- Never rebase `main`, commit on a detached HEAD, or amend a commit after it has been pushed.
- Never delete a branch containing commits that are not safely reachable from another durable ref.

**Repository transition note:** At the start of this blueprint, an earlier assistant-created branch, `docs/beginner-gap-audit-uganda-projects`, already existed with an open PR. Its commits have been fast-forwarded into `perez` so the work is preserved on the designated work branch. The branch ref/PR still needs final cleanup after the equivalent commits are safely reachable from `main`; do not delete it prematurely. This is a pre-existing deviation from the two-branch policy, not permission to create more branches.

## Per-unit workflow

One unit means one ministry/portfolio, agency, local-government capability, sector or worldwide domain package. Stage only that unit's files, never blindly stage everything.

```bash
git fetch origin --prune
git checkout perez
git pull --ff-only origin perez

# Create/change files for one unit, then inspect:
git status --short
git diff --check
git diff --stat
git diff

# Stage ONLY the intended paths; example:
git add uganda/central-government/ug-m-health/

# Commit with the detailed template below:
git commit

# Push the work branch:
git push origin perez

# After review and the required checks pass:
git checkout main
git pull --ff-only origin main
git merge --no-ff perez -m "<detailed merge message>"
git push origin main

# Bring the work branch back in sync; no rebase of main:
git checkout perez
git merge main
git push origin perez
```

Do not merge a package simply because the SQL parses. Do not bypass repository protections or required reviews. If a pull request is the review mechanism, it must target `main` from `perez`; do not create a new branch per unit.

## Commit message template (mandatory)

Use a descriptive subject no longer than 72 characters and include the sections below. Do not invent tests or claim success for checks that were not actually run.

```text
<type>(<scope>): <short summary <= 72 chars>

Why:
  <real-world problem this solves>

What:
  - <file/schema added or changed>
  - <tables, views, procedures, tests and docs>

Domain:
  <e.g. Uganda -> Ministry of Health -> medicine stock>

Impact:
  <who benefits and what measurable reporting/workflow is enabled>

Testing:
  <exact commands and actual result; say NOT RUN when not run>

Refs:
  <issue, phase, roadmap section or PR>

Signed-off-by: Perez <kweeziperez712@gmail.com>
```

Allowed types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `perf`, `security`.

The sign-off line is commit-message metadata; it does not prove that Git's author/committer metadata has the configured email. Verify the actual commit identity separately.

## Required pre-merge checks

- Confirm branch is `perez`, working tree is clean apart from the intended package, and no credentials or real personal records are staged.
- Run `git diff --check` and the repository's declared lint/test commands.
- Test a clean PostgreSQL 15+ setup with synthetic seed data and all package assertions.
- Test any MySQL 8 / SQL Server 2019 variant on that engine; otherwise label it unverified.
- Inspect constraints, null/empty/duplicate cases, permission denial, RLS cross-tenant denial, transaction rollback and concurrency as relevant.
- Review query plans with representative data where performance is important.
- Verify migration upgrade path, rollback/recovery notes, and README setup order.
- Inspect the PR diff; ensure no unrelated files are present.
- Merge only if all required review/checks pass.

## No orphan / no hanging commits

Before a merge:

```bash
git fetch origin --prune
git log --graph --oneline --decorate --all -40
git rev-list --left-right --count origin/main...origin/perez
git log --oneline origin/main..origin/perez
```

After the merge and branch sync:

```bash
git fetch origin --prune
git log --oneline --graph --all --decorate
git log main..perez                 # must be empty after sync
git fsck --no-reflogs | grep dangling  # investigate any result; never discard commits blindly
```

Rules:
- Never commit while HEAD is detached.
- Never run `git commit --amend` after push.
- Never delete unmerged work; first make the commits safely reachable from `main` or another intentionally retained durable ref, then verify.
- Never force-push `main` or rebase `main`.
- Every accepted commit on `perez` must be reachable from `main` after the merge/sync sequence.
- Investigate dangling **commits** individually. Git can report dangling trees/blobs as well; do not treat every dangling object as a lost commit or delete objects without a rationale.
- After each merge, capture `git log --oneline --graph --all --decorate` and verify `git log main..perez` is empty.

## Repository layout and SQL conventions

Each indexed solution should follow [docs/CONVENTIONS.md](docs/CONVENTIONS.md) and [docs/ROADMAP.md](docs/ROADMAP.md). PostgreSQL 15+ is primary. All fixtures must be synthetic. Document engine/version, setup order, data assumptions, access model, migration behavior and actual test results.

The local pre-commit hook described in later tooling work is not installed by this Phase 0 blueprint. Until a reviewed hook exists, verify branch, identity, staged paths and message manually.
