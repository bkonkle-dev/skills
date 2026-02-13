#!/bin/bash
set -euo pipefail

# ── Skills repo installer ──────────────────────────────────────────────
# Symlinks skills, statusline, and hooks from this repo into ~/.claude/.
# Idempotent — safe to run repeatedly.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# Ensure ~/.claude/ directories exist
mkdir -p "$CLAUDE_DIR/skills" "$CLAUDE_DIR/hooks"

# ── Statusline ──────────────────────────────────────────────────────────

src="$SCRIPT_DIR/statusline/statusline.sh"
dst="$CLAUDE_DIR/statusline.sh"

if [ -L "$dst" ]; then
  # Already a symlink — update it
  ln -sf "$src" "$dst"
elif [ -f "$dst" ]; then
  echo "Backing up existing $dst → ${dst}.bak"
  mv "$dst" "${dst}.bak"
  ln -s "$src" "$dst"
else
  ln -s "$src" "$dst"
fi
echo "✓ statusline → $src"

# ── Skills ──────────────────────────────────────────────────────────────

for skill_dir in "$SCRIPT_DIR/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  src="$skill_dir"
  dst="$CLAUDE_DIR/skills/$skill_name"

  if [ -L "$dst" ]; then
    ln -sf "$src" "$dst"
  elif [ -d "$dst" ]; then
    echo "Backing up existing $dst → ${dst}.bak"
    mv "$dst" "${dst}.bak"
    ln -s "$src" "$dst"
  else
    ln -s "$src" "$dst"
  fi
  echo "✓ skill/$skill_name → $src"
done

# ── Hooks ───────────────────────────────────────────────────────────────

for hook_file in "$SCRIPT_DIR/hooks"/*; do
  [ -f "$hook_file" ] || continue
  hook_name="$(basename "$hook_file")"
  src="$hook_file"
  dst="$CLAUDE_DIR/hooks/$hook_name"

  if [ -L "$dst" ]; then
    ln -sf "$src" "$dst"
  elif [ -f "$dst" ]; then
    echo "Backing up existing $dst → ${dst}.bak"
    mv "$dst" "${dst}.bak"
    ln -s "$src" "$dst"
  else
    ln -s "$src" "$dst"
  fi
  echo "✓ hook/$hook_name → $src"
done

# ── Summary ─────────────────────────────────────────────────────────────

echo ""
echo "Done. Skills installed via symlinks from:"
echo "  $SCRIPT_DIR"
echo ""
echo "To update skills, pull this repo — symlinks auto-reflect changes."
echo "To add a new skill, run setup.sh again after adding it."
