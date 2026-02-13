---
name: pick-up-issue
description: Pick up an unassigned issue from a repo, implement it, and shepherd the PR to merge
argument-hint: <owner/repo> [issue-filter]
---

# Pick Up Issue

Find an unassigned, open issue in a repository, claim it, implement the fix or feature, open a PR,
shepherd it to merge, and confirm the issue is closed. This skill orchestrates the full lifecycle
from issue selection through cleanup.

**Multi-agent safety:** Multiple agents may run this skill in parallel across different worktrees.
Each agent works on its own issue and branch. The cleanup step at the end is session-scoped and will
not interfere with branches or worktrees used by other agents.

## Input

`$ARGUMENTS` should contain:

- **Required:** A repo reference in `owner/repo` format (e.g., `my-org/my-app`).
- **Optional:** An issue filter — a label name, milestone, or search term to narrow which issues to
  consider. If omitted, all open issues are candidates.

Examples:

- `/pick-up-issue my-org/my-app` — pick any open, unassigned issue
- `/pick-up-issue my-org/my-app bug` — prefer issues labeled `bug`
- `/pick-up-issue my-org/my-app "good first issue"` — prefer issues labeled `good first issue`

If `$ARGUMENTS` is empty, attempt to derive `owner/repo` from the current git remote. If not in a
git repo, ask the user which repo to target.

## Prerequisites

- You must be inside the target repository (or it will be derived from git context).
- The `gh` CLI must be authenticated.
- The `/shepherd-to-merge` and `/cleanup` skills must be available.

## Detecting Context

1. **Owner and repo:** Parse from the first positional argument in `$ARGUMENTS`, or derive from
   `git remote get-url origin`.
2. **Issue filter:** Everything after the `owner/repo` argument (may be empty).

## Steps

### 0. Worktree safety checks

If the current working directory is inside a git worktree (path contains `.claude/worktrees/<name>/`),
perform these checks before proceeding:

1. **Detect worktree name:** Extract `<name>` from the path.

2. **Check for active sessions:** Count JSONL transcript files modified in the last 5 minutes for
   this worktree. The current session will have its own transcript, so only flag a conflict when
   **2 or more** recent transcripts exist (indicating another session is also active):

   ```sh
   worktree_name=$(echo "$PWD" | sed -n 's|.*/.claude/worktrees/\([^/]*\)\(/.*\)\{0,1\}$|\1|p')
   if [ -n "$worktree_name" ]; then
     project_dir=$(find ~/.claude/projects/ -maxdepth 1 -type d -name "*worktrees-${worktree_name}" | head -1)
     if [ -n "$project_dir" ]; then
       active_count=$(find "$project_dir" -name '*.jsonl' -mmin -5 2>/dev/null | wc -l | tr -d ' ')
     fi
   fi
   ```

   If `active_count` is 2 or more, **STOP with error**: "Worktree `<name>` has an active session
   (multiple transcripts modified within 5 minutes). Refusing to dispatch — wait for the session
   to finish or use a different worktree."

3. **Record current branch:** The cleanup skill will independently return to `claude/<name>` in
   a worktree context. Verify the current branch matches this convention:

   ```sh
   current_branch=$(git branch --show-current)
   expected_branch="claude/${worktree_name}"
   ```

   If `current_branch` does not match `expected_branch`, warn but proceed.

### 1. Find a candidate issue

Search for open issues that are not assigned to anyone:

```sh
gh issue list -R <owner>/<repo> --state open --assignee "" --limit 30 --json number,title,labels,milestone,body,assignees
```

If an issue filter was provided, narrow the results:

- If the filter matches a label name, add `--label "<filter>"` to the query.
- If doing a text search instead, replace `--assignee ""` with `--search "<filter> no:assignee"`
  since `--search` and `--assignee` cannot be combined.

From the results, exclude issues that:

- Are already assigned (verify the `assignees` array is empty) — another agent may have just
  claimed an issue, so always re-check assignment before claiming.
- Have a `wontfix`, `duplicate`, or `invalid` label.
- Have a `status:in-progress` label (likely being worked on by another agent).
- Are pull request references (some repos track PRs as issues).

Present the top 5 candidates to the user and ask which one to work on. Include the issue number,
title, labels, and a one-line summary of the body. If the user has a preference, respect it. If they
say "any" or "you pick", choose the highest-priority candidate using this heuristic:

1. Issues with a milestone sort first.
2. Issues with `priority` or `urgent` labels sort next.
3. Issues with `bug` labels sort before `enhancement` or `feature`.
4. Older issues (lower number) sort before newer ones.

### 2. Claim the issue

**Race-condition guard:** Before claiming, re-fetch the issue to confirm it is still unassigned.
Another agent running in parallel may have claimed it between step 1 and now:

```sh
gh issue view <number> -R <owner>/<repo> --json assignees --jq '.assignees | length'
```

If the count is > 0, **skip this issue** and try the next candidate from the list gathered in
step 1. If all candidates have been claimed, re-run the search query from step 1. If the re-query
also returns no unassigned issues, inform the user that no unclaimed issues are available.

Assign yourself to the issue and add an "in progress" signal:

```sh
gh issue edit <number> -R <owner>/<repo> --add-assignee "@me"
```

If assignment fails (e.g., insufficient permissions), proceed anyway — note it in the comment
instead.

Check if the repo has a `status:in-progress` label:

```sh
gh label list -R <owner>/<repo> --search "status:in-progress" --json name --jq '.[].name'
```

If it exists, apply it:

```sh
gh issue edit <number> -R <owner>/<repo> --add-label "status:in-progress"
```

