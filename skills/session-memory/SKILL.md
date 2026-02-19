---
name: session-memory
description: Create or finalize session memory files for the current working session
argument-hint: <start|finalize>
disable-model-invocation: true
---

# Session Memory

Manage session memory artifacts in repos that have opted in via a `docs/agent-sessions/` directory.
Two modes: `start` creates the session directory with a template `memory.md`; `finalize` checks for
completeness and stages everything.

Session directories are the index — each directory name encodes the date, session name, and scope.
No shared index file is maintained, so parallel sessions never conflict.

## Prerequisites

- You must be working inside a repo that has a `docs/agent-sessions/` directory.
- You must be on a feature branch (not `main`/`master`).

## Detecting Context

Before either mode, determine:

1. **Session name:** Extract from `$PWD`. If the path contains `.claude/worktrees/<name>/` or
   `.codex/worktrees/<name>/`, use
   `<name>`. Otherwise, use the branch slug (branch name after the last `/`, e.g.,
   `user/add-oauth` → `add-oauth`).
2. **Repo root:** Run `git rev-parse --show-toplevel`.
3. **Branch:** Run `git branch --show-current`.
4. **Scope:** Derive from issue number, PR number, or branch name (in priority order):
   - If the PR body contains `Closes #N` or `Resolves #N`, use `issue-{N}`.
   - If a PR exists for the current branch (`gh pr view --json number,body --jq .`), use `pr-{N}`.
   - If the branch name contains an issue reference (e.g., created by `/pick-up-issue`), extract the
     issue keyword and use `issue-{N}` or the slug as scope.
   - Otherwise, take the branch slug after the `/` (e.g., `bkonkle/add-oauth` → `add-oauth`).
5. **Date:** Today's date as `YYYY-MM-DD`.
6. **Session directory:** `docs/agent-sessions/YYYY-MM-DD-{session-name}-{scope}/`.
7. **Session ID:** Parse from the agent JSONL transcript path. The session ID is the conversation
   UUID — look for the most recent `.jsonl` file under `~/.claude/projects/` or
   `~/.codex/projects/` whose encoded path matches the current repo. The filename (without
   `.jsonl`) is the session ID. If detection fails, leave as `(unknown)` and note the user can fill
   it in manually.

If `docs/agent-sessions/` does not exist in the repo root, stop and tell the user the repo has not
opted in. They can opt in by creating `docs/agent-sessions/README.md`.

## Mode: `start`

Parse `$ARGUMENTS` — if it equals `start` (or is empty), run this mode.

### Steps

1. **Check for existing session directory.** If `docs/agent-sessions/YYYY-MM-DD-{session-name}-{scope}/`
   already exists, print its path and note that it's ready for use. Do not overwrite.

2. **Create the session directory:**

   ```sh
   mkdir -p docs/agent-sessions/YYYY-MM-DD-{session-name}-{scope}
   ```

3. **Create `memory.md`** with this template (fill in known fields, leave placeholders for others):

   ```markdown
   # Memory: <title — describe the work>

   | Field      | Value              |
   | ---------- | ------------------ |
   | Session    | {session-name}     |
   | Date       | YYYY-MM-DD         |
   | Session ID | {sessionId}        |
   | PR         | (pending)          |
   | Branch     | {branch}           |
   | Issue(s)   | (none yet)         |

   ## Goal

   <!-- What this session sets out to accomplish -->

   ## Key Decisions

   <!-- 1. **Decision** — Rationale. Alternatives considered. -->

   ## Approach

   <!-- Implementation strategy, files changed, patterns followed -->

   ## Problems Encountered

   <!-- - **Problem** — Root cause and fix -->

   ## Outcome

   <!-- End state: merged, open for review, follow-up needed -->

   ## Follow-ups

   <!-- - [ ] Unresolved items for future sessions -->
   ```

4. **Stage the new files:**

   ```sh
   git add docs/agent-sessions/YYYY-MM-DD-{session-name}-{scope}/
   ```

5. **Print summary** — show the session directory path and the memory file path. Remind to update
   the memory file incrementally throughout the session.

## Mode: `finalize`

Parse `$ARGUMENTS` — if it equals `finalize`, run this mode.

### Steps

1. **Find the session directory.** Look for a directory in `docs/agent-sessions/` matching the
   current session name and branch scope for today's date. If multiple exist, use the most recent.
   If none exist, tell the user to run `/session-memory start` first.

2. **Check for completeness.** Read `memory.md`. Look for HTML comment placeholders
   (`<!-- ... -->`). List sections that still have only placeholder content and prompt the user to
   fill them in before finalizing.

3. **Update PR number.** If `memory.md` still shows `(pending)` for the PR field and a PR exists
   for the current branch, update it:

   ```sh
   gh pr view --json number --jq .number
   ```

4. **Update session ID.** If `memory.md` still shows `(unknown)` for the Session ID field, attempt
   to detect it again from the JSONL file path.

5. **Validate metadata completeness.** Check that the metadata table in `memory.md` has been filled
   in — Session, Date, Branch, and PR fields should not be placeholders. If any are still
   placeholders, warn the user.

6. **Stage and commit the session memory:**

   ```sh
   git add docs/agent-sessions/
   git commit -m "docs(sessions): finalize session memory"
   ```

   The memory must be committed before the next step can verify it's in the PR's commit chain.

7. **Verify session memory is in the PR's commit chain.** Session memories committed to a worktree
   branch can get stranded if the PR merges via squash from a different commit history. Check that
   the session memory will actually land on main:

   a. **Check if a PR exists for the current branch:**
      ```sh
      branch=$(git branch --show-current)
      pr_json=$(gh pr view --json number,headRefName,state --jq '.' 2>/dev/null || echo '{}')
      pr_number=$(echo "$pr_json" | jq -r '.number // empty')
      pr_head=$(echo "$pr_json" | jq -r '.headRefName // empty')
      ```

   b. **If the PR branch differs from the current branch** (e.g., you're on a worktree branch but
      the PR was created from a different branch), the session memory won't make it to main. Warn:
      "Session memory is on branch `$branch` but PR #N targets branch `$pr_head`. The memory will
      be stranded after merge."

      In this case, **cherry-pick the session memory commit to the PR branch**:

      ```sh
      memory_commit=$(git log --oneline -1 --format='%H' -- docs/agent-sessions/)
      git switch "$pr_head"
      git cherry-pick "$memory_commit"
      git push
      git switch "$branch"
      ```

      If cherry-picking is not feasible (e.g., PR branch is on a different remote or has conflicts),
      note this in the summary and recommend creating a separate PR for the session memory.

   c. **If no PR exists yet**, remind the agent to ensure the session memory is included when the PR
      is created.

8. **Print summary** — confirm the memory file is complete and committed. List any remaining
   placeholder sections as warnings. If the PR branch verification from step 7 flagged any issues,
   include them prominently in the summary.
