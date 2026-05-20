#!/bin/bash
# filter-noise.sh — Removes noisy diffs to save tokens
# Input: unified diff from stdin or file argument
# Output: filtered diff to stdout
#
# Removes:
#   1. Entire file diffs for lockfiles and generated files
#   2. Hunks where only imports changed
#   3. Hunks where only whitespace changed
#   4. Version-only bumps in package.json
#
# Usage: filter-noise.sh [classified-files] < diff-full.patch > diff-filtered.patch
#        filter-noise.sh [classified-files] diff-full.patch > diff-filtered.patch

CLASSIFIED_FILE="${1:-}"
DIFF_INPUT="${2:-/dev/stdin}"

# Build skip list from classified files (lockfile + generated + asset)
# Uses a newline-separated string instead of associative arrays (bash 3.2 compat)
SKIP_FILES=""
if [ -n "$CLASSIFIED_FILE" ] && [ -f "$CLASSIFIED_FILE" ]; then
  while IFS= read -r line; do
    category="${line%%:*}"
    filepath="${line#*:}"
    case "$category" in
      lockfile|generated|asset)
        SKIP_FILES="$SKIP_FILES
$filepath"
        ;;
    esac
  done < "$CLASSIFIED_FILE"
fi

# Add ignore_patterns from .sherlock.yml (passed via SHERLOCK_IGNORE_PATTERNS env var)
IGNORE_PATTERNS="${SHERLOCK_IGNORE_PATTERNS:-}"
if [ -n "$IGNORE_PATTERNS" ]; then
  # Unescape \n to real newlines
  IGNORE_PATTERNS=$(printf '%b' "$IGNORE_PATTERNS")
fi

# Check if a file matches any ignore glob pattern
matches_ignore_pattern() {
  local file="$1"
  [ -z "$IGNORE_PATTERNS" ] && return 1
  local pattern
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    # Use case for glob matching (bash 3.2 compatible)
    case "$file" in
      $pattern) return 0 ;;
    esac
  done <<EOF
$IGNORE_PATTERNS
EOF
  return 1
}

# Check if a file is in the skip list or matches an ignore pattern
is_skipped() {
  echo "$SKIP_FILES" | grep -qFx "$1" 2>/dev/null && return 0
  matches_ignore_pattern "$1"
}

# State machine to process unified diff
current_file=""
skip_current=0
hunk_buffer=""
in_hunk=0
file_header=""

flush_hunk() {
  if [ -n "$hunk_buffer" ] && [ "$skip_current" -eq 0 ]; then
    # Check if hunk is import-only or whitespace-only
    local added removed
    added=$(echo "$hunk_buffer" | grep "^+" | grep -v "^+++" || true)
    removed=$(echo "$hunk_buffer" | grep "^-" | grep -v "^---" || true)

    # Skip if no actual changes
    if [ -z "$added" ] && [ -z "$removed" ]; then
      hunk_buffer=""
      return
    fi

    # Check import-only: all added/removed lines are imports or empty
    local non_import=0
    local changed_lines
    changed_lines=$(echo "$hunk_buffer" | grep "^[+-]" | grep -v "^[+-][+-][+-]" || true)
    if [ -n "$changed_lines" ]; then
      # Filter out import lines, "use" directives, and blank +/- lines
      local remaining
      remaining=$(echo "$changed_lines" \
        | grep -v "^[+-]import " \
        | grep -v "^[+-][\"']use " \
        | grep -v "^[+-]$" \
        | sed 's/^[+-]//' \
        | sed 's/^[[:space:]]*//' \
        | grep -v "^$" || true)
      if [ -n "$remaining" ]; then
        non_import=1
      fi
    fi

    if [ "$non_import" -eq 0 ] && [ -n "$added$removed" ]; then
      hunk_buffer=""
      return
    fi

    # Check whitespace-only: stripped added == stripped removed
    local stripped_added stripped_removed
    stripped_added=$(echo "$added" | sed 's/^+//' | tr -d '[:space:]' | sort)
    stripped_removed=$(echo "$removed" | sed 's/^-//' | tr -d '[:space:]' | sort)
    if [ -n "$stripped_added" ] && [ "$stripped_added" = "$stripped_removed" ]; then
      hunk_buffer=""
      return
    fi

    # Hunk passes all filters — output it
    printf '%s\n' "$file_header"
    printf '%s\n' "$hunk_buffer"
  fi
  hunk_buffer=""
}

process_diff() {
  while IFS= read -r line; do
    case "$line" in
      "diff --git "*)
        # Flush previous hunk
        flush_hunk

        # Extract file path (b/path format)
        current_file=$(echo "$line" | sed 's|.*b/||')
        file_header="$line"
        skip_current=0

        # Check skip list
        if is_skipped "$current_file"; then
          skip_current=1
          continue
        fi

        # Check version-only bump pattern (will verify in hunk)
        ;;

      "--- "*|"+++ "*)
        if [ "$skip_current" -eq 1 ]; then continue; fi
        file_header="$file_header
$line"
        ;;

      "@@"*)
        # New hunk — flush previous
        flush_hunk
        if [ "$skip_current" -eq 1 ]; then continue; fi
        hunk_buffer="$line"
        ;;

      *)
        if [ "$skip_current" -eq 1 ]; then continue; fi
        if [ -n "$hunk_buffer" ]; then
          hunk_buffer="$hunk_buffer
$line"
        fi
        ;;
    esac
  done < "$DIFF_INPUT"

  # Flush last hunk
  flush_hunk
}

process_diff
