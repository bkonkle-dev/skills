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

### 6. Worktree session conflict

If `$PWD` contains `.claude/worktrees/<name>/` or `.codex/worktrees/<name>/`, check whether
another session is already active in this worktree:

```sh
worktree_name=$(echo "$PWD" | sed -n 's|.*/\.\(claude\|codex\)/worktrees/\([^/]*\)\(/.*\)\{0,1\}$|\2|p')
if [ -n "$worktree_name" ]; then
  for projects_root in "$HOME/.claude/projects" "$HOME/.codex/projects"; do
    [ -d "$projects_root" ] || continue
    project_dir=$(find "$projects_root" -maxdepth 1 -type d -name "*worktrees-${worktree_name}" | head -1)
    [ -n "$project_dir" ] && break
  done
  if [ -n "$project_dir" ]; then
    active_count=$(find "$project_dir" -name '*.jsonl' -mmin -5 2>/dev/null | wc -l | tr -d ' ')
  fi
fi
```

If `active_count` is 2 or more (the current session has its own transcript, so 2+ means another
session is also active):

- **FAIL** — "Worktree `<name>` has an active session (multiple transcripts modified within 5
  minutes). Another agent is likely working here — dispatch to a different worktree."

If not in a worktree context, skip this check.

### 7. CI runner architecture

If the repo has a `CLAUDE.md` or `AGENTS.md` that specifies runner architecture requirements (e.g.,
ARM64 Blacksmith runners), spot-check recent workflow files for compliance:

```sh
repo_root=$(git rev-parse --show-toplevel)
if grep -q -i 'blacksmith\|ARM64' "$repo_root/CLAUDE.md" "$repo_root/AGENTS.md" 2>/dev/null; then
  mismatches=$(grep -r 'runs-on:.*ubuntu-latest' "$repo_root/.github/workflows/" 2>/dev/null | head -5)
  if [ -n "$mismatches" ]; then
    echo "WARN: Found ubuntu-latest in workflows — repo expects ARM64/Blacksmith runners"
  fi
fi
```

If mismatches are found:

- **WARN** — "Workflow files use `ubuntu-latest` but the repo specifies ARM64/Blacksmith runners.
  CI changes should use the documented runner type."

If no architecture requirements are documented, skip this check.

### 8. Branch freshness

Check how far behind the default branch the current branch is:

```sh
git fetch origin 2>/dev/null
default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
[ -z "$default" ] && default="main"
behind=$(git rev-list --count HEAD..origin/$default 2>/dev/null || echo 0)
```

If `behind` is > 50:

- **FAIL** — "Branch is $behind commits behind `origin/$default` — severely stale. Consider
  starting a fresh branch from `origin/$default` instead of rebasing."

If `behind` is > 0 (but ≤ 50):

- **WARN** — "Branch is $behind commit(s) behind `origin/$default`. Rebase before starting work
  to avoid duplicating changes that already landed on main:
  `git fetch origin && git rebase origin/$default`"

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
