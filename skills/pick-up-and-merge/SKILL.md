---
name: pick-up-and-merge
description: One-command issue claim to merged PR pipeline
argument-hint: <owner/repo> [issue-filter]
---

# Pick Up and Merge

Run the full issue lifecycle as a single command: select an unassigned issue, claim it,
implement the change, open a PR, shepherd through review/CI, merge, verify closure, and clean up.

This skill is an umbrella entry point for operators who want one command instead of manual handoffs
between `/pick-up-issue`, `/shepherd-to-merge`, and `/cleanup`.

## Input

`$ARGUMENTS` should contain:

- **Required:** `owner/repo`
- **Optional:** issue filter (label, milestone, or search text)

Examples:

- `/pick-up-and-merge my-org/my-app`
- `/pick-up-and-merge my-org/my-app bug`
- `/pick-up-and-merge my-org/my-app "good first issue"`

If `$ARGUMENTS` is empty, derive `owner/repo` from `git remote get-url origin`.

## Prerequisites

- You are in a clone of the target repo.
- `gh` CLI is authenticated.
- `/pick-up-issue` skill is available.

## Steps

### 1. Normalize arguments

Parse `owner/repo` and optional issue filter from `$ARGUMENTS`.

- If `owner/repo` is missing, derive from git remote.
- Preserve the filter string exactly as provided.

### 2. Run the end-to-end pipeline

Invoke `/pick-up-issue` with the normalized arguments:

```
/pick-up-issue <owner/repo> [issue-filter]
```

`/pick-up-issue` already performs the complete lifecycle:

1. Worktree safety checks
2. Candidate issue discovery and selection
3. Claim and in-progress signaling
4. Preflight validation
5. Branch setup
6. Implementation + tests/validation
7. PR creation
8. Shepherd to merge
9. Issue closure verification
10. Cleanup

Do not stop at PR creation. Continue until merge/closure/cleanup are complete or a hard blocker is
reached.

### 3. Confirm final state

After `/pick-up-issue` completes, print a compact completion report with:

- issue number/title/url
- PR number/title/url and merge status
- final issue state
- cleanup outcome

If blocked, print the first blocking step and exact command to resume.

## Notes

- This is a convenience wrapper to remove operator handoff overhead.
- Keep behavior consistent with `/pick-up-issue` so improvements in that skill automatically apply.
