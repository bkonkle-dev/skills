```
                              *
            /\               /\
           /  \      *      /  \
    *     /    \       /\  /    \
         /      \     /  \/      \        *
   /\   /   /\   \   /    \      \
  /  \ /   /  \   \ /      \   /\ \
 /    \/  /    \   /   /\   \ /  \ \
/______\_/______\_/___/  \___/____\_\__
        ~    ~  bkonkle-dev/skills
```

# Skills

> Reusable [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills for autonomous
> development workflows — issue triage, PR shepherding, session memory, and more.
>
> _From Colorado, with love._

Skills are slash commands that teach Claude Code _how_ to do complex, multi-step tasks. They're
plain Markdown files with structured instructions — readable by humans, executable by bots. Think of
them as detailed route guides: clear enough for anyone to follow, thorough enough to get the job
done without hand-holding.

This repo is designed for a **worktree-based workflow**: multiple Claude Code sessions running in
parallel via `git worktree`, each on its own branch and its own path forward.

## Quick Start

### Linux / macOS

```sh
git clone git@github.com:bkonkle-dev/skills.git ~/code/bkonkle/skills
cd ~/code/bkonkle/skills
./setup.sh
```

To install a single skill:

```sh
./install-skill.sh <skill-name>
```

### Windows

**Git Bash (recommended)** — works without elevated privileges:

```sh
git clone git@github.com:bkonkle-dev/skills.git ~/code/bkonkle/skills
cd ~/code/bkonkle/skills
bash setup.sh
```

To install a single skill:

```sh
bash install-skill.sh <skill-name>
```

**PowerShell** — requires Developer Mode (Settings > For developers) or an elevated (admin) prompt:

```powershell
git clone git@github.com:bkonkle-dev/skills.git ~\code\bkonkle\skills
cd ~\code\bkonkle\skills
.\setup.ps1
```

To install a single skill:

```powershell
.\install-skill.ps1 <skill-name>
```

---

Skills are symlinked into `~/.claude/skills/`, so changes to this repo are reflected immediately —
pull the repo and you're up to date. No reinstall needed.

## Skills

| Skill | Command | What it does |
|-------|---------|-------------|
| **AWS Cost Check** | `/aws-cost-check` | Audits your AWS account for runaway costs, forgotten resources, and free tier overages |
| **Cleanup** | `/cleanup` | Prunes stale branches, checks for uncommitted work, reminds about session memories |
| **Pick Up Issue** | `/pick-up-issue` | Finds an unassigned issue, claims it, implements a fix, opens a PR, and shepherds it to merge |
| **Preflight** | `/preflight` | Validates repo identity, branch state, CI health, and open PRs before you start work |
| **Session Memory** | `/session-memory` | Creates structured memory files so future sessions can learn from past decisions |
| **Shepherd to Merge** | `/shepherd-to-merge` | Reviews a PR, addresses feedback, fixes CI, rebases, and enables auto-merge |

### Lifecycle

These skills aren't standalone — they compose into a full development lifecycle:

```
                          ___
                         /   \
                        / imp- \
                       / lement \
  /preflight  →  /pick-up-issue  →  /shepherd-to-merge  →  /cleanup
       ↑                                                       |
       └───────────────────────────────────────────────────────┘
```

`/session-memory` runs alongside any of these, preserving context across sessions so nothing learned
gets lost between runs.

## Extras

- **`statusline/statusline.sh`** — CLI statusline showing session name, context %, cost, and model.
  Detects worktree names from `.claude/worktrees/<name>/` paths.
- **`hooks/`** — Hook scripts (empty for now — add hooks as needed).

## Updating

```sh
cd ~/code/bkonkle/skills && git pull
```

Since skills are symlinked, existing ones update automatically. Run `./setup.sh` (or `.\setup.ps1`
on Windows) again only to pick up newly added skills or hooks.

## Writing New Skills

A skill is a directory under `skills/` containing a `SKILL.md` file with YAML frontmatter:

```markdown
---
name: my-skill
description: One-line description shown in /help
argument-hint: <optional args>
---

# My Skill

Instructions go here. Write them like you're onboarding a sharp colleague
who's never seen the codebase — enough context to be autonomous, not so
much that it's a novel.
```

After adding a new skill, run `./setup.sh` (or `.\setup.ps1` on Windows) to symlink it into
`~/.claude/skills/`.

Good skills are **specific**, **sequential**, and **verifiable** — they tell the agent what to do,
in what order, and how to know it worked.

## Common Pitfalls

Recurring friction patterns from real-world multi-agent usage:

| Problem | Cause | Fix |
|---------|-------|-----|
| Wrong repo targeted | Agent derived repo from wrong remote | Use explicit `owner/repo` argument |
| Push to wrong branch | Didn't verify tracking before push | Run `git branch -vv` before pushing |
| CI won't trigger | Stale workflow YAML on branch | Rebase onto latest main |
| Worktree branch conflict | Tried to switch to `main` | Use `claude/<worktree-name>` instead |
| Cache misses after runner change | Mixed cache actions | Use repo's standard cache action consistently |
| Repeated work | Didn't check prior sessions | Read `docs/agent-sessions/` and use `/recall` |
| Stranded session memories | Memory committed to worktree branch, not in PR | Finalize memory before shepherding; `/cleanup` checks for orphans |

## CLAUDE.md Integration

Skills are generic — they work across repos. For repo-specific behavior, add context to the repo's
`CLAUDE.md` or `AGENTS.md`:

- **Repository identity** — correct org/repo name to prevent wrong-repo targeting
- **CI architecture** — runner type, cache action, build constraints
- **Branch conventions** — naming patterns, protected branches
- **Verification commands** — test/lint/build commands for the project's toolchain

Skills like `/preflight` read `CLAUDE.md` to validate architecture constraints, so keeping it
accurate directly reduces agent mistakes.

## License

MIT
