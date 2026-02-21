---
name: status
description: Dashboard of open PRs, open issues, and stuck work
argument-hint: <owner/repo> [--with-worktrees]
disable-model-invocation: true
---

# Status

Produce a concise status dashboard for a repository: open PRs, open issues, and stuck items that
need intervention.

Use this skill when you need fast situational awareness before deciding what to shepherd next.

## Input

`$ARGUMENTS` should contain:

- **Required:** `owner/repo` (for example: `my-org/my-app`).
- **Optional:** `--with-worktrees` to include local worktree branch status (if running on a machine
  that has those worktrees).

Examples:

- `/status my-org/my-app`
- `/status my-org/my-app --with-worktrees`

## Prerequisites

- `gh` CLI must be authenticated.
- If `--with-worktrees` is used, local filesystem access to worktree paths is required.

## Steps

### 1. Validate repo input

Ensure the first argument is `owner/repo`. If missing, ask the user for it. Use this value as
`repo_slug` for all commands.

### 2. Fetch open PR dashboard data

Use GraphQL so each PR includes CI, review, and auto-merge state in one request:

```sh
gh api graphql -f query='query($owner:String!, $name:String!) {
  repository(owner:$owner, name:$name) {
    pullRequests(states: OPEN, first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
      nodes {
        number
        title
        url
        isDraft
        updatedAt
        reviewDecision
        mergeStateStatus
        autoMergeRequest { enabledAt }
        commits(last: 1) {
          nodes {
            commit {
              statusCheckRollup {
                state
              }
            }
          }
        }
      }
    }
  }
}' -F owner='<owner>' -F name='<repo>'
```

Normalize each PR into:

- `PR` (`#number`)
- `Title`
- `Draft` (`yes/no`)
- `Review` (`APPROVED`, `CHANGES_REQUESTED`, `REVIEW_REQUIRED`, or `none`)
- `CI` (`SUCCESS`, `FAILURE`, `PENDING`, `ERROR`, or `none`)
- `MergeState` (GitHub merge state)
- `AutoMerge` (`enabled` or `off`)
- `Updated` (relative age)

### 3. Fetch open issue dashboard data

List open issues with assignees and labels:

```sh
gh issue list -R <owner>/<repo> --state open --limit 100 --json number,title,assignees,labels,updatedAt,url
```

Normalize each issue into:

- `Issue` (`#number`)
- `Title`
- `Assignees` (comma-separated usernames, or `unassigned`)
- `Labels` (comma-separated label names)
- `Updated` (relative age)

### 4. Detect stuck PRs

Flag PRs as stuck when any of the following is true:

1. `CI` is `FAILURE` or `ERROR`.
2. `Review` is `CHANGES_REQUESTED`.
3. `Updated` is older than 1 hour and (`CI` is not `SUCCESS` or `MergeState` is not `CLEAN`).

For each stuck PR, include one short reason line:

- `CI failing`
- `changes requested`
- `stale >1h with pending merge requirements`

### 5. Optional: include local worktree status

Only when `--with-worktrees` is present, enumerate local worktrees and show branch cleanliness:

```sh
git worktree list --porcelain
```

For each worktree path, collect:

- branch name
- whether there are uncommitted changes (`git -C <path> status --porcelain`)
- whether branch tracks a remote (`git -C <path> branch -vv | grep '^\*'`)

If `git worktree list` fails (not a repo or no worktrees), print a one-line note and continue.

### 6. Print concise report

Print, in order:

1. `Repo summary`: total open PRs, total open issues, stuck PR count.
2. `Open PRs` table sorted by most recently updated.
3. `Stuck PRs` section with reasons (or `None`).
4. `Open issues` table (top 20 by recency; include note if truncated).
5. `Worktrees` section when requested.

Keep output short and decision-oriented. The goal is to identify what needs action now.
