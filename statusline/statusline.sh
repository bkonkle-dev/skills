#!/bin/bash
input=$(cat)

DIR=$(echo "$input" | jq -r '.workspace.current_dir // empty')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0' | xargs printf '%.2f')
MODEL=$(echo "$input" | jq -r '.model.display_name // empty')

# Extract session name from worktree path or fall back to basename
if [[ "$DIR" =~ \.claude/worktrees/([^/]+) ]]; then
  NAME="${BASH_REMATCH[1]}"
else
  NAME="$(basename "$DIR")"
fi

info=()
info+=("ctx: ${PCT}%")
info+=("\$${COST}")

if [ -n "$MODEL" ]; then
  info+=("$MODEL")
fi

echo "$NAME"
echo "${info[0]}$(printf ' | %s' "${info[@]:1}")"
