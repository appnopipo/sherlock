#!/bin/bash
# parse-config.sh — Reads .sherlock.yml and outputs shell-friendly config
# Compatible with bash 3.2 (macOS). Handles flat keys and simple lists.
#
# Usage:
#   eval "$(parse-config.sh)"              # source all config as shell vars
#   parse-config.sh --get chunk_threshold  # get a single value
#   parse-config.sh --get ignore_patterns  # get list as newline-separated string
#
# Config search order (first found wins):
#   1. .sherlock.yml
#   2. .sherlock.yaml
#   3. .sherlock/config.yml
#
# Output format:
#   SHERLOCK_CHUNK_THRESHOLD=300
#   SHERLOCK_MAX_CHUNK_LINES=500
#   SHERLOCK_DIFF_CONTEXT=3
#   SHERLOCK_IGNORE_PATTERNS="*.stories.tsx
#   migrations/*"

set -euo pipefail

# Find config file
CONFIG_FILE=""
for candidate in ".sherlock.yml" ".sherlock.yaml" ".sherlock/config.yml"; do
  if [ -f "$candidate" ]; then
    CONFIG_FILE="$candidate"
    break
  fi
done

# Defaults
DEF_CHUNK_THRESHOLD=300
DEF_MAX_CHUNK_LINES=500
DEF_DIFF_CONTEXT=3
DEF_IGNORE_PATTERNS=""

# If no config file, output defaults and exit
if [ -z "$CONFIG_FILE" ]; then
  if [ "${1:-}" = "--get" ]; then
    key="${2:-}"
    case "$key" in
      chunk_threshold)   echo "$DEF_CHUNK_THRESHOLD" ;;
      max_chunk_lines)   echo "$DEF_MAX_CHUNK_LINES" ;;
      diff_context)      echo "$DEF_DIFF_CONTEXT" ;;
      ignore_patterns)   echo "" ;;
      *)                 echo "" ;;
    esac
  else
    echo "SHERLOCK_CHUNK_THRESHOLD=$DEF_CHUNK_THRESHOLD"
    echo "SHERLOCK_MAX_CHUNK_LINES=$DEF_MAX_CHUNK_LINES"
    echo "SHERLOCK_DIFF_CONTEXT=$DEF_DIFF_CONTEXT"
    echo "SHERLOCK_IGNORE_PATTERNS=''"
  fi
  exit 0
fi

# Parse the YAML file
# We support:
#   key: value          → flat key-value
#   key:                → start of list
#     - item            → list item
# Lines starting with # are comments

current_key=""
in_list=0
list_values=""

CHUNK_THRESHOLD="$DEF_CHUNK_THRESHOLD"
MAX_CHUNK_LINES="$DEF_MAX_CHUNK_LINES"
DIFF_CONTEXT="$DEF_DIFF_CONTEXT"
IGNORE_PATTERNS=""

flush_list() {
  if [ "$in_list" -eq 1 ] && [ -n "$current_key" ]; then
    case "$current_key" in
      ignore_patterns) IGNORE_PATTERNS="$list_values" ;;
    esac
  fi
  in_list=0
  current_key=""
  list_values=""
}

while IFS= read -r line; do
  # Skip empty lines and comments
  stripped=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  case "$stripped" in
    ""|\#*) continue ;;
  esac

  # Check if this is a list item (starts with -)
  if echo "$line" | grep -q '^[[:space:]]\{1,\}-' ; then
    if [ "$in_list" -eq 1 ]; then
      item=$(echo "$stripped" | sed 's/^-[[:space:]]*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')
      if [ -n "$list_values" ]; then
        list_values="$list_values
$item"
      else
        list_values="$item"
      fi
    fi
    continue
  fi

  # Not a list item — flush any pending list
  flush_list

  # Parse key: value
  key=$(echo "$stripped" | sed 's/:.*//')
  value=$(echo "$stripped" | sed 's/^[^:]*://' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')

  # Remove quotes from value
  value=$(echo "$value" | sed 's/^["'"'"']//' | sed 's/["'"'"']$//')

  if [ -z "$value" ]; then
    # Key with no value — start of a list
    current_key="$key"
    in_list=1
    list_values=""
  else
    # Flat key-value
    case "$key" in
      chunk_threshold)   CHUNK_THRESHOLD="$value" ;;
      max_chunk_lines)   MAX_CHUNK_LINES="$value" ;;
      diff_context)      DIFF_CONTEXT="$value" ;;
    esac
  fi
done < "$CONFIG_FILE"

# Flush any remaining list
flush_list

# Output
if [ "${1:-}" = "--get" ]; then
  key="${2:-}"
  case "$key" in
    chunk_threshold)   echo "$CHUNK_THRESHOLD" ;;
    max_chunk_lines)   echo "$MAX_CHUNK_LINES" ;;
    diff_context)      echo "$DIFF_CONTEXT" ;;
    ignore_patterns)   echo "$IGNORE_PATTERNS" ;;
    *)                 echo "" ;;
  esac
else
  # Escape newlines in IGNORE_PATTERNS for safe eval
  # Use single quotes to prevent glob expansion during eval
  ESCAPED_PATTERNS=$(echo "$IGNORE_PATTERNS" | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  echo "SHERLOCK_CHUNK_THRESHOLD=$CHUNK_THRESHOLD"
  echo "SHERLOCK_MAX_CHUNK_LINES=$MAX_CHUNK_LINES"
  echo "SHERLOCK_DIFF_CONTEXT=$DIFF_CONTEXT"
  echo "SHERLOCK_IGNORE_PATTERNS='$ESCAPED_PATTERNS'"
fi
