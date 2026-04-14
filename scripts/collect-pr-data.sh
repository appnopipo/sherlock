#!/bin/bash
# collect-pr-data.sh — Centralized PR data collection for Sherlock
# Collects all data BEFORE AI analysis to minimize token usage
#
# Usage:
#   collect-pr-data.sh [OPTIONS]
#
# Options:
#   --base=<branch>   Base branch to diff against (default: auto-detect main/master)
#   --commit=<sha>    Review specific commit (use "last" for HEAD, "last:N" for last N)
#   --quick           Skip lint/typecheck/tests — only collect diff and stats
#
# Output: .review/ directory with pre-computed data files

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REVIEW_DIR=".review"

# Parse arguments
BASE_BRANCH=""
COMMIT_MODE=""
QUICK=0

for arg in "$@"; do
  case "$arg" in
    --base=*) BASE_BRANCH="${arg#--base=}" ;;
    --commit=*) COMMIT_MODE="${arg#--commit=}" ;;
    --quick) QUICK=1 ;;
    *) BASE_BRANCH="$arg" ;;
  esac
done

# Setup output directory
rm -rf "$REVIEW_DIR"
mkdir -p "$REVIEW_DIR"

# ============================================================
# PHASE 1: Determine diff range
# ============================================================

if [ -n "$COMMIT_MODE" ]; then
  # Commit mode
  case "$COMMIT_MODE" in
    last)
      DIFF_BASE="HEAD~1"
      DIFF_HEAD="HEAD"
      RANGE_DESC="commit $(git rev-parse --short HEAD)"
      ;;
    last:*)
      N="${COMMIT_MODE#last:}"
      DIFF_BASE="HEAD~$N"
      DIFF_HEAD="HEAD"
      RANGE_DESC="last $N commits"
      ;;
    *)
      DIFF_BASE="${COMMIT_MODE}~1"
      DIFF_HEAD="$COMMIT_MODE"
      RANGE_DESC="commit $(echo "$COMMIT_MODE" | cut -c1-7)"
      ;;
  esac
else
  # Branch mode — find merge base
  if [ -z "$BASE_BRANCH" ]; then
    # Auto-detect: try main, then master
    if git rev-parse --verify main >/dev/null 2>&1; then
      BASE_BRANCH="main"
    elif git rev-parse --verify master >/dev/null 2>&1; then
      BASE_BRANCH="master"
    else
      echo "ERROR: Could not detect base branch. Use --base=<branch>" >&2
      exit 1
    fi
  fi

  MERGE_BASE=$(git merge-base HEAD "$BASE_BRANCH" 2>/dev/null || echo "")
  if [ -z "$MERGE_BASE" ]; then
    echo "ERROR: No common ancestor with $BASE_BRANCH" >&2
    exit 1
  fi

  DIFF_BASE="$MERGE_BASE"
  DIFF_HEAD="HEAD"
  RANGE_DESC="$(git rev-parse --abbrev-ref HEAD) vs $BASE_BRANCH"
fi

# ============================================================
# PHASE 2: Git data collection (sequential, fast)
# ============================================================

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
COMMIT_COUNT=$(git rev-list --count "$DIFF_BASE".."$DIFF_HEAD" 2>/dev/null || echo "0")

# Meta information
cat > "$REVIEW_DIR/meta.txt" <<EOF
branch=$CURRENT_BRANCH
base=$BASE_BRANCH
range=$RANGE_DESC
commits=$COMMIT_COUNT
date=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

# Commit log
git log --oneline "$DIFF_BASE".."$DIFF_HEAD" > "$REVIEW_DIR/commits.txt" 2>/dev/null || true

# File list with stats
git diff --stat --stat-width=200 "$DIFF_BASE".."$DIFF_HEAD" > "$REVIEW_DIR/files-changed.txt" 2>/dev/null || true

# Extract just file paths for classification
git diff --name-only "$DIFF_BASE".."$DIFF_HEAD" > "$REVIEW_DIR/files-list.txt" 2>/dev/null || true

# Classify files
if [ -f "$SCRIPT_DIR/classify-files.sh" ]; then
  "$SCRIPT_DIR/classify-files.sh" < "$REVIEW_DIR/files-list.txt" > "$REVIEW_DIR/files-classified.txt"
else
  # Fallback: mark all as source
  sed 's/^/source:/' "$REVIEW_DIR/files-list.txt" > "$REVIEW_DIR/files-classified.txt"
fi

