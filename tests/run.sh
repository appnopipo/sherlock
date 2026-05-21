#!/bin/bash
# run.sh — Sherlock test runner
# Usage: ./tests/run.sh              # run all tests
#        ./tests/run.sh classify     # run specific test suite
set -u
# Note: no set -e or pipefail — assert functions handle errors internally
# and sourced test files may have commands that return non-zero intentionally

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHERLOCK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors (if terminal supports it)
if [ -t 1 ]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN="" RED="" YELLOW="" BOLD="" RESET=""
fi

# Export for test files
export SHERLOCK_DIR
export PASS_COUNT=0
export FAIL_COUNT=0
export SKIP_COUNT=0
export TEST_LOG=""

# Shared temp dir for all tests
export TEST_TMPDIR
TEST_TMPDIR=$(mktemp -d)
trap 'rm -rf "$TEST_TMPDIR"' EXIT

# ============================================================
# Test helpers (sourced by each test file)
# ============================================================

assert() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    PASS_COUNT=$((PASS_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${GREEN}PASS${RESET}: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${RED}FAIL${RESET}: $name"
  fi
}

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${GREEN}PASS${RESET}: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${RED}FAIL${RESET}: $name (expected '$expected', got '$actual')"
  fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${GREEN}PASS${RESET}: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${RED}FAIL${RESET}: $name (not found: '$needle')"
  fi
}

assert_not_contains() {
  local name="$1" haystack="$2" needle="$3"
  if ! echo "$haystack" | grep -qF "$needle"; then
    PASS_COUNT=$((PASS_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${GREEN}PASS${RESET}: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${RED}FAIL${RESET}: $name (should not contain: '$needle')"
  fi
}

assert_file_exists() {
  local name="$1" path="$2"
  if [ -f "$path" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${GREEN}PASS${RESET}: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${RED}FAIL${RESET}: $name (file not found: $path)"
  fi
}

assert_file_not_empty() {
  local name="$1" path="$2"
  if [ -s "$path" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${GREEN}PASS${RESET}: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${RED}FAIL${RESET}: $name (file empty or missing: $path)"
  fi
}

assert_gt() {
  local name="$1" a="$2" b="$3"
  if [ "$a" -gt "$b" ]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${GREEN}PASS${RESET}: $name"
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    TEST_LOG="$TEST_LOG\n  ${RED}FAIL${RESET}: $name ($a not > $b)"
  fi
}

# Export all functions for subshells
export -f assert assert_eq assert_contains assert_not_contains assert_file_exists assert_file_not_empty assert_gt

# ============================================================
# Run tests
# ============================================================

FILTER="${1:-}"
TOTAL_SUITES=0
TOTAL_PASS=0
TOTAL_FAIL=0

run_suite() {
  local suite_file="$1"
  local suite_name
  suite_name=$(basename "$suite_file" .sh | sed 's/^test-//')

  # Reset per-suite counters
  PASS_COUNT=0
  FAIL_COUNT=0
  TEST_LOG=""

  printf "\n${BOLD}--- %s ---${RESET}\n" "$suite_name"

  # Source and run (inherits all functions and vars)
  source "$suite_file"

  printf "$TEST_LOG\n"
  TOTAL_SUITES=$((TOTAL_SUITES + 1))
  TOTAL_PASS=$((TOTAL_PASS + PASS_COUNT))
  TOTAL_FAIL=$((TOTAL_FAIL + FAIL_COUNT))
}

echo "==========================================="
echo "Sherlock Test Suite"
echo "==========================================="

# Collect test files into a list first (avoid glob issues with source/cd)
SUITE_FILES=""
for suite in "$SCRIPT_DIR"/test-*.sh; do
  [ -f "$suite" ] || continue
  suite_name=$(basename "$suite" .sh | sed 's/^test-//')
  if [ -n "$FILTER" ] && [ "$FILTER" != "$suite_name" ]; then
    continue
  fi
  SUITE_FILES="$SUITE_FILES $suite"
done

for suite in $SUITE_FILES; do
  run_suite "$suite"
done

echo ""
echo "==========================================="
if [ "$TOTAL_FAIL" -eq 0 ]; then
  printf "${GREEN}${BOLD}ALL PASSED${RESET}: %d tests across %d suites\n" "$TOTAL_PASS" "$TOTAL_SUITES"
else
  printf "${RED}${BOLD}FAILURES${RESET}: %d passed, %d failed across %d suites\n" "$TOTAL_PASS" "$TOTAL_FAIL" "$TOTAL_SUITES"
fi
echo "==========================================="

exit "$TOTAL_FAIL"
