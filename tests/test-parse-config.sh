#!/bin/bash
# test-parse-config.sh — Tests for parse-config.sh

PARSE="$SHERLOCK_DIR/scripts/parse-config.sh"
CFGDIR="$TEST_TMPDIR/config-tests"
mkdir -p "$CFGDIR"

# Helper: run parse-config in a specific directory
parse_in() {
  local dir="$1"
  shift
  (cd "$dir" && "$PARSE" "$@")
}

# ============================================================
# Defaults (no config file)
# ============================================================

DEFAULTS=$(parse_in "$CFGDIR")
assert_contains "default: chunk_threshold=300" "$DEFAULTS" "SHERLOCK_CHUNK_THRESHOLD=300"
assert_contains "default: max_chunk_lines=500" "$DEFAULTS" "SHERLOCK_MAX_CHUNK_LINES=500"
assert_contains "default: diff_context=3" "$DEFAULTS" "SHERLOCK_DIFF_CONTEXT=3"
assert_contains "default: empty ignore_patterns" "$DEFAULTS" "SHERLOCK_IGNORE_PATTERNS=''"

# --get mode with no config
assert_eq "default --get chunk_threshold" "300" "$(parse_in "$CFGDIR" --get chunk_threshold)"
assert_eq "default --get max_chunk_lines" "500" "$(parse_in "$CFGDIR" --get max_chunk_lines)"
assert_eq "default --get diff_context" "3" "$(parse_in "$CFGDIR" --get diff_context)"
assert_eq "default --get ignore_patterns" "" "$(parse_in "$CFGDIR" --get ignore_patterns)"
assert_eq "default --get unknown key" "" "$(parse_in "$CFGDIR" --get nonexistent)"

# ============================================================
# Flat key-value config
# ============================================================

FLAT_DIR="$CFGDIR/flat"
mkdir -p "$FLAT_DIR"
cat > "$FLAT_DIR/.sherlock.yml" << 'YML'
chunk_threshold: 500
max_chunk_lines: 800
diff_context: 5
YML

OUTPUT=$(parse_in "$FLAT_DIR")
assert_contains "flat: chunk_threshold=500" "$OUTPUT" "SHERLOCK_CHUNK_THRESHOLD=500"
assert_contains "flat: max_chunk_lines=800" "$OUTPUT" "SHERLOCK_MAX_CHUNK_LINES=800"
assert_contains "flat: diff_context=5" "$OUTPUT" "SHERLOCK_DIFF_CONTEXT=5"

assert_eq "flat --get chunk_threshold" "500" "$(parse_in "$FLAT_DIR" --get chunk_threshold)"

# ============================================================
# List values (ignore_patterns)
# ============================================================

LIST_DIR="$CFGDIR/list"
mkdir -p "$LIST_DIR"
cat > "$LIST_DIR/.sherlock.yml" << 'YML'
ignore_patterns:
  - "*.stories.tsx"
  - "migrations/*"
  - "*.snap"
YML

PATTERNS=$(parse_in "$LIST_DIR" --get ignore_patterns)
assert_contains "list: has *.stories.tsx" "$PATTERNS" "*.stories.tsx"
assert_contains "list: has migrations/*" "$PATTERNS" "migrations/*"
assert_contains "list: has *.snap" "$PATTERNS" "*.snap"

# ============================================================
# Mixed config (flat + lists)
# ============================================================

MIX_DIR="$CFGDIR/mixed"
mkdir -p "$MIX_DIR"
cat > "$MIX_DIR/.sherlock.yml" << 'YML'
chunk_threshold: 999
diff_context: 1

ignore_patterns:
  - "dist/*"
  - "*.min.js"

max_chunk_lines: 777
YML

OUTPUT=$(parse_in "$MIX_DIR")
assert_contains "mixed: chunk_threshold" "$OUTPUT" "SHERLOCK_CHUNK_THRESHOLD=999"
assert_contains "mixed: max_chunk_lines" "$OUTPUT" "SHERLOCK_MAX_CHUNK_LINES=777"
assert_contains "mixed: diff_context" "$OUTPUT" "SHERLOCK_DIFF_CONTEXT=1"