# Full diff with reduced context (3 lines instead of default 5 — saves ~20% tokens)
git diff -U3 "$DIFF_BASE".."$DIFF_HEAD" > "$REVIEW_DIR/diff-full.patch" 2>/dev/null || true

# Filter noise from diff
if [ -f "$SCRIPT_DIR/filter-noise.sh" ]; then
  "$SCRIPT_DIR/filter-noise.sh" "$REVIEW_DIR/files-classified.txt" "$REVIEW_DIR/diff-full.patch" \
    > "$REVIEW_DIR/diff-filtered.patch"
else
  cp "$REVIEW_DIR/diff-full.patch" "$REVIEW_DIR/diff-filtered.patch"
fi

# Compute diff stats summary
TOTAL_FILES=$(wc -l < "$REVIEW_DIR/files-list.txt" | tr -d ' ')
SOURCE_FILES=$(grep -c "^source:" "$REVIEW_DIR/files-classified.txt" 2>/dev/null || echo "0")
TEST_FILES=$(grep -c "^test:" "$REVIEW_DIR/files-classified.txt" 2>/dev/null || echo "0")
CONFIG_FILES=$(grep -c "^config:" "$REVIEW_DIR/files-classified.txt" 2>/dev/null || echo "0")
LOCK_FILES=$(grep -c "^lockfile:" "$REVIEW_DIR/files-classified.txt" 2>/dev/null || echo "0")
GENERATED_FILES=$(grep -c "^generated:" "$REVIEW_DIR/files-classified.txt" 2>/dev/null || echo "0")
DOCS_FILES=$(grep -c "^docs:" "$REVIEW_DIR/files-classified.txt" 2>/dev/null || echo "0")
STYLE_FILES=$(grep -c "^style:" "$REVIEW_DIR/files-classified.txt" 2>/dev/null || echo "0")

