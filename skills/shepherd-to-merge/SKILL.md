---
name: shepherd-to-merge
description: Shepherd a PR through review, feedback resolution, CI checks, and auto-merge
argument-hint: <owner/repo#number or pr-url>
---

# Shepherd to Merge

Guide a pull request through code review, feedback resolution, CI validation, and auto-merge. This
skill orchestrates the full lifecycle from review to merge without circumventing any branch
protection rules or security constraints.

**Important:** Never use admin privileges to bypass branch protections, force-merge, or dismiss
reviews. The goal is to satisfy all merge requirements legitimately.

## Input

`$ARGUMENTS` should be one of:

- A full PR URL: `https://github.com/owner/repo/pull/123`
- A repo-qualified reference: `owner/repo#123`
- A bare PR number: `123` — only works when your current directory is inside a git repo with a
  GitHub remote.

If `$ARGUMENTS` is empty, ask the user which PR to shepherd — request the full URL or
`owner/repo#number`.

## Steps

### 1. Identify the PR

Parse `$ARGUMENTS` to determine the owner, repo, and PR number:

- **Full URL** (`https://github.com/owner/repo/pull/123`): extract owner, repo, and number from the
  URL path.
- **Qualified reference** (`owner/repo#123`): split on `/` and `#` to get owner, repo, and number.
- **Bare number** (`123`): attempt to detect the repo from git context:
  1. Run `git remote get-url origin` to find the GitHub remote.
  2. Parse `owner/repo` from the remote URL.
  3. If this fails (not in a git repo), ask the user for the full `owner/repo#number`.

Once you have owner, repo, and number, set the repo reference (`-R owner/repo`) for all subsequent
`gh` commands.

Fetch PR details and confirm the PR is open:

```sh
gh pr view <number> -R <owner>/<repo> --json number,title,state,headRefName,baseRefName,url,reviews,statusCheckRollup
```

If the PR is already merged, print a friendly summary (title, URL, merge status, CI results) and
stop — no further action needed. If the PR is closed but not merged, inform the user and stop.

### 2. Check out the PR branch

Ensure you're in the repo and check out the PR branch:

```sh
gh pr checkout <number>
```

### 3. Spawn a review subagent

Use the **Task tool** to launch a subagent that performs a thorough code review of the PR. The
subagent should:

- Read and understand every changed file in the PR diff (`gh pr diff <number>`)
- Review for correctness, security issues, performance concerns, and style consistency
- Return a structured summary: a list of issues found (with file, line, and description) and an
  overall assessment (approve, request changes, or comment)

Wait for the subagent to return its findings before proceeding.

### 4. Address review feedback

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

### 5. Resolve all review threads

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

### 6. Re-review after fixes

If changes were made in step 4, do a quick self-review of the new commits to make sure the fixes
are correct and don't introduce new issues. If new problems are found, go back to step 4.

### 7. Verify CI checks

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

### 8. Rebase on base branch (with retry loop)

Concurrent merges from other sessions move the base branch forward frequently. This step may need to
run multiple times — up to 3 attempts.

**For each attempt (max 3):**

1. Check merge state:
   ```sh
   gh pr view <number> -R <owner>/<repo> --json mergeStateStatus --jq .mergeStateStatus
   ```

2. If the status is `CLEAN`, exit the loop — proceed to step 9.

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

4. If all 3 attempts fail to reach `CLEAN`, inform the user — something else is likely merging
   continuously and manual coordination is needed.

### 9. Enable auto-merge

Once all feedback is addressed and CI is green (or running), enable auto-merge so GitHub merges the
PR automatically when all branch protection requirements are met:

```sh
gh pr merge <number> -R <owner>/<repo> --auto --squash
```

Use `--squash` by default. If the repo convention prefers merge commits or rebases, match the
convention instead.

**Do not** use `--admin` or any flag that bypasses branch protections. The PR must satisfy all
required reviews, status checks, and other branch protection rules before merging.

### 10. Confirm and summarize

Print a summary:

- **PR:** title and URL
- **Review:** findings from the subagent review
- **Fixes applied:** list of commits pushed to address feedback
- **CI status:** all checks passing
- **Merge:** auto-merge enabled, will merge when all requirements are met

If auto-merge could not be enabled (e.g., the repo doesn't support it), inform the user and suggest
they merge manually once requirements are satisfied.
