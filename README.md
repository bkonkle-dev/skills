# Skills

Global Claude Code skills, statusline, and hooks — installed via symlinks to `~/.claude/`.

## Setup

```sh
git clone git@github.com:bkonkle-dev/skills.git ~/code/bkonkle/skills
cd ~/code/bkonkle/skills
./setup.sh
```

This creates symlinks from `~/.claude/skills/`, `~/.claude/statusline.sh`, and `~/.claude/hooks/`
pointing into this repo. Changes to the repo are reflected immediately — no reinstall needed.

To install a single skill:

```sh
./install-skill.sh <skill-name>
```

## Skills

| Skill | Description |
|-------|-------------|
| `aws-cost-check` | Comprehensive AWS account cost audit — discovers resources, flags runaway costs and free tier limits |
| `cleanup` | Clean up the current repo — prune branches, check for uncommitted work |
| `pick-up-issue` | Pick up an unassigned issue, implement it, shepherd the PR to merge |
| `preflight` | Validate repo, branch, and environment before starting work |
| `recall` | Search and load archived Claude Code transcripts from past sessions |
| `session-memory` | Create or finalize session memory files for the current working session |
| `shepherd-to-merge` | Shepherd a PR through review, feedback resolution, CI checks, and auto-merge |

## Extras

- **`statusline/statusline.sh`** — CLI statusline showing session name, context %, cost, and model.
  Detects worktree names from `.claude/worktrees/<name>/` paths.
- **`hooks/`** — Hook scripts (empty for now — add hooks as needed).

## Updating

```sh
cd ~/code/bkonkle/skills && git pull
```

Since skills are symlinked, existing skills update automatically. Run `./setup.sh` again only to
pick up newly added skills or hooks.