# Count additions/deletions from source files only
ADDITIONS=$(git diff --numstat "$DIFF_BASE".."$DIFF_HEAD" -- $(grep "^source:" "$REVIEW_DIR/files-classified.txt" | cut -d: -f2-) 2>/dev/null | awk '{s+=$1} END {print s+0}')
DELETIONS=$(git diff --numstat "$DIFF_BASE".."$DIFF_HEAD" -- $(grep "^source:" "$REVIEW_DIR/files-classified.txt" | cut -d: -f2-) 2>/dev/null | awk '{s+=$1} END {print s+0}')
TOTAL_ADDITIONS=$(git diff --shortstat "$DIFF_BASE".."$DIFF_HEAD" 2>/dev/null | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
TOTAL_DELETIONS=$(git diff --shortstat "$DIFF_BASE".."$DIFF_HEAD" 2>/dev/null | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")

cat > "$REVIEW_DIR/diff-stats.txt" <<EOF
total_files=$TOTAL_FILES
source_files=$SOURCE_FILES
test_files=$TEST_FILES
config_files=$CONFIG_FILES
lock_files=$LOCK_FILES
generated_files=$GENERATED_FILES
docs_files=$DOCS_FILES
style_files=$STYLE_FILES
total_additions=$TOTAL_ADDITIONS
total_deletions=$TOTAL_DELETIONS
diff_full_lines=$(wc -l < "$REVIEW_DIR/diff-full.patch" | tr -d ' ')
diff_filtered_lines=$(wc -l < "$REVIEW_DIR/diff-filtered.patch" | tr -d ' ')
EOF

# ============================================================
# PHASE 3: Tool checks (parallel, optional)
# ============================================================

if [ "$QUICK" -eq 0 ]; then
  # Extract source file paths
  SOURCE_PATHS=$(grep "^source:" "$REVIEW_DIR/files-classified.txt" | cut -d: -f2- | tr '\n' ' ')

  if [ -n "$SOURCE_PATHS" ]; then
    # ESLint (if available) — compact format saves tokens vs JSON
    (
      if command -v npx >/dev/null 2>&1 && [ -f ".eslintrc*" ] || [ -f "eslint.config*" ] || grep -q '"eslint"' package.json 2>/dev/null; then
        npx eslint --format compact $SOURCE_PATHS 2>/dev/null > "$REVIEW_DIR/lint-results.txt" || true
      else
        echo "SKIPPED: eslint not available" > "$REVIEW_DIR/lint-results.txt"
      fi
    ) &
    LINT_PID=$!

    # TypeScript check (if available) — filter to changed files only
    (
      if command -v npx >/dev/null 2>&1 && [ -f "tsconfig.json" ]; then
        npx tsc --noEmit 2>&1 | grep -F -f "$REVIEW_DIR/files-list.txt" > "$REVIEW_DIR/typecheck-results.txt" 2>/dev/null || true
      else
        echo "SKIPPED: typescript not available" > "$REVIEW_DIR/typecheck-results.txt"
      fi
    ) &
    TSC_PID=$!

    # Test file existence check
    (
      > "$REVIEW_DIR/test-hint.txt"
      while IFS= read -r src; do
        # Common test file patterns
        local_dir=$(dirname "$src")
        local_name=$(basename "$src")
        local_base="${local_name%.*}"
        local_ext="${local_name##*.}"

        found=0
        for pattern in \
          "${local_dir}/${local_base}.test.${local_ext}" \
          "${local_dir}/${local_base}.spec.${local_ext}" \
          "${local_dir}/__tests__/${local_name}" \
          "${local_dir}/__tests__/${local_base}.test.${local_ext}" \
          "${local_dir}/../__tests__/${local_base}.test.${local_ext}"; do
          if [ -f "$pattern" ]; then
            found=1
            break
          fi
        done

        if [ "$found" -eq 0 ]; then
          echo "MISSING_TEST:$src" >> "$REVIEW_DIR/test-hint.txt"
        fi
      done <<< "$(grep "^source:" "$REVIEW_DIR/files-classified.txt" | cut -d: -f2-)"
    ) &
    TEST_PID=$!
  else
    echo "NO_SOURCE_FILES" > "$REVIEW_DIR/lint-results.txt"
    echo "NO_SOURCE_FILES" > "$REVIEW_DIR/typecheck-results.txt"
    echo "NO_SOURCE_FILES" > "$REVIEW_DIR/test-hint.txt"
  fi

  # PR metadata (if gh CLI available)
  (
    if command -v gh >/dev/null 2>&1; then
      gh pr view --json title,body,labels,number,baseRefName 2>/dev/null > "$REVIEW_DIR/pr-metadata.txt" || echo "NO_PR" > "$REVIEW_DIR/pr-metadata.txt"
    else
      echo "NO_GH_CLI" > "$REVIEW_DIR/pr-metadata.txt"
    fi
  ) &
  PR_PID=$!

  # Wait for all background jobs
  wait ${LINT_PID:-} 2>/dev/null || true
  wait ${TSC_PID:-} 2>/dev/null || true
  wait ${TEST_PID:-} 2>/dev/null || true
  wait ${PR_PID:-} 2>/dev/null || true

else
  # Quick mode — skip tool checks
  echo "SKIPPED: quick mode" > "$REVIEW_DIR/lint-results.txt"
  echo "SKIPPED: quick mode" > "$REVIEW_DIR/typecheck-results.txt"
  echo "SKIPPED: quick mode" > "$REVIEW_DIR/test-hint.txt"
  echo "SKIPPED: quick mode" > "$REVIEW_DIR/pr-metadata.txt"
fi

# ============================================================
# PHASE 4: Check for REVIEW.md (Claude Code compatibility)
# ============================================================

if [ -f "REVIEW.md" ]; then
  cp "REVIEW.md" "$REVIEW_DIR/project-review-guidelines.txt"
elif [ -f ".github/REVIEW.md" ]; then
  cp ".github/REVIEW.md" "$REVIEW_DIR/project-review-guidelines.txt"
fi

# ============================================================
# Summary
# ============================================================

FILTERED_SAVINGS=""
FULL_LINES=$(wc -l < "$REVIEW_DIR/diff-full.patch" | tr -d ' ')
FILTERED_LINES=$(wc -l < "$REVIEW_DIR/diff-filtered.patch" | tr -d ' ')
if [ "$FULL_LINES" -gt 0 ]; then
  SAVINGS=$(( (FULL_LINES - FILTERED_LINES) * 100 / FULL_LINES ))
  FILTERED_SAVINGS=" (${SAVINGS}% noise removed)"
fi

echo "========================================="
echo "Sherlock: Data collection complete"
echo "========================================="
echo "Range: $RANGE_DESC"
echo "Files: $TOTAL_FILES total ($SOURCE_FILES source, $TEST_FILES test, $LOCK_FILES lock, $GENERATED_FILES generated)"
echo "Diff: ${FULL_LINES} lines raw → ${FILTERED_LINES} lines filtered${FILTERED_SAVINGS}"
echo "Output: $REVIEW_DIR/"
echo "========================================="
