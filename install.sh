#!/bin/bash
# Sherlock — Multi-target install via granular symlinks
# Supports: Claude Code, Roo Code, or both simultaneously
# Compatible with Alfred (claude-codequality-toolkit)
#
# Usage:
#   ./install.sh /path/to/project              # Auto-detect targets
#   ./install.sh /path/to/project --claude      # Force Claude Code only
#   ./install.sh /path/to/project --roo         # Force Roo Code only
#   ./install.sh /path/to/project --all         # Install for both

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "Usage: ./install.sh /path/to/project [--claude|--roo|--all]"
  echo ""
  echo "Options:"
  echo "  --claude    Install for Claude Code only"
  echo "  --roo       Install for Roo Code only"
  echo "  --all       Install for both Claude Code and Roo Code"
  echo "  (default)   Auto-detect based on existing .claude/ or .roo/ directories"
  exit 1
fi

PROJECT="$1"
SHERLOCK_DIR="$(cd "$(dirname "$0")" && pwd)"
FORCE_TARGET="${2:-}"

if [ ! -d "$PROJECT" ]; then
  echo "ERROR: Directory $PROJECT does not exist"
  exit 1
fi

# ============================================================
# Detect targets
# ============================================================

install_claude=false
install_roo=false

case "$FORCE_TARGET" in
  --claude) install_claude=true ;;
  --roo)    install_roo=true ;;
  --all)    install_claude=true; install_roo=true ;;
  "")
    # Auto-detect: check for existing directories or config files
    if [ -d "$PROJECT/.claude" ] || [ -f "$PROJECT/.claude/settings.local.json" ]; then
      install_claude=true
    fi
    if [ -d "$PROJECT/.roo" ] || [ -f "$PROJECT/.roomodes" ] || [ -f "$PROJECT/.roorules" ]; then
      install_roo=true
    fi
    # If neither detected, default to Claude Code
    if ! $install_claude && ! $install_roo; then
      install_claude=true
    fi
    ;;
  *)
    echo "ERROR: Unknown option $FORCE_TARGET"
    echo "Use --claude, --roo, or --all"
    exit 1
    ;;
esac

echo "========================================="
echo "Sherlock Installer"
echo "========================================="
echo ""

TARGETS=""
$install_claude && TARGETS="Claude Code"
$install_roo && { [ -n "$TARGETS" ] && TARGETS="$TARGETS + Roo Code" || TARGETS="Roo Code"; }
echo "Targets: $TARGETS"
echo "Project: $PROJECT"
echo ""

# ============================================================
# Scripts — always installed to .sherlock/scripts/ (neutral path)
# ============================================================

mkdir -p "$PROJECT/.sherlock/scripts"

SCRIPTS=0
for script in "$SHERLOCK_DIR/scripts"/*.sh; do
  [ -f "$script" ] || continue
  ln -sf "$script" "$PROJECT/.sherlock/scripts/$(basename "$script")"
  echo "  + script: $(basename "$script")"
  SCRIPTS=$((SCRIPTS + 1))
done

# ============================================================
# Install commands and rules for each target
# ============================================================

install_commands_and_rules() {
  local target_dir="$1"
  local target_name="$2"

  mkdir -p "$target_dir/commands" "$target_dir/rules"

  echo ""
  echo "  [$target_name]"

  # Symlink commands
  local cmds=0
  for cmd in "$SHERLOCK_DIR/commands"/*.md; do
    [ -f "$cmd" ] || continue
    ln -sf "$cmd" "$target_dir/commands/$(basename "$cmd")"
    echo "    + command: /$(basename "$cmd" .md)"
    cmds=$((cmds + 1))
  done

  # Symlink rules
  local rules=0
  for rule in "$SHERLOCK_DIR/rules"/*.md; do
    [ -f "$rule" ] || continue
    ln -sf "$rule" "$target_dir/rules/$(basename "$rule")"
    echo "    + rule: $(basename "$rule")"
    rules=$((rules + 1))
  done

  echo "    ($cmds commands, $rules rules)"
}

TOTAL_CMDS=0

# --- Claude Code ---
if $install_claude; then
  install_commands_and_rules "$PROJECT/.claude" "Claude Code"

  # Merge settings.local.json permissions
  echo ""
  if [ -f "$PROJECT/.claude/settings.local.json" ]; then
    echo "  Merging permissions into existing .claude/settings.local.json..."
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
    mkdir -p "$PROJECT/.claude"
    cp "$SHERLOCK_DIR/settings.local.json" "$PROJECT/.claude/settings.local.json"
    echo "  Created .claude/settings.local.json"
  fi
fi

# --- Roo Code ---
if $install_roo; then
  install_commands_and_rules "$PROJECT/.roo" "Roo Code"

  # Create .roomodes with Sherlock mode (if not exists)
  if [ ! -f "$PROJECT/.roomodes" ]; then
    cat > "$PROJECT/.roomodes" <<'ROOMODES'
customModes:
  - slug: sherlock
    name: Sherlock Review
    description: PR code review with token-efficient analysis
    roleDefinition: >
      You are Sherlock, a code review specialist focused on performance and
      token economy. You review PR diffs using pre-computed data from bash
      scripts, analyzing against 5 categories: Logic, Security, Performance,
      Maintainability, and Testing.
    groups:
      - read
      - command
    customInstructions: >
      Follow the rules in .roo/rules/ for severity classification and
      token economy. Always run .sherlock/scripts/collect-pr-data.sh before
      analyzing. Never read full source files — use the filtered diff only.
ROOMODES
    echo ""
    echo "  Created .roomodes with 'sherlock' custom mode"
  else
    echo ""
    echo "  .roomodes already exists — you may want to add the 'sherlock' mode manually"
    echo "  See: $SHERLOCK_DIR/USAGE.md for Roo Code mode configuration"
  fi
fi

# ============================================================
# Gitignore
# ============================================================

GITIGNORE_ENTRIES=(".review/" ".sherlock/")
for entry in "${GITIGNORE_ENTRIES[@]}"; do
  if [ -f "$PROJECT/.gitignore" ]; then
    if ! grep -q "^\\${entry}" "$PROJECT/.gitignore" 2>/dev/null; then
      echo "" >> "$PROJECT/.gitignore"
      echo "# Sherlock" >> "$PROJECT/.gitignore"
      echo "$entry" >> "$PROJECT/.gitignore"
    fi
  fi
done

if [ ! -f "$PROJECT/.gitignore" ]; then
  printf "# Sherlock\n.review/\n.sherlock/\n" > "$PROJECT/.gitignore"
  echo "  Created .gitignore"
fi

# ============================================================
# Summary
# ============================================================

echo ""
echo "========================================="
echo "Sherlock installed successfully!"
echo "  Targets: $TARGETS"
echo "  $SCRIPTS scripts (in .sherlock/scripts/)"
echo ""
echo "Commands available:"
echo "  /review          Full PR review (terminal output)"
echo "  /review-pr       Full PR review (inline comments on GitHub/Bitbucket)"
echo "  /review-quick    Ultra-fast gate check"
echo "  /review-commit   Review specific commit(s)"
$install_roo && echo "" && echo "Roo Code: use 'sherlock' mode or run commands directly"
echo "========================================="
