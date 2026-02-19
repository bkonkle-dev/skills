---
name: batch-merge
description: Merge multiple PRs sequentially to avoid rebase spirals
argument-hint: <owner/repo> [pr-number ... | --mine]
---

# Batch Merge

Merge multiple pull requests **one at a time** so each PR is rebased on the latest base branch before
it merges. This avoids concurrent auto-merge collisions and repeated rebase churn.

This skill delegates full PR handling (review feedback, CI, auto-merge) to `/shepherd-to-merge`, then
waits for each PR to fully merge before advancing to the next one.

## Input

`$ARGUMENTS` should contain:

- **Required:** `owner/repo` (for example: `my-org/my-app`).
- **Optional:** A list of PR numbers (for example: `123 124 125`) or `--mine` to discover all open PRs
  authored by the current GitHub user.

Examples:

- `/batch-merge my-org/my-app 101 102 103`
- `/batch-merge my-org/my-app --mine`

If no PR numbers are provided and `--mine` is omitted, discover open PRs by the current user.

## Prerequisites

- You must be inside a clone of the target repo.
- `gh` CLI must be authenticated.
- `/shepherd-to-merge` and `/cleanup` skills must be available.

## Steps

### 1. Resolve repository and PR set

1. Validate repository context:
   ```sh
   actual_remote=$(git remote get-url origin | sed -E 's|.*github\.com[:/]||; s|\.git$||')
   ```
   If `actual_remote` does not match `<owner>/<repo>`, stop and warn the user.

2. Build the PR queue:

   - If PR numbers were passed, use those in the provided order.
   - If `--mine` was passed (or no numbers provided), discover PRs:
     ```sh
     me=$(gh api user --jq .login)
     gh pr list -R <owner>/<repo> --state open --author "$me" --json number,title,updatedAt,isDraft
     ```

3. Filter out drafts and de-duplicate numbers. If no PRs remain, stop with a short summary.

4. Show the final queue and ask for confirmation if the queue was auto-discovered.

### 2. Verify baseline branch health

1. Detect default branch:
   ```sh
   default=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
   [ -z "$default" ] && default="main"
   ```
2. Check latest CI on default branch:
   ```sh
   gh run list -R <owner>/<repo> --branch "$default" --limit 1 --json conclusion --jq '.[0].conclusion'
   ```
3. If default branch CI is failing, continue but warn the user that failures may be inherited.

### 3. Process PRs sequentially

For each PR in queue order:

1. Re-check PR is still open:
   ```sh
   gh pr view <number> -R <owner>/<repo> --json state,isDraft,mergeStateStatus,url,title
   ```
   If closed/merged, skip and continue.

2. Shepherd this PR end-to-end:
   ```
   /shepherd-to-merge <owner>/<repo>#<number>
   ```

3. Wait until the PR is actually merged before continuing. Poll state every 30 seconds:
   ```sh
   gh pr view <number> -R <owner>/<repo> --json state --jq .state
   ```
   If still `OPEN`, keep waiting (up to a reasonable timeout, e.g., 30 minutes).

4. If the PR did not merge within timeout (blocked checks, unresolved threads, or merge conflicts),
   stop the batch and report the blocker.

5. Run cleanup after successful merge:
   ```
   /cleanup
   ```

### 4. Rebase remaining PRs after each merge

After a PR merges, update each remaining queued PR branch onto the latest default branch:

1. For each remaining PR:
   ```sh
   gh pr checkout <remaining-pr> -R <owner>/<repo>
   git fetch origin <default>
   git rebase origin/<default>
   ```

2. If rebase succeeds, push safely:
   ```sh
   git push --force-with-lease
   ```

3. If rebase conflicts occur, stop batch processing and report:
   - PR number and branch name
   - conflicted files
   - exact command to resume after manual conflict resolution

   Do not auto-resolve ambiguous conflicts.

### 5. Final summary

Print a concise report:

- PRs merged (number + URL)
- PRs skipped (with reason)
- First blocking PR (if any)
- Whether batch completed fully or stopped early

If stopped early, recommend resuming with only remaining PR numbers after fixing the blocker.
