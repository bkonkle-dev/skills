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

1. **Session name:** Extract from `$PWD`. If the path contains `.claude/worktrees/<name>/`, use
   `<name>`. Otherwise, use the branch slug (branch name after the last `/`, e.g.,
   `bkonkle/add-oauth` → `add-oauth`).
2. **Repo root:** Run `git rev-parse --show-toplevel`.
3. **Branch:** Run `git branch --show-current`.
4. **Scope:** Derive from branch name or PR number:
   - If a PR exists for the current branch (`gh pr view --json number --jq .number`), use `pr-{N}`.
   - Otherwise, take the branch slug after the `/` (e.g., `bkonkle/add-oauth` → `add-oauth`).
5. **Date:** Today's date as `YYYY-MM-DD`.
6. **Session directory:** `docs/agent-sessions/YYYY-MM-DD-{session-name}-{scope}/`.
7. **Session ID:** Parse from the Claude Code JSONL file path. The session ID is the conversation
   UUID — look for the most recent `.jsonl` file under `~/.claude/projects/` whose encoded path
   matches the current repo. The filename (without `.jsonl`) is the session ID. If detection fails,
   leave as `(unknown)` and note the user can fill it in manually.

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

6. **Stage everything:**

   ```sh
   git add docs/agent-sessions/
   ```

7. **Print summary** — confirm the memory file is complete and staged. List any remaining
   placeholder sections as warnings.