PATTERNS=$(parse_in "$MIX_DIR" --get ignore_patterns)
assert_contains "mixed: has dist/*" "$PATTERNS" "dist/*"
assert_contains "mixed: has *.min.js" "$PATTERNS" "*.min.js"

# ============================================================
# Comments and blank lines
# ============================================================

COMMENT_DIR="$CFGDIR/comments"
mkdir -p "$COMMENT_DIR"
cat > "$COMMENT_DIR/.sherlock.yml" << 'YML'
# This is a comment
chunk_threshold: 42

# Another comment

diff_context: 7
YML

assert_eq "comments: chunk_threshold" "42" "$(parse_in "$COMMENT_DIR" --get chunk_threshold)"
assert_eq "comments: diff_context" "7" "$(parse_in "$COMMENT_DIR" --get diff_context)"

# ============================================================
# Alternate file locations
# ============================================================

# .sherlock.yaml
YAML_DIR="$CFGDIR/yaml-ext"
mkdir -p "$YAML_DIR"
cat > "$YAML_DIR/.sherlock.yaml" << 'YML'
chunk_threshold: 111
YML
assert_eq "alt: .sherlock.yaml" "111" "$(parse_in "$YAML_DIR" --get chunk_threshold)"

# .sherlock/config.yml
NESTED_DIR="$CFGDIR/nested"
mkdir -p "$NESTED_DIR/.sherlock"
cat > "$NESTED_DIR/.sherlock/config.yml" << 'YML'
chunk_threshold: 222
YML
assert_eq "alt: .sherlock/config.yml" "222" "$(parse_in "$NESTED_DIR" --get chunk_threshold)"

# Priority: .sherlock.yml wins over .sherlock.yaml
PRIO_DIR="$CFGDIR/priority"
mkdir -p "$PRIO_DIR"
echo "chunk_threshold: 10" > "$PRIO_DIR/.sherlock.yml"
echo "chunk_threshold: 20" > "$PRIO_DIR/.sherlock.yaml"
assert_eq "priority: .yml wins over .yaml" "10" "$(parse_in "$PRIO_DIR" --get chunk_threshold)"

# ============================================================
# Glob safety (patterns with * should not expand)
# ============================================================

GLOB_DIR="$CFGDIR/glob"
mkdir -p "$GLOB_DIR"
# Create files that could match globs
touch "$GLOB_DIR/foo.stories.tsx" "$GLOB_DIR/bar.stories.tsx"
cat > "$GLOB_DIR/.sherlock.yml" << 'YML'
ignore_patterns:
  - "*.stories.tsx"
YML

# eval should not expand the glob
OUTPUT=$(parse_in "$GLOB_DIR")
eval "$OUTPUT"
assert_eq "glob safe: no expansion" '*.stories.tsx' "$SHERLOCK_IGNORE_PATTERNS"

# ============================================================
# Partial config (only some keys)
# ============================================================

PARTIAL_DIR="$CFGDIR/partial"
mkdir -p "$PARTIAL_DIR"
echo "diff_context: 10" > "$PARTIAL_DIR/.sherlock.yml"

OUTPUT=$(parse_in "$PARTIAL_DIR")
assert_contains "partial: specified key" "$OUTPUT" "SHERLOCK_DIFF_CONTEXT=10"
assert_contains "partial: default chunk_threshold" "$OUTPUT" "SHERLOCK_CHUNK_THRESHOLD=300"
assert_contains "partial: default max_chunk_lines" "$OUTPUT" "SHERLOCK_MAX_CHUNK_LINES=500"

# ============================================================
# Quoted values
# ============================================================

QUOTE_DIR="$CFGDIR/quoted"
mkdir -p "$QUOTE_DIR"
cat > "$QUOTE_DIR/.sherlock.yml" << 'YML'
chunk_threshold: "600"
ignore_patterns:
  - '*.snap'
  - "*.stories.tsx"
YML

assert_eq "quoted: numeric value" "600" "$(parse_in "$QUOTE_DIR" --get chunk_threshold)"
PATTERNS=$(parse_in "$QUOTE_DIR" --get ignore_patterns)
assert_contains "quoted: single-quoted pattern" "$PATTERNS" "*.snap"
assert_contains "quoted: double-quoted pattern" "$PATTERNS" "*.stories.tsx"
