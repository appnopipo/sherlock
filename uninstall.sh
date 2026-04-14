#!/bin/bash
# Sherlock — Uninstall (removes only Sherlock files, preserves Alfred)
#
# Usage: ./uninstall.sh /path/to/project

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: ./uninstall.sh /path/to/project"
  exit 1
fi

PROJECT="$1"
SHERLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Uninstalling Sherlock from $PROJECT/.claude/"
echo ""

# Remove command symlinks
for cmd in "$SHERLOCK_DIR/commands"/*.md; do
  [ -f "$cmd" ] || continue
  target="$PROJECT/.claude/commands/$(basename "$cmd")"
  if [ -L "$target" ] || [ -f "$target" ]; then
    rm -f "$target"
    echo "  - command: /$(basename "$cmd" .md)"
  fi
done

# Remove script symlinks
for script in "$SHERLOCK_DIR/scripts"/*.sh; do
  [ -f "$script" ] || continue
  target="$PROJECT/.claude/scripts/$(basename "$script")"
  if [ -L "$target" ] || [ -f "$target" ]; then
    rm -f "$target"
    echo "  - script: $(basename "$script")"
  fi
done

# Remove rule symlinks
for rule in "$SHERLOCK_DIR/rules"/*.md; do
  [ -f "$rule" ] || continue
  target="$PROJECT/.claude/rules/$(basename "$rule")"
  if [ -L "$target" ] || [ -f "$target" ]; then
    rm -f "$target"
    echo "  - rule: $(basename "$rule")"
  fi
done

# Clean up .review/ directory
if [ -d "$PROJECT/.review" ]; then
  rm -rf "$PROJECT/.review"
  echo "  - cleaned .review/ directory"
fi

echo ""
echo "Sherlock uninstalled. Other toolkit files preserved."
echo "Note: settings.local.json permissions were NOT removed (may contain shared permissions)."
