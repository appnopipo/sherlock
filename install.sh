#!/bin/bash
# Sherlock — Install via granular symlinks
# Compatible with Alfred (claude-codequality-toolkit)
#
# Usage: ./install.sh /path/to/project

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: ./install.sh /path/to/project"
  echo "Installs Sherlock commands, scripts, and rules via symlinks."
  exit 1
fi

PROJECT="$1"
SHERLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$PROJECT" ]; then
  echo "ERROR: Directory $PROJECT does not exist"
  exit 1
fi

echo "Installing Sherlock into $PROJECT/.claude/"
echo ""

# Create directories if they don't exist
mkdir -p "$PROJECT/.claude/commands" "$PROJECT/.claude/scripts" "$PROJECT/.claude/rules"

# Symlink commands (review-* prefix — no conflict with Alfred's quality-*)
CMDS=0
for cmd in "$SHERLOCK_DIR/commands"/*.md; do
  [ -f "$cmd" ] || continue
  ln -sf "$cmd" "$PROJECT/.claude/commands/$(basename "$cmd")"
  echo "  + command: /$(basename "$cmd" .md)"
  CMDS=$((CMDS + 1))
done

# Symlink scripts
SCRIPTS=0
for script in "$SHERLOCK_DIR/scripts"/*.sh; do
  [ -f "$script" ] || continue
  ln -sf "$script" "$PROJECT/.claude/scripts/$(basename "$script")"
  echo "  + script: $(basename "$script")"
  SCRIPTS=$((SCRIPTS + 1))
done

# Symlink rules
RULES=0
for rule in "$SHERLOCK_DIR/rules"/*.md; do
  [ -f "$rule" ] || continue
  ln -sf "$rule" "$PROJECT/.claude/rules/$(basename "$rule")"
  echo "  + rule: $(basename "$rule")"
  RULES=$((RULES + 1))
done

# Merge settings.local.json permissions
echo ""
if [ -f "$PROJECT/.claude/settings.local.json" ]; then
  echo "  Merging permissions into existing settings.local.json..."
  if command -v jq >/dev/null 2>&1; then
    jq -s '
      .[0].permissions.allow = (
        (.[0].permissions.allow // []) + (.[1].permissions.allow // [])
        | unique
      ) | .[0]
    ' "$PROJECT/.claude/settings.local.json" "$SHERLOCK_DIR/settings.local.json" \
      > "$PROJECT/.claude/settings.local.json.tmp" \
    && mv "$PROJECT/.claude/settings.local.json.tmp" "$PROJECT/.claude/settings.local.json"
    echo "  Permissions merged successfully."
  else
    echo "  WARNING: jq not found. Cannot merge settings."
    echo "  Please manually merge permissions from $SHERLOCK_DIR/settings.local.json"
  fi
else
  cp "$SHERLOCK_DIR/settings.local.json" "$PROJECT/.claude/settings.local.json"
  echo "  Created settings.local.json"
fi

# Add .review/ to .gitignore if not already present
if [ -f "$PROJECT/.gitignore" ]; then
  if ! grep -q "^\.review/" "$PROJECT/.gitignore" 2>/dev/null; then
    echo "" >> "$PROJECT/.gitignore"
    echo "# Sherlock review output" >> "$PROJECT/.gitignore"
    echo ".review/" >> "$PROJECT/.gitignore"
    echo "  Added .review/ to .gitignore"
  fi
else
  echo "# Sherlock review output" > "$PROJECT/.gitignore"
  echo ".review/" >> "$PROJECT/.gitignore"
  echo "  Created .gitignore with .review/"
fi

echo ""
echo "========================================="
echo "Sherlock installed successfully!"
echo "  $CMDS commands, $SCRIPTS scripts, $RULES rules"
echo ""
echo "Commands available:"
echo "  /review          Full PR review (terminal output)"
echo "  /review-pr       Full PR review (inline comments on GitHub PR)"
echo "  /review-quick    Ultra-fast gate check"
echo "  /review-commit   Review specific commit(s)"
echo "========================================="
