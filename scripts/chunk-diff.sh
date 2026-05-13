#!/bin/bash
# chunk-diff.sh — Splits a filtered diff into reviewable chunks
# Groups files by directory proximity, targeting ~500 lines per chunk.
#
# Usage: chunk-diff.sh <filtered-diff> <classified-files> [max-lines-per-chunk]
#
# Output:
#   .review/chunks/chunk-01.patch
#   .review/chunks/chunk-02.patch
#   ...
#   .review/chunks/manifest.txt  (chunk metadata for orchestration)

set -euo pipefail

DIFF_FILE="${1:?Usage: chunk-diff.sh <filtered-diff> <classified-files> [max-lines]}"
CLASSIFIED_FILE="${2:?Usage: chunk-diff.sh <filtered-diff> <classified-files> [max-lines]}"
MAX_LINES="${3:-500}"
CHUNK_DIR=".review/chunks"

rm -rf "$CHUNK_DIR"
mkdir -p "$CHUNK_DIR"

# ============================================================
# Step 1: Split the filtered diff into per-file sections
# ============================================================

TMPDIR_SPLIT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_SPLIT"' EXIT

current_out=""
file_index=0

while IFS= read -r line; do
  case "$line" in
    "diff --git "*)
      current_file=$(echo "$line" | sed 's|.*b/||')
      file_index=$((file_index + 1))
      current_out="$TMPDIR_SPLIT/$(printf '%04d' $file_index).patch"
      # Store file path as first line (metadata), then the diff line
      echo "@@FILE@@$current_file" > "$current_out"
      echo "$line" >> "$current_out"
      ;;
    *)
      if [ -n "$current_out" ]; then
        echo "$line" >> "$current_out"
      fi
      ;;
  esac
done < "$DIFF_FILE"

if [ "$file_index" -eq 0 ]; then
  echo "No files in diff — nothing to chunk."
  exit 0
fi

# ============================================================
# Step 2: Build file index (module|filepath|linecount|patchfile)
# ============================================================

FILE_INDEX="$TMPDIR_SPLIT/_index.txt"
> "$FILE_INDEX"

for patch in "$TMPDIR_SPLIT"/*.patch; do
  filepath=$(head -1 "$patch" | sed 's/^@@FILE@@//')
  linecount=$(tail -n +2 "$patch" | wc -l | tr -d ' ')
  dir=$(dirname "$filepath")
  # Normalize to top-level module directory (max 2 levels deep)
  module=$(echo "$dir" | cut -d/ -f1-2)
  echo "$module|$filepath|$linecount|$patch" >> "$FILE_INDEX"
done

# Sort by module so files in the same directory stay together
sort -t'|' -k1,1 "$FILE_INDEX" > "$FILE_INDEX.sorted"

# ============================================================
# Step 3: Group files into chunks respecting module boundaries
# ============================================================

> "$CHUNK_DIR/manifest.txt"

chunk_num=0
chunk_lines=0
chunk_patch_files=""
chunk_modules=""
prev_module=""

flush_chunk() {
  if [ -z "$chunk_patch_files" ]; then return; fi

  local chunk_name
  chunk_name=$(printf 'chunk-%02d' "$chunk_num")
  local chunk_path="$CHUNK_DIR/${chunk_name}.patch"
  > "$chunk_path"

  for pf in $chunk_patch_files; do
    tail -n +2 "$pf" >> "$chunk_path"
  done

  local actual_lines
  actual_lines=$(wc -l < "$chunk_path" | tr -d ' ')
  local file_count
  file_count=$(echo "$chunk_patch_files" | wc -w | tr -d ' ')

  echo "${chunk_name}|${file_count}|${actual_lines}|${chunk_modules}" >> "$CHUNK_DIR/manifest.txt"
}

start_new_chunk() {
  chunk_num=$((chunk_num + 1))
  chunk_lines=0
  chunk_patch_files=""
  chunk_modules=""
}

start_new_chunk

while IFS='|' read -r module filepath linecount patchfile; do
  [ -z "$filepath" ] && continue

  # If adding this file would exceed limit and we have content,
  # flush — unless same module and we haven't doubled the limit
  if [ "$chunk_lines" -gt 0 ] && [ $((chunk_lines + linecount)) -gt "$MAX_LINES" ]; then
    if [ "$module" != "$prev_module" ] || [ "$chunk_lines" -gt $((MAX_LINES * 2)) ]; then
      flush_chunk
      start_new_chunk
    fi
  fi

  chunk_patch_files="$chunk_patch_files $patchfile"
  chunk_lines=$((chunk_lines + linecount))

  # Track unique modules in this chunk
  case "$chunk_modules" in
    *"$module"*) ;;
    "")  chunk_modules="$module" ;;
    *)   chunk_modules="$chunk_modules, $module" ;;
  esac

  prev_module="$module"
done < "$FILE_INDEX.sorted"

# Flush remaining
flush_chunk

# ============================================================
# Step 4: Summary
# ============================================================

total_chunks=$(wc -l < "$CHUNK_DIR/manifest.txt" | tr -d ' ')

echo "========================================="
echo "Sherlock: Diff chunked into $total_chunks chunks"
echo "========================================="
while IFS='|' read -r name fcount lcount modules; do
  echo "  $name: $fcount files, $lcount lines [$modules]"
done < "$CHUNK_DIR/manifest.txt"
echo "========================================="
