#!/bin/bash
set -euo pipefail

# ── Skills repo installer ──────────────────────────────────────────────
# Symlinks skills, statusline, and hooks from this repo into ~/.claude/
# and ~/.codex/.
# Idempotent — safe to run repeatedly.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_ROOTS=("$HOME/.claude" "$HOME/.codex")

install_link() {
  local src="$1"
  local dst="$2"

  if [ -L "$dst" ]; then
    ln -sf "$src" "$dst"
  elif [ -e "$dst" ]; then
    echo "Backing up existing $dst -> ${dst}.bak"
    mv "$dst" "${dst}.bak"
    ln -s "$src" "$dst"
  else
    ln -s "$src" "$dst"
  fi
}

for target_root in "${TARGET_ROOTS[@]}"; do
  mkdir -p "$target_root/skills" "$target_root/hooks"

  statusline_src="$SCRIPT_DIR/statusline/statusline.sh"
  statusline_dst="$target_root/statusline.sh"
  if [ -f "$statusline_src" ]; then
    install_link "$statusline_src" "$statusline_dst"
    echo "✓ ${target_root##*/}/statusline -> $statusline_src"
  fi

  for skill_dir in "$SCRIPT_DIR/skills"/*/; do
    skill_name="$(basename "$skill_dir")"
    install_link "$skill_dir" "$target_root/skills/$skill_name"
    echo "✓ ${target_root##*/}/skill/$skill_name -> $skill_dir"
  done

  for hook_file in "$SCRIPT_DIR/hooks"/*; do
    [ -f "$hook_file" ] || continue
    hook_name="$(basename "$hook_file")"
    install_link "$hook_file" "$target_root/hooks/$hook_name"
    echo "✓ ${target_root##*/}/hook/$hook_name -> $hook_file"
  done
done

echo ""
echo "Done. Skills installed via symlinks from:"
echo "  $SCRIPT_DIR"
echo ""
echo "Targets: ${TARGET_ROOTS[*]}"
echo "To update skills, pull this repo — symlinks auto-reflect changes."
echo "To add a new skill, run setup.sh again after adding it."
