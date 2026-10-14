# Raw SQL Vault: Safe GitHub Flow and Commit-Reachability Policy

## Goals

Keep `main` releasable, ensure legitimate work remains reachable from a durable Git ref, and avoid rewriting shared history merely to make branch counts look clean.

## Standard change flow

```bash
git fetch origin --prune
git switch main
git pull --ff-only origin main
git switch -c docs/short-purpose
# make one coherent change
git diff --check
git status --short
git add path/to/changed-files
git commit -m "docs: explain a focused SQL topic"
git push -u origin docs/short-purpose
```

Open a pull request targeting `main`. Review the complete diff, run the checks, resolve feedback, and merge using the repository's approved strategy. Do not bypass branch protections just to speed up a documentation change.

## Inspecting divergence

```bash
git fetch origin --prune
git log --graph --oneline --decorate --all -40
git rev-list --left-right --count origin/main...origin/perez
git log --oneline origin/main..origin/perez
git diff --stat origin/main...origin/perez
```

For `rev-list --left-right --count A...B`, the first number is commits unique to A and the second is commits unique to B. A branch can be ahead, behind, or diverged. A count alone does not determine whether a commit is legitimate, obsolete, or already represented by a squash merge.

## Audit every remote branch before deletion

```bash
git fetch origin --prune
for branch in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin); do
  [ "$branch" = "origin/HEAD" ] && continue
  echo "===== $branch ====="
  git rev-list --left-right --count origin/main..."$branch"
  git log --oneline origin/main.."$branch"
done
```

Inspect unique commits and diffs manually. Confirm each intended change is in `main` or another deliberately retained durable ref. A commit is not orphaned merely because a feature branch is deleted; a commit with no reachable ref may eventually be garbage-collected. Conversely, an ahead count does not prove a branch should be merged.

## Merge safety

- Never force-push as routine cleanup.
- Never delete a branch with unreviewed unique work.
- Do not automatically merge all ahead branches: branches may contain experiments, secrets, obsolete changes, or incompatible work.
- Prefer pull requests and tested merge strategies.
- After merge, confirm the intended files/behaviour exist on `main` and required checks passed.
- Protect `main` from deletion and force-push; require PRs and relevant CI checks where repository permissions allow.
- Keep credentials and production data out of commits. If a secret is committed, revoke/rotate it; deleting the line alone does not erase Git history.

## SQL-specific CI checks to grow into

- SQL lint and formatting with the project's declared dialect.
- Clean database creation and full migration application.
- Upgrade migration from the prior supported schema.
- Integration tests for constraints, transaction rollback, parameterised queries and access roles.
- Tests using synthetic data only.
- Performance smoke tests for critical queries where practical.
- Documentation link and example syntax checks where supported.

## Current baseline for this change

At the time of this work, `main` and `perez` compare as identical: 0 commits ahead, 0 behind. This only compares those two refs; it is not a complete audit of all branches, tags, pull requests, or dangling objects. No existing branch is deleted or rewritten by this documentation change.
