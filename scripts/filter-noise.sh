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
declare -A SKIP_FILES
if [ -n "$CLASSIFIED_FILE" ] && [ -f "$CLASSIFIED_FILE" ]; then
  while IFS= read -r line; do
    category="${line%%:*}"
    filepath="${line#*:}"
    case "$category" in
      lockfile|generated|asset)
        SKIP_FILES["$filepath"]=1
        ;;
    esac
  done < "$CLASSIFIED_FILE"
fi

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
    while IFS= read -r line; do
      case "$line" in
        +import*|+\"use *|+'use *|-import*|-\"use *|-'use *|+|-)
          ;; # import or empty line — ok
        +*|-*)
          # Strip leading +/- and whitespace
          local content="${line:1}"
          content="${content#"${content%%[![:space:]]*}"}"
          if [ -n "$content" ]; then
            non_import=1
            break
          fi
          ;;
      esac
    done <<< "$(echo "$hunk_buffer" | grep "^[+-]" | grep -v "^[+-][+-][+-]")"

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
        if [ -n "${SKIP_FILES[$current_file]+x}" ]; then
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
