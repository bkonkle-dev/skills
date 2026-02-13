---
name: recall
description: Search and load archived Claude Code transcripts from past sessions
argument-hint: <search|load> [args]
disable-model-invocation: true
---

# Recall

Search for and load archived Claude Code JSONL transcripts stored in DynamoDB. This allows sessions
to retrieve full conversation context from past sessions to understand prior implementation
decisions.

## Prerequisites

- The `transcript-archive` CLI must be built and available. If you're in the `bkonkle-dev/apps`
  repo, build it with:

  ```sh
  go build -o ~/go/bin/transcript-archive ./scripts/transcript-archive/
  ```

  Otherwise, ensure `transcript-archive` is on your `$PATH`.

- For local development, set `LOCALSTACK_ENDPOINT=http://localhost.localstack.cloud:4566`.

## Mode: `search`

Parse `$ARGUMENTS` — if the first word is `search`, run this mode.

### Usage

```
/recall search --since YYYY-MM-DD [--until YYYY-MM-DD]
/recall search --repo <org/repo>
/recall search --branch <name>
/recall search --issue <N>
/recall search --pr <N>
```

### Steps

1. **Parse flags** from `$ARGUMENTS` after the `search` keyword.

2. **Run the CLI:**

   ```sh
   transcript-archive search <flags>
   ```

3. **Display results.** Show the table of matching sessions. If `--json` is passed, output raw
   JSON for programmatic use.

4. **Suggest next steps.** If results are found, suggest loading a specific session:

   ```
   To load a session's transcript: /recall load <session-id>
   ```

## Mode: `load`

Parse `$ARGUMENTS` — if the first word is `load`, run this mode.

### Usage

```
/recall load <session-id>
/recall load <session-id> --format summary
/recall load <session-id> --format full
/recall load <session-id> --format context --max-tokens 50000
```

### Formats

- **context** (default) — Structured markdown with metadata table, conversation flow summary, and
  files modified. Designed for injecting into session context as background knowledge.
- **summary** — Readable markdown conversation showing user messages and assistant responses.
  Skips tool use details and thinking blocks.
- **full** — Raw JSONL transcript. Large — use `--output <file>` to write to disk.

### Steps

1. **Parse the session ID** — first non-flag argument after `load`.

2. **Run the CLI:**

   ```sh
   transcript-archive load <session-id> [--format <type>] [--max-tokens <N>]
   ```

3. **Display the output.** For `context` and `summary` formats, display the markdown directly.
   For `full` format, suggest writing to a file instead:

   ```sh
   transcript-archive load <session-id> --format full --output /tmp/session.jsonl
   ```

4. **Provide context.** After loading, remind that this is a previous session's transcript and it
   can be referenced for understanding prior decisions.

## Auto-Detection

If no arguments are provided (just `/recall`), attempt to auto-detect useful context:

1. **Check current branch** for related sessions:

   ```sh
   branch=$(git branch --show-current 2>/dev/null)
   transcript-archive search --branch "$branch" --limit 5
   ```

2. **If no branch results, search recent sessions:**

   ```sh
   transcript-archive search --limit 5 --since <30-days-ago>
   ```

3. Display results and suggest loading a specific session.
