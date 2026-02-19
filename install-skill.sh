#!/bin/bash
set -euo pipefail

# ── Single skill installer ──────────────────────────────────────────────
# Symlinks one skill from this repo into ~/.claude/skills/ and ~/.codex/skills/.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_ROOTS=("$HOME/.claude" "$HOME/.codex")
SKILLS_DIR="$SCRIPT_DIR/skills"

usage() {
  echo "Usage: $0 <skill-name>"
  echo ""
  echo "Available skills:"
  for skill_dir in "$SKILLS_DIR"/*/; do
    name="$(basename "$skill_dir")"
    desc=$(grep '^description:' "$skill_dir/SKILL.md" 2>/dev/null | sed 's/^description:[[:space:]]*//')
    printf "  %-20s %s\n" "$name" "$desc"
  done
  exit 1
}

if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  usage
fi

skill_name="$1"
src="$SKILLS_DIR/$skill_name"

if [ ! -d "$src" ]; then
  echo "Error: skill '$skill_name' not found in $SKILLS_DIR/"
  echo ""
  usage
fi

for target_root in "${TARGET_ROOTS[@]}"; do
  mkdir -p "$target_root/skills"
  dst="$target_root/skills/$skill_name"

  if [ -L "$dst" ]; then
    ln -sf "$src" "$dst"
  elif [ -d "$dst" ]; then
    echo "Backing up existing $dst -> ${dst}.bak"
    mv "$dst" "${dst}.bak"
    ln -s "$src" "$dst"
  else
    ln -s "$src" "$dst"
  fi

  echo "✓ ${target_root##*/}/skill/$skill_name -> $src"
done
