#!/bin/bash
# Sherlock — Multi-target uninstall (removes only Sherlock files)
# Preserves Alfred, Roo Code custom modes, and other toolkit files
#
# Usage:
#   ./uninstall.sh /path/to/project              # Remove from all targets
#   ./uninstall.sh /path/to/project --claude      # Remove from Claude Code only
#   ./uninstall.sh /path/to/project --roo         # Remove from Roo Code only

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: ./uninstall.sh /path/to/project [--claude|--roo]"
  exit 1
fi

PROJECT="$1"
SHERLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${2:-}"

echo "Uninstalling Sherlock from $PROJECT"
echo ""

remove_from_target() {
  local target_dir="$1"
  local target_name="$2"

  if [ ! -d "$target_dir" ]; then
    return
  fi

  echo "  [$target_name]"

  # Remove command symlinks
  for cmd in "$SHERLOCK_DIR/commands"/*.md; do
    [ -f "$cmd" ] || continue
    local file="$target_dir/commands/$(basename "$cmd")"
    if [ -L "$file" ] || [ -f "$file" ]; then
      rm -f "$file"
      echo "    - command: /$(basename "$cmd" .md)"
    fi
  done

  # Remove rule symlinks
  for rule in "$SHERLOCK_DIR/rules"/*.md; do
    [ -f "$rule" ] || continue
    local file="$target_dir/rules/$(basename "$rule")"
    if [ -L "$file" ] || [ -f "$file" ]; then
      rm -f "$file"
      echo "    - rule: $(basename "$rule")"
    fi
  done
}

case "$TARGET" in
  --claude) remove_from_target "$PROJECT/.claude" "Claude Code" ;;
  --roo)    remove_from_target "$PROJECT/.roo" "Roo Code" ;;
  "")
    remove_from_target "$PROJECT/.claude" "Claude Code"
    remove_from_target "$PROJECT/.roo" "Roo Code"
    ;;
esac

# Remove shared scripts
if [ -d "$PROJECT/.sherlock" ]; then
  rm -rf "$PROJECT/.sherlock"
  echo ""
  echo "  - removed .sherlock/ directory"
fi

# Clean up .review/ directory
if [ -d "$PROJECT/.review" ]; then
  rm -rf "$PROJECT/.review"
  echo "  - cleaned .review/ directory"
fi

echo ""
echo "Sherlock uninstalled. Other toolkit files preserved."
echo "Note: settings.local.json and .roomodes were NOT modified (may contain shared config)."
