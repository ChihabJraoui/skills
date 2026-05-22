#!/usr/bin/env bash
#
# link-skills.sh — symlink every skill in this repo into ~/.claude/skills/
#
# This repo is the source of truth for my personal skills. Running this script
# creates a symlink in the Claude skills directory for each SKILL.md found here,
# so edits in the repo take effect live (no copy step, no drift).
#
# Usage:
#   ./link-skills.sh            # link into ~/.claude/skills
#   CLAUDE_SKILLS_DIR=/path ./link-skills.sh   # link into a custom dir
#
# Re-running is safe (idempotent). Real (non-symlink) entries are never clobbered.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"

mkdir -p "$TARGET_DIR"

linked=0
skipped=0

while IFS= read -r skill_md; do
  skill_dir="$(dirname "$skill_md")"
  name="$(basename "$skill_dir")"
  link="$TARGET_DIR/$name"

  if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "skip:   $name  (a real file/dir already exists at $link)"
    skipped=$((skipped + 1))
    continue
  fi

  ln -sfn "$skill_dir" "$link"
  echo "linked: $name  ->  $skill_dir"
  linked=$((linked + 1))
done < <(find "$REPO_DIR" -name SKILL.md -not -path '*/.git/*' | sort)

echo ""
echo "Done. $linked linked, $skipped skipped, into $TARGET_DIR"
