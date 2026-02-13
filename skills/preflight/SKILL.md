---
name: preflight
description: Validate repo, branch, and environment before starting work
argument-hint: <owner/repo>
disable-model-invocation: true
---

# Preflight

Run pre-work validation checks to catch common misconfigurations before they waste time. This skill
verifies repo identity, branch state, CI health, and existing PRs.

Other skills (like `/pick-up-issue`) incorporate these checks inline. Use `/preflight` standalone
when starting ad-hoc work outside the standard skill pipeline.

## Input

`$ARGUMENTS` should be the expected `owner/repo` (e.g., `my-org/my-app`). If omitted, the check
will still run but skip the repo identity validation.

## Prerequisites

- You must be inside a git repo (not a bare workspace root).
- The `gh` CLI must be authenticated.

## Detecting Context

1. **Repo root:** Run `git rev-parse --show-toplevel`.
2. **Current branch:** Run `git branch --show-current`.
3. **Expected repo:** Parse from `$ARGUMENTS` (if provided).

## Checks

Run all checks and collect results. Print a go/no-go summary at the end.

### 1. Repo identity

Verify the git remote matches the intended target repo:

```sh
actual_remote=$(git remote get-url origin | sed -E 's|.*github\.com[:/]||; s|\.git$||')
```

If `$ARGUMENTS` was provided and `actual_remote` does not match the expected `owner/repo`:

- **FAIL** — "Remote is `$actual_remote` but expected `<owner>/<repo>`. You may be in the wrong
  repo."

If `$ARGUMENTS` was not provided, print the detected remote as informational.

### 2. Branch and tracking

Verify the current branch and its upstream:

```sh
git branch -vv | grep '^\*'
```

Check for these problems:

- **On `main`/`master` directly** — WARN: "You're on the default branch. Create a feature branch
  before making changes."
- **No upstream tracking** — INFO: "Branch has no upstream. Will need `git push -u origin HEAD`."
- **Tracking wrong remote** — FAIL: "Branch tracks `<upstream>` which doesn't match origin."

### 3. Uncommitted changes

```sh
git status --porcelain
```

If there are uncommitted changes:

- **WARN** — "Working directory has uncommitted changes. Consider committing or stashing before
  starting new work."

### 4. Base branch CI health

Check the latest CI run on the default branch. Use `$ARGUMENTS` if provided, otherwise derive from
the git remote:

```sh
repo_slug=$(git remote get-url origin | sed -E 's|.*github\.com[:/]||; s|\.git$||')
default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
[ -z "$default" ] && default="main"
gh run list -R "$repo_slug" --branch "$default" --limit 1 --json conclusion --jq '.[0].conclusion'
```

If the latest run failed:

- **WARN** — "Latest CI on `$default` is failing. Your PR may inherit pre-existing failures."

### 5. Open PRs on same branch

Check if there's already an open PR for the current branch:

```sh
repo_slug=$(git remote get-url origin | sed -E 's|.*github\.com[:/]||; s|\.git$||')
branch=$(git branch --show-current)
gh pr list --repo "$repo_slug" --head "$branch" --state open --json number,title --jq '.[]'
```

If a PR already exists:

- **INFO** — "Open PR #N already exists for this branch. You may want to work on that PR rather
  than creating a new one."

## Summary

Print all results grouped by severity:

```
Preflight: <repo> on <branch>

FAIL:  (any items — stop and fix before proceeding)
WARN:  (any items — proceed with caution)
INFO:  (any items — for awareness)

Verdict: GO / NO-GO
```

If any FAIL items exist, the verdict is **NO-GO** — stop and fix the issue before proceeding.
If only WARN or INFO items exist, the verdict is **GO** with caveats noted.
