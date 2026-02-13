---
name: cleanup
description: Clean up the current repo — prune branches, check for uncommitted work, finalize sessions
disable-model-invocation: true
---

# Cleanup

Clean up the current repository after finishing a task. Prunes stale branches, checks for
uncommitted or unpushed work, and checks for unfinalized session memories.

**Multi-agent safety:** Multiple agents may be running in parallel via worktrees. This skill only
cleans up resources belonging to the **current session** and never touches branches or worktrees
owned by other active sessions.

## Prerequisites

- You must be inside a git repository.

## Detecting Context

1. **Session name:** Extract from `$PWD`. If the path contains `.claude/worktrees/<name>/`, use
   `<name>`. Otherwise, use `$(basename "$PWD")`.
2. **Repo root:** Run `git rev-parse --show-toplevel`.
3. **Current branch:** Run `git branch --show-current`.
4. **Active worktree branches:** List all branches checked out in any worktree. These are
   **off-limits** for deletion:

   ```sh
   git worktree list --porcelain | awk '/^branch / {sub("refs/heads/", "", $2); print $2}'
   ```

   Store this list for use during branch pruning.

## Steps

### 1. Check for uncommitted and unpushed work

1. **Uncommitted changes:** Run `git status --porcelain`. If output is non-empty, **warn the user**
   and list the dirty files. Do NOT discard changes — the user must decide what to do.
2. **Unpushed commits:** Run `git log --oneline @{u}..HEAD 2>/dev/null`. If output is non-empty,
   **warn the user** that there are unpushed commits. Do NOT push — the user must decide.

If there are uncommitted changes or unpushed commits, **stop and ask the user** how to proceed
before continuing. Do not silently skip warnings.

### 2. Prune stale local branches

1. **Fetch and prune remote tracking refs:**

   ```sh
   git fetch --prune 2>/dev/null
   ```

2. **Find branches whose upstream is gone:** List local branches where the upstream tracking branch
   no longer exists on the remote:

   ```sh
   git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads/ \
     | awk '$2 == "[gone]" {print $1}'
   ```

3. **Find branches already merged into the default branch:** Determine the default branch
   (`main` or `master`) and list merged branches:

   ```sh
   default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
   [ -z "$default" ] && default="main"
   git branch --merged "origin/$default" --format='%(refname:short)' \
     | grep -v "^${default}$"
   ```

4. **Triage and delete stale branches:** Combine the two lists (dedup). For each candidate branch,
   run the following checks before deleting. Track skipped branches and their reasons for the
   summary.

   **a. Skip worktree-checked-out branches** — if the branch appears in the active worktree
   branches list (from "Detecting Context" step 4), **skip** it (reason: "checked out in a
   worktree"). This protects branches used by other parallel agents. Never attempt to delete a
   branch that is checked out in any worktree.

   **b. Check for open PRs** — query GitHub to see if the branch has an open pull request:

   ```sh
   repo_slug=$(git remote get-url origin | sed -E 's|.*github\.com[:/]||; s|\.git$||')
   open_prs=$(gh pr list --repo "$repo_slug" --head "<branch>" --state open --json number --jq 'length')
   ```

   If `open_prs > 0`, **skip** the branch (reason: "has open PR").

   **c. Delete if safe** — only if all checks above pass:

   - For **gone-upstream branches** (from step 2.2), use `-D` since the remote already deleted the
     tracking branch:

     ```sh
     git branch -D <branch>
     ```

   - For **merged branches** (from step 2.3 only), use `-d` which is safe since git confirms they
     are fully merged:

     ```sh
     git branch -d <branch>
     ```

   Report each deleted branch. If no stale branches are found, note that the repo is clean.

5. **Handle the current session's branch:** If the current branch is a candidate for deletion
   (merged or gone-upstream) and you need to switch away from it:

   **Worktree context (primary path):** If `$PWD` contains `.claude/worktrees/<name>/`, return to
   the worktree's designated branch (`claude/<name>`) instead of the default branch. Never switch
   to the default branch in a worktree — it will fail if that branch is checked out elsewhere:

   ```sh
   worktree_name=$(echo "$PWD" | sed -n 's|.*/.claude/worktrees/\([^/]*\)\(/.*\)\{0,1\}$|\1|p')
   if [ -n "$worktree_name" ]; then
     git switch "claude/${worktree_name}"
   else
     git switch <default>
   fi
   ```

   **Non-worktree context (fallback):** Switch to the default branch (`git switch <default>`).

   If `git switch` fails for any reason (branch doesn't exist, checked out elsewhere), **skip**
   the current branch (reason: "cannot switch away — delete after worktree is removed or branch
   is freed") and continue with the remaining candidates.

### 3. Finalize session memory (if applicable)

Check whether a session memory directory exists for the current session and today's date:

```sh
ls -d "$(git rev-parse --show-toplevel)/docs/agent-sessions/$(date +%Y-%m-%d)-"*/ 2>/dev/null
```

If a session directory exists and has not been finalized (contains HTML comment placeholders in
`memory.md`), remind the user to run `/session-memory finalize` before cleaning up.

### 4. Print summary

Display:

- **Session:** name (from worktree or directory)
- **Active worktrees:** count of other active worktrees detected (so the user knows parallel agents
  exist)
- **Stale branches deleted** — list each, or "none" if all clean
- **Branches skipped** — list each with its reason ("checked out in a worktree", "has open PR").
  Omit this bullet entirely if nothing was skipped.
- **Warnings** — any uncommitted changes, unpushed commits, or unfinalized session memories (this
  section only appears if there are warnings)
- **Status** — "ready for next task"
