---
name: recall
description: Load relevant prior context from layered session memory and archived transcripts
argument-hint: [owner/repo] [keywords]
disable-model-invocation: true
---

# Recall

Load prior context before implementation so agents reuse decisions, avoid repeated failures, and
stay consistent with existing patterns.

This skill prioritizes the layered memory structure:

- Durable memory: `docs/agent-sessions/MEMORY.md`
- Working log: `docs/agent-sessions/memory/YYYY-MM-DD.md`
- Session artifacts: `docs/agent-sessions/YYYY-MM-DD-*/memory.md`

It can optionally augment results from `transcript-archive search` when available.

## Input

`$ARGUMENTS` accepts:

- Optional `owner/repo` (for transcript search scoping).
- Optional free-text keywords (issue number, feature area, or file/module terms).

Examples:

- `/recall`
- `/recall my-org/my-app oauth login`
- `/recall my-org/my-app #431`

## Prerequisites

- Run from a git repo.
- `docs/agent-sessions/` is expected for layered memory recall.
- `transcript-archive` is optional.

## Steps

### 1. Detect context

```sh
repo_root=$(git rev-parse --show-toplevel)
today=$(date +%Y-%m-%d)
branch=$(git branch --show-current)
```

Parse `$ARGUMENTS` into:

- `repo_slug` if the first token matches `owner/repo`
- `keywords` as remaining tokens

If `repo_slug` is missing, derive from `origin`:

```sh
repo_slug=$(git remote get-url origin | sed -E 's|.*github\.com[:/]||; s|\.git$||')
```

### 2. Read durable memory first

If `"$repo_root/docs/agent-sessions/MEMORY.md"` exists, read it first and extract relevant entries for current
keywords and branch context.

If missing, note that durable memory is not initialized for this repo.

### 3. Read today's working log

If `"$repo_root/docs/agent-sessions/memory/$today.md"` exists, read it and capture recent chronology that may
affect current work.

### 4. Find matching session artifacts

Search session artifacts for the most relevant prior runs:

```sh
find "$repo_root/docs/agent-sessions" -maxdepth 2 -type f -name memory.md 2>/dev/null
```

Prioritize artifacts by:

1. Explicit keyword matches (issue number, feature terms, filenames)
2. Branch/scope similarity
3. Recency

Read the top 3-5 relevant artifacts; avoid loading all histories.

### 5. Augment with transcript archive (optional)

If `transcript-archive` is available:

```sh
transcript-archive search --repo "$repo_slug" --limit 5 <keywords...> 2>/dev/null
```

Load only clearly relevant hits (same issue/PR, same subsystem, or matching error signatures).

If unavailable, continue without failing.

### 6. Produce a recall brief

Return a concise brief with:

1. `Decisions to reuse` (from durable/session memories)
2. `Known pitfalls` (what failed before and why)
3. `Open follow-ups` (unfinished items still relevant)
4. `Relevant artifacts` (paths to `memory.md` files used)
5. `Transcript hits` (if any)

If no meaningful context is found, state that explicitly.

## Notes

- Do not claim persistence; recall only reports what is already on disk or in transcript archive.
- If the repo lacks `docs/agent-sessions/`, recommend `/session-memory start` for future runs.
