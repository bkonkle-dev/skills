---
name: firecrawl-api
description: Use when a task should call a hosted Firecrawl HTTPS API directly instead of running a local MCP server or `npx`. Reads the base URL from `FIRECRAWL_API_URL`, authenticates with `FIRECRAWL_API_KEY`, and includes a YouTube transcript workflow that works in sandboxed environments.
---

# Firecrawl API

## When to use
- The user wants data from a hosted Firecrawl HTTPS API.
- The environment does not have `npx`, terminal access on the target device, or a local MCP runtime.
- The task is a Firecrawl API operation such as `scrape`, `search`, `map`, `extract`, or `crawl`.
- The task is summarizing a YouTube video and you need transcript or caption text.

## Endpoint and auth
- Base URL: `FIRECRAWL_API_URL`
- Auth header: `X-API-Key: $FIRECRAWL_API_KEY`
- Required env var: `FIRECRAWL_API_URL`
- Required env var: `FIRECRAWL_API_KEY`

If either environment variable is missing, stop and say exactly that.

## Core workflow
1. Read `FIRECRAWL_API_URL` and `FIRECRAWL_API_KEY`.
2. Pick the smallest Firecrawl endpoint that fits the task.
3. Normalize the base URL by trimming any trailing slash before appending `/v1/...`.
4. Use `curl -sS` for one-off requests.
5. Return the useful fields, not the full raw payload, unless the user asked for it.

## API cheat sheet

Scrape:
```sh
curl -sS "${FIRECRAWL_API_URL%/}/v1/scrape" \
  -H "X-API-Key: $FIRECRAWL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}'
```

Search:
```sh
curl -sS "${FIRECRAWL_API_URL%/}/v1/search" \
  -H "X-API-Key: $FIRECRAWL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"site:example.com docs"}'
```

Map:
```sh
curl -sS "${FIRECRAWL_API_URL%/}/v1/map" \
  -H "X-API-Key: $FIRECRAWL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}'
```

Extract:
```sh
curl -sS "${FIRECRAWL_API_URL%/}/v1/extract" \
  -H "X-API-Key: $FIRECRAWL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"urls":["https://example.com"],"prompt":"Extract the main facts."}'
```

Crawl:
```sh
curl -sS "${FIRECRAWL_API_URL%/}/v1/crawl" \
  -H "X-API-Key: $FIRECRAWL_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://example.com"}'
```

## YouTube workflow

Use two stages:

1. Use Firecrawl `scrape` on the YouTube URL for metadata.
   This usually gets the title, description, publish date, channel, and duration.

2. Use `scripts/youtube_transcript.py` for the transcript.
   Firecrawl often does not return the full spoken transcript from YouTube pages even when the page exposes a transcript panel.

Run it like this:
```sh
python3 scripts/youtube_transcript.py "https://www.youtube.com/watch?v=hDn8-fK3XaU"
```

Without timestamps:
```sh
python3 scripts/youtube_transcript.py --no-timestamps "https://www.youtube.com/watch?v=hDn8-fK3XaU"
```

## Why the helper script is better in sandboxes
- It does not try to install Python packages globally.
- If `youtube-transcript-api` is missing, it creates a temporary virtualenv under the system temp directory and installs only there.
- That is safer and more reliable in externally managed Python environments and most sandboxed workspaces.
- If the sandbox blocks network access or virtualenv creation, the script fails cleanly and you should fall back to a metadata-only summary.

## Notes
- Preserve user-provided payload fields; only add headers and the base URL.
- Do not echo the API key back to the user.
- If the API returns an auth error, tell the user it likely means the key is missing, invalid, expired, or lacks scope.
- For YouTube, do not promise a transcript until the helper script succeeds. The page can expose transcript metadata while still blocking direct caption fetches.