If not, skip — don't create labels automatically.

Leave a comment so others know the issue is being worked on:

```sh
gh issue comment <number> -R <owner>/<repo> --body "Picking this up — working on a fix now."
```

### 3. Preflight validation

Before writing any code, verify the environment is correct. Wrong repo/branch targeting is the #1
source of wasted work.

1. **Confirm the remote matches the intended repo.** Parse the actual owner/repo from the git
   remote and compare to the target:
   ```sh
   actual_remote=$(git remote get-url origin | sed -E 's|.*github\.com[:/]||; s|\.git$||')
   ```
   If `actual_remote` does not match `<owner>/<repo>`, **stop and error** — you're in the wrong
   repo. Do not proceed.

2. **Check CI on the base branch.** Ensure the base branch isn't broken before building on it:
   ```sh
   gh run list -R <owner>/<repo> --branch main --limit 1 --json conclusion --jq '.[0].conclusion'
   ```
   If the latest run failed, warn the user — your PR may inherit pre-existing CI failures.

### 4. Set up a branch

Fetch latest and create a feature branch. Use the human's GitHub username as the branch prefix.

**In a worktree, NEVER switch to the default branch (e.g., `main` or `master`) using `git switch`
or `git checkout`.** The default branch may be checked out in another worktree, and switching to it
would fail with `fatal: 'main' is already used by worktree at ...`. Instead, always create the
feature branch directly from `origin/<default>`:

```sh
USERNAME=$(gh api user --jq .login)
git fetch origin
default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
[ -z "$default" ] && default="main"
git switch -c "${USERNAME}/<issue-slug>" "origin/${default}"
```

This creates the branch from the remote ref without needing to check out the default branch locally.

For the issue slug, derive a short kebab-case name from the issue title (e.g., issue #42 "Fix login
timeout" becomes `fix-login-timeout`). Keep it under 50 characters.

### 5. Start session memory (if available)

If the repo has a `docs/agent-sessions/` directory, run:

```
/session-memory start
```

Update `memory.md` with the issue reference and goal throughout the implementation.

### 5.5. Check for prior context

Before implementing, check whether past sessions touched related code. This prevents re-discovering
solutions or repeating failed approaches.

1. **Check session memories** in `docs/agent-sessions/` for related work:
   ```sh
   ls docs/agent-sessions/ 2>/dev/null | grep -i "<issue-keyword>"
   ```
   Read any relevant `memory.md` files for decisions and lessons learned.

2. **Search archived transcripts** (if `transcript-archive` is available):
   ```sh
   transcript-archive search --repo <owner>/<repo> --limit 5 2>/dev/null
   ```
   If a relevant session is found, load it for context before starting implementation.

### 6. Implement the fix

Read the issue body carefully. Understand the requirements, acceptance criteria, and any linked
discussions or references.

**Before writing code:**

1. Read the relevant parts of the codebase — grep for related functions, types, and tests.
2. Check for a `CONTRIBUTING.md`, `AGENTS.md`, or `CLAUDE.md` in the repo for project-specific
   conventions.
3. Identify the files that need to change and the expected impact.
4. Plan the implementation.

**While implementing:**

1. Make minimal, focused changes — only what the issue requires.
2. Follow existing code style and conventions.
3. Write or update tests to cover the change.
4. Commit incrementally with clear messages referencing the issue:
   ```
   fix(scope): short description

   Resolves #<number>
   ```

**After implementing:**

1. Run the project's test suite, linter, and type checker.
2. Fix any failures before proceeding.

### 7. Verify and push

Before pushing, confirm you're on the correct branch and it tracks the right remote:

```sh
git branch -vv | grep '^\*'
```

Verify the output shows your feature branch tracking `origin/<your-branch>`, not `main` or another
branch. If something looks wrong, **stop and fix it** before pushing.

Then push:

```sh
git push -u origin HEAD
```

### 8. Open a pull request

Create a PR that links to the issue:

```sh
gh pr create -R <owner>/<repo> --title "<concise title>" --body "$(cat <<'EOF'
## Summary

<1-3 bullet points describing the change>

## Issue

Closes #<number>

## Test plan

- [ ] <how to verify the change>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Use `Closes #<number>` in the body so GitHub auto-closes the issue when the PR merges.

### 9. Shepherd the PR to merge

Invoke the shepherd skill to handle review, feedback, CI, and merge:

```
/shepherd-to-merge <owner>/<repo>#<pr-number>
```

Wait for the shepherd process to complete. If it encounters issues it cannot resolve, surface them
to the user.

### 10. Confirm the issue is closed

After the PR is merged, verify the issue was automatically closed:

```sh
gh issue view <number> -R <owner>/<repo> --json state --jq .state
```

If the state is not `CLOSED`, close it manually with a reference to the PR:

```sh
gh issue close <number> -R <owner>/<repo> --comment "Resolved in #<pr-number>."
```

### 11. Remove in-progress signals

If a `status:in-progress` label was added in step 2, remove it:

```sh
gh issue edit <number> -R <owner>/<repo> --remove-label "status:in-progress"
```

If no status label was added, skip this step.

### 12. Clean up

Run the cleanup skill to prune branches and check for loose work. If running in a worktree,
`/cleanup` will attempt to return to `claude/<worktree-name>` instead of the default branch. If
that branch does not exist or switching fails, it will skip changing branches.

```
/cleanup
```

### 13. Print summary

Display:

- **Issue:** number, title, and URL
- **Branch:** name of the feature branch (now deleted or merged)
- **PR:** number, title, URL, and merge status
- **Issue status:** confirmed closed
- **Cleanup:** workspace tidied
