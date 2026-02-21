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

Use a layered memory model (influenced by OpenClaw):

- **Session artifact (source of truth for one run):**
  `docs/agent-sessions/YYYY-MM-DD-{session-name}-{scope}/memory.md`
- **Working memory log (append-only timeline):**
  `docs/agent-sessions/memory/YYYY-MM-DD.md`
- **Durable memory (curated cross-session memory):**
  `docs/agent-sessions/MEMORY.md`

Session directories still prevent collisions across parallel worktrees, while the log and durable
files make recall easier across many sessions.

## Memory Rules

1. Never claim memory persistence unless it is written to disk in this repo.
2. If the user says "remember", "note this", "save this", or equivalent, write it to the current
   session `memory.md` and clearly mark it if it is durable (decision, preference, stable fact,
   recurring pitfall) so it can be promoted later.
3. Use `docs/agent-sessions/memory/YYYY-MM-DD.md` for operational breadcrumbs and chronology during
   the run; do not curate heavily there.
4. Update `docs/agent-sessions/MEMORY.md` during `finalize` by promoting durable items from the
   session artifact. Keep entries short, deduplicated, and date-stamped.

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
7. **Session ID:** Parse from the agent JSONL transcript path. Prefer the structured
   `session_meta.payload.id` value from the transcript, and include Codex archived transcripts as a
   fallback source.

   Use this detection order:

   a. Build candidate transcript list from:
   - `find ~/.codex/sessions -type f -name '*.jsonl' 2>/dev/null`
   - `find ~/.codex/archived_sessions -maxdepth 1 -type f -name '*.jsonl' 2>/dev/null`
   - `find ~/.claude/projects -type f -name '*.jsonl' 2>/dev/null`

   b. Prefer the most recent candidate whose `session_meta.payload.cwd` contains the current repo
   root path (or current worktree path).

   c. Extract the session ID:
   - First choice: `jq -r 'select(.type=="session_meta" and .payload.id != null and .payload.id != "") | .payload.id' <file> | head -1`
   - If missing, parse UUID from filename with:
     `grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'`
   - If still missing and filename starts with `rollout-`, use the rollout filename stem (without
     `.jsonl`) as a temporary Session ID and note it is rollout-formatted.

   d. If no candidate matches, leave as `(unknown)` and note the user can fill it manually.

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

4. **Ensure layered memory files exist:**

   ```sh
   mkdir -p docs/agent-sessions/memory
   touch "docs/agent-sessions/memory/YYYY-MM-DD.md"
   ```

   If `docs/agent-sessions/MEMORY.md` does not exist, create it with:

   ```markdown
   # Durable Memory

   ## Decisions

   <!-- Stable decisions that future sessions should reuse -->

   ## Preferences

   <!-- User/team preferences and conventions -->

   ## Facts

   <!-- Stable repo or environment facts -->

   ## Pitfalls

   <!-- Repeated failure modes and how to avoid them -->
   ```

5. **Append a session-open breadcrumb** to `docs/agent-sessions/memory/YYYY-MM-DD.md`:

   ```markdown
   ## HH:MM {session-name} ({scope})
   - Started on branch `{branch}`
   - Session artifact: `docs/agent-sessions/YYYY-MM-DD-{session-name}-{scope}/memory.md`
   ```

6. **Stage the new files:**

   ```sh
   git add docs/agent-sessions/YYYY-MM-DD-{session-name}-{scope}/ docs/agent-sessions/memory/ docs/agent-sessions/MEMORY.md
   ```

7. **Print summary** — show all three memory paths and remind the user to update the session
   `memory.md` incrementally.

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

4. **Update session ID.** If `memory.md` still shows `(unknown)` or `(not captured)` for the Session
   ID field, attempt detection again using the same logic from Detecting Context step 7
   (`session_meta.payload.id` first, then filename UUID, then rollout stem fallback).

5. **Validate metadata completeness.** Check that the metadata table in `memory.md` has been filled
   in — Session, Date, Branch, and PR fields should not be placeholders. If any are still
   placeholders, warn the user.

6. **Ensure layered files exist, then promote durable memory candidates.**

   Before promoting, ensure layered memory files exist. This keeps `finalize` backward-compatible
   with older sessions that only have `docs/agent-sessions/YYYY-MM-DD-.../memory.md`.

   - If `docs/agent-sessions/MEMORY.md` does not exist, create it using the same template from
     `start` mode.
   - If `docs/agent-sessions/memory/YYYY-MM-DD.md` does not exist, create it.

   Review completed session sections (`Key Decisions`, `Problems Encountered`, `Outcome`,
   `Follow-ups`) and promote only durable items into `docs/agent-sessions/MEMORY.md`.

   Promotion format:

   ```markdown
   - YYYY-MM-DD: <fact/decision/pitfall> (source: YYYY-MM-DD-{session-name}-{scope})
   ```

   Also append a session-close breadcrumb to `docs/agent-sessions/memory/YYYY-MM-DD.md`:

   ```markdown
   ## HH:MM finalize {session-name} ({scope})
   - Finalized `YYYY-MM-DD-{session-name}-{scope}`
   - Durable memory updated.
   ```

7. **Stage and commit the session memory:**

   ```sh
   git add docs/agent-sessions/
   git commit -m "docs(sessions): finalize session memory"
   ```

   The memory must be committed before the next step can verify it's in the PR's commit chain.

8. **Verify session memory is in the PR's commit chain.** Session memories committed to a worktree
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

9. **Print summary** — confirm memory files are complete and committed. List any remaining
   placeholder sections as warnings. If the PR branch verification from step 8 flagged any issues,
   include them prominently in the summary.
