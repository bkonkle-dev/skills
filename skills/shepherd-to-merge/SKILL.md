---
name: shepherd-to-merge
description: Shepherd a PR through review, feedback resolution, CI checks, and auto-merge
argument-hint: <owner/repo#number | pr-url | owner/repo pr-number... | --mine>
---

# Shepherd to Merge

Guide a pull request through code review, feedback resolution, CI validation, and auto-merge. This
skill orchestrates the full lifecycle from review to merge without circumventing any branch
protection rules or security constraints.

**Important:** Never use admin privileges to bypass branch protections, force-merge, or dismiss
reviews. The goal is to satisfy all merge requirements legitimately.

**Multi-agent safety:** Multiple agents may be shepherding different PRs in parallel. Expect the
base branch to move frequently as other agents merge. The rebase retry loop in step 10 handles this.
Each agent works on its own PR branch and does not modify branches belonging to other sessions.

## Input

`$ARGUMENTS` supports both single-PR and sequential batch modes.

Single-PR inputs:

- A full PR URL: `https://github.com/owner/repo/pull/123`
- A repo-qualified reference: `owner/repo#123`
- A bare PR number: `123` — only works when your current directory is inside a git repo with a
  GitHub remote.

Sequential batch inputs:

- `owner/repo 123 124 125` (explicit queue order)
- `owner/repo --mine` (discover current user's open PRs and process oldest-updated first)

If `$ARGUMENTS` is empty, ask the user which PR to shepherd — request the full URL or
`owner/repo#number`.

## Steps

### 1. Identify repository and PR queue

Parse `$ARGUMENTS` and normalize it into:

- `owner/repo`
- `pr_queue` (ordered list of one or more PR numbers)
- `mode` (`single` or `sequential`)

For single-PR input forms:

- **Full URL** (`https://github.com/owner/repo/pull/123`): extract owner, repo, and number from the
  URL path and set `pr_queue=[number]`.
- **Qualified reference** (`owner/repo#123`): split on `/` and `#` and set `pr_queue=[number]`.
- **Bare number** (`123`): detect owner/repo from `git remote get-url origin` and set
  `pr_queue=[number]`.

For sequential inputs:

- **Explicit numbers** (`owner/repo 123 124 125`): set `pr_queue` to numbers in provided order.
- **`--mine`**: discover open PRs authored by current user:
  ```sh
  me=$(gh api user --jq .login)
  gh pr list -R <owner>/<repo> --state open --author "$me" --json number,title,updatedAt,isDraft
  ```
  Exclude drafts, then sort oldest-updated first and set `pr_queue` to that order.

If `pr_queue` is empty after filtering, stop with a concise summary.

### 2. Validate each queued PR and report plan

For each PR in `pr_queue`, fetch details and confirm it is open:

```sh
gh pr view <number> -R <owner>/<repo> --json number,title,state,headRefName,baseRefName,url,reviews,statusCheckRollup
```

Skip PRs that are already merged or closed; report why each was skipped.

Print the final processing queue before continuing. In sequential mode, this is required progress
context for the operator.

### 3. Process queue one PR at a time

For each PR in `pr_queue`, run steps 4-16 completely before moving to the next PR. Never shepherd
multiple PRs concurrently from this skill.

After each PR reaches `MERGED`, print a one-line progress update:

- `Completed <index>/<total>: #<number> <title> (<url>)`

### 4. Check out the PR branch

Ensure you're in the repo and check out the PR branch:

```sh
gh pr checkout <number>
```

### 5. Spawn a review subagent

Use the **Task tool** to launch a subagent that performs a thorough code review of the PR. The
subagent should:

- Read and understand every changed file in the PR diff (`gh pr diff <number>`)
- Review for correctness, security issues, performance concerns, and style consistency
- Return a structured summary: a list of issues found (with file, line, and description) and an
  overall assessment (approve, request changes, or comment)

Wait for the subagent to return its findings before proceeding.

### 6. Address review feedback

After the subagent returns, check for any existing review comments and GitHub Copilot suggestions on
the PR:

```sh
gh api repos/<owner>/<repo>/pulls/<number>/comments --jq '.[] | {id, node_id, path, line, body, user: .user.login}'
gh api repos/<owner>/<repo>/pulls/<number>/reviews --jq '.[] | {id, node_id, state, body, user: .user.login}'
```

For each piece of actionable feedback (from the subagent review, human reviewers, or Copilot):

1. **Fix the issue** in the local checkout — edit the file, make the correction
2. **Commit the fix** with a clear message referencing the feedback
3. **Resolve the review thread** if it's a PR review comment thread. First, find the thread ID for
   the comment, then resolve it:
   ```sh
   # Get the thread ID from a review comment's node_id
   gh api graphql -f query='query { node(id: "<comment-node-id>") { ... on PullRequestReviewComment { pullRequestReviewThread { id } } } }' --jq '.data.node.pullRequestReviewThread.id'

   # Resolve the thread
   gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<thread-id>"}) { thread { isResolved } } }'
   ```
4. **Push the fixes** to the PR branch

If any feedback requires clarification or is outside the scope of the PR, leave a reply comment
explaining why it wasn't addressed rather than ignoring it.

### 7. Resolve all review threads

Before proceeding, ensure every review thread on the PR is resolved. Unresolved threads block
auto-merge on repos with branch protection.

1. **List all review threads** and check for unresolved ones:
   ```sh
   gh api graphql -f query='query {
     repository(owner: "<owner>", name: "<repo>") {
       pullRequest(number: <number>) {
         reviewThreads(first: 100) {
           nodes { id isResolved comments(first: 1) { nodes { body path } } }
         }
       }
     }
   }' --jq '.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)'
   ```

2. For each unresolved thread where the feedback was addressed in a commit, resolve it:
   ```sh
   gh api graphql -f query='mutation { resolveReviewThread(input: {threadId: "<thread-id>"}) { thread { isResolved } } }'
   ```

3. For threads where the feedback was not addressed, leave a reply comment explaining why.

### 8. Re-review after fixes

If changes were made in step 6, do a quick self-review of the new commits to make sure the fixes
are correct and don't introduce new issues. If new problems are found, go back to step 6.

### 9. Verify CI checks

Wait for all CI status checks to complete:

```sh
gh pr checks <number> -R <owner>/<repo> --watch
```

If any checks fail:

1. Inspect the failure logs:
   ```sh
   gh run view <run-id> --log-failed
   ```
2. Fix the issue locally, commit, and push
3. Wait for checks to re-run and pass
4. Repeat until all checks are green

Do **not** skip or override failing checks. If a check is flaky and the failure is unrelated to the
PR, note it in a comment but do not bypass it.

If CI workflows fail to **trigger** at all (no runs appear after pushing):

1. Rebase onto the latest base branch — stale workflow YAML is the most common cause.
2. If still no trigger, push an empty commit: `git commit --allow-empty -m "chore: trigger CI"`
3. If still no trigger, close and reopen the PR:
   `gh pr close <number> -R <owner>/<repo> && gh pr reopen <number> -R <owner>/<repo>`
4. As a last resort, create a new PR from the same branch.

### 10. Rebase on base branch (with retry loop)

Concurrent merges from other agents move the base branch forward frequently. This step may need to
run multiple times — up to 5 attempts. With many parallel agents, the base branch can move several
times while CI is running.

**For each attempt (max 5):**

1. Check merge state:
   ```sh
   gh pr view <number> -R <owner>/<repo> --json mergeStateStatus --jq .mergeStateStatus
   ```

2. If the status is `CLEAN`, exit the loop — proceed to step 11.

3. Otherwise (`BEHIND`, `DIRTY`, or any other non-clean state):
   a. Fetch the latest base branch:
      ```sh
      git fetch origin <base-branch>
      ```
   b. Rebase onto it:
      ```sh
      git rebase origin/<base-branch>
      ```
   c. If there are merge conflicts, resolve them carefully — read both sides before choosing.
   d. Force-push with lease (safe — only overwrites your own branch):
      ```sh
      git push --force-with-lease
      ```
   e. Wait for CI to re-run and pass before the next iteration.
   f. After CI passes, re-check `mergeStateStatus`. If still not `CLEAN`, loop again.

4. If all 5 attempts fail to reach `CLEAN`, inform the user — multiple agents are likely merging
   concurrently and manual coordination may be needed.

### 11. Enable auto-merge

Once all feedback is addressed and CI is green (or running), enable auto-merge so GitHub merges the
PR automatically when all branch protection requirements are met:

```sh
gh pr merge <number> -R <owner>/<repo> --auto --squash
```

Use `--squash` by default. If the repo convention prefers merge commits or rebases, match the
convention instead.

**Do not** use `--admin` or any flag that bypasses branch protections. The PR must satisfy all
status checks and have all review threads resolved before merging. No human review approval is
required — the only merge gates are CI and resolved threads. If `mergeStateStatus` is `BLOCKED`
after CI passes, check for unresolved review threads (step 7) rather than assuming human approval
is needed.

### 12. Confirm and summarize

Print a summary:

- **PR:** title and URL
- **Review:** findings from the subagent review
- **Fixes applied:** list of commits pushed to address feedback
- **CI status:** all checks passing
- **Merge:** auto-merge enabled, will merge when all requirements are met

If auto-merge could not be enabled (e.g., the repo doesn't support it), inform the user and suggest
they merge manually once requirements are satisfied.

### 13. Post-merge session memory rescue

After the PR merges (or when auto-merge is enabled), check whether any session memories are stranded
on the current branch but missing from the merged PR. Session memories committed to worktree branches
often get lost when the PR squash-merges a different commit chain.

```sh
state=$(gh pr view <number> -R <owner>/<repo> --json state --jq .state)
```

If the state is `MERGED`:

1. **Check for session memory commits on the local branch that did not make it to main:**
   ```sh
   repo_root=$(git rev-parse --show-toplevel)
   default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
   [ -z "$default" ] && default="main"
   git fetch origin "$default"

   # Find session memory files that exist locally but not on main
   orphaned=$(git diff --name-only "origin/$default" HEAD -- docs/agent-sessions/ 2>/dev/null)
   ```

2. **If orphaned session memories are found**, rescue them by creating a cleanup PR:
   ```sh
   if [ -n "$orphaned" ]; then
     USERNAME=$(gh api user --jq .login 2>/dev/null || echo "agent")
     rescue_branch="${USERNAME}/rescue-session-memory-$(date +%Y%m%d-%H%M%S)"
     git switch -c "$rescue_branch" "origin/$default"
     git checkout HEAD@{1} -- docs/agent-sessions/
     git add docs/agent-sessions/
     git commit -m "docs: rescue stranded session memory from merged PR #<number>

   Why: Session memory was committed to a worktree branch that diverged from the
   PR's commit chain. The PR merged via squash, leaving the memory stranded."
     git push -u origin HEAD
     gh pr create --title "docs: rescue session memory from PR #<number>" \
       --body "Rescues session memory files that were stranded on a worktree branch after PR #<number> merged via squash."
   fi
   ```

   If the rescue PR creation fails, warn the user that session memories need manual rescue.

### 14. Archive transcript

After a successful merge, automatically archive the current session transcript to S3 and DynamoDB so
future agents can search and recall this session's context.

**Prerequisites:** The `scripts/transcript-archive` CLI must exist in the repo, and the
`AWS_PROFILE=agent-write` profile must be available. If either is missing, warn the user and skip
this step rather than failing.

1. **Detect session ID and repo root:**
   ```sh
   repo_root=$(git rev-parse --show-toplevel)
   ```

   Detect the current session ID from runtime-specific sources:
   - Prefer `CODEX_THREAD_ID` in Codex by matching `*${CODEX_THREAD_ID}*.jsonl` under
     `~/.codex/sessions/` and `~/.codex/archived_sessions/`.
   - Prefer `CLAUDE_SESSION_ID` in Claude Code by matching `*${CLAUDE_SESSION_ID}*.jsonl` under
     `~/.claude/projects/`.
   - If those env vars are unavailable, fall back to the most recent `.jsonl` for the current
     runtime (`~/.codex/sessions` for Codex; `~/.claude/projects` for Claude).
   - Use the matched filename without `.jsonl` as `session_id`.
   - If no JSONL is found, warn and skip archival (best-effort behavior).

2. **Detect context for archive metadata:**
   ```sh
   current_branch=$(git branch --show-current)
   worktree_name=$(echo "$PWD" | sed -n 's|.*/\.\(claude\|codex\)/worktrees/\([^/]*\)\(/.*\)\{0,1\}$|\2|p')
   agent_name="${worktree_name:-shepherd}"
   ```

3. **Run the archive command:**
   ```sh
   runtime=$(echo "$PWD" | sed -n 's|.*/\.\(claude\|codex\)/worktrees/.*|\1|p')
   session_id=""

   if [ -n "${CODEX_THREAD_ID:-}" ]; then
     codex_match=$(
       find "$HOME/.codex/sessions" "$HOME/.codex/archived_sessions" -type f -name "*.jsonl" \
         2>/dev/null | rg "${CODEX_THREAD_ID}" | head -1
     )
     [ -n "$codex_match" ] && session_id=$(basename "$codex_match" .jsonl)
   fi

   if [ -z "$session_id" ] && [ -n "${CLAUDE_SESSION_ID:-}" ]; then
     claude_match=$(find "$HOME/.claude/projects" -type f -name "*${CLAUDE_SESSION_ID}*.jsonl" 2>/dev/null | head -1)
     [ -n "$claude_match" ] && session_id=$(basename "$claude_match" .jsonl)
   fi

   if [ -z "$session_id" ]; then
     if [ "$runtime" = "codex" ]; then
       latest=$(find "$HOME/.codex/sessions" -type f -name "*.jsonl" 2>/dev/null | sort | tail -1)
     else
       latest=$(find "$HOME/.claude/projects" -type f -name "*.jsonl" 2>/dev/null | sort | tail -1)
     fi
     [ -n "$latest" ] && session_id=$(basename "$latest" .jsonl)
   fi

   if [ -z "$session_id" ]; then
     echo "Warning: no session JSONL found for current runtime — skipping transcript archival."
   else
   AWS_PROFILE=agent-write go run "${repo_root}/scripts/transcript-archive" archive \
     --session "$session_id" \
     --agent "$agent_name" \
     --repo <owner>/<repo> \
     --branch "$current_branch" \
     --pr <number> \
     --summary "Shepherded PR #<number>: <pr-title>"
   fi
   ```

   If the `scripts/transcript-archive` directory does not exist, skip with a warning:
   ```
   Warning: transcript-archive CLI not found — skipping transcript archival.
   ```

   If the archive command fails (e.g., AWS credentials expired), warn the user but do not treat it
   as a blocking error. The PR is already merged; transcript archiving is best-effort.

### 15. Post-merge cleanup (standalone only)

When `/shepherd-to-merge` is invoked standalone (not as part of `/pick-up-issue`), clean up the local
branch after the PR merges. If the PR is still pending auto-merge, skip this step.

If the state is `MERGED`:

1. Switch away from the PR branch. In a worktree, use `claude/<worktree-name>` or
   `codex/<worktree-name>`:
   ```sh
   runtime=$(echo "$PWD" | sed -n 's|.*/\.\(claude\|codex\)/worktrees/.*|\1|p')
   worktree_name=$(echo "$PWD" | sed -n 's|.*/\.\(claude\|codex\)/worktrees/\([^/]*\)\(/.*\)\{0,1\}$|\2|p')
   if [ -n "$worktree_name" ]; then
     git switch "${runtime}/${worktree_name}" 2>/dev/null || true
   else
     default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
     [ -z "$default" ] && default="main"
     git switch "$default"
   fi
   ```
2. Delete the local PR branch:
   ```sh
   git branch -D <pr-branch>
   ```

### 16. Rebase remaining queue entries (sequential mode only)

When `mode=sequential` and at least one PR remains in `pr_queue`, update each remaining PR branch
onto the latest default branch before processing the next PR.

1. Detect default branch once:
   ```sh
   default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
   [ -z "$default" ] && default="main"
   git fetch origin "$default"
   ```
2. For each remaining PR in queue order:
   ```sh
   gh pr checkout <remaining-number> -R <owner>/<repo>
   git fetch origin "$default"
   git rebase "origin/$default"
   git push --force-with-lease
   ```
3. If a rebase conflict occurs, stop batch processing and report:
   - PR number and branch
   - conflicted files
   - exact resume command (`/shepherd-to-merge <owner>/<repo> <remaining-prs...>`)

Do not auto-resolve ambiguous conflicts.

### 17. Final queue report (sequential mode only)

After the queue is exhausted (or processing stops early), print:

- PRs merged (number + URL)
- PRs skipped (with reason)
- first blocking PR, if any
- whether the full queue completed
