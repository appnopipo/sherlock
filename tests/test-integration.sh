#!/bin/bash
# test-integration.sh — End-to-end tests for collect-pr-data.sh

COLLECT="$SHERLOCK_DIR/scripts/collect-pr-data.sh"
IDIR="$TEST_TMPDIR/integration"
mkdir -p "$IDIR"

# ============================================================
# Setup: create a temp git repo with realistic history
# ============================================================

setup_repo() {
  local repo="$1"
  mkdir -p "$repo"
  cd "$repo"
  git init -b main >/dev/null 2>&1
  git commit --allow-empty -m "init" >/dev/null 2>&1

  # Base commit: some existing files
  mkdir -p src/api src/auth src/utils src/styles
  echo 'export function old() { return 1 }' > src/api/handler.ts
  echo 'export function legacy() {}' > src/utils/helpers.ts
  git add . && git commit -m "base: initial code" >/dev/null 2>&1

  # Feature commit: changes + new files
  echo 'export function handler(req) { return req.body }' > src/api/handler.ts
  echo 'export function login(u, p) { return eval(u) }' > src/auth/login.ts
  echo 'export const config = { secret: "abc" }' > src/utils/config.ts
  echo 'body { color: red }' > src/styles/main.css

  # Lockfile
  echo '{"lockfileVersion": 3}' > package-lock.json

  git add . && git commit -m "feat: add auth module" >/dev/null 2>&1

  # Install sherlock scripts
  mkdir -p .sherlock/scripts
  cp "$SHERLOCK_DIR"/scripts/*.sh .sherlock/scripts/
  chmod +x .sherlock/scripts/*.sh
}

# ============================================================
# Test: commit mode (--commit=last)
# ============================================================

REPO="$IDIR/commit-mode"
setup_repo "$REPO"

.sherlock/scripts/collect-pr-data.sh --commit=last >/dev/null 2>&1

assert_file_exists "commit: meta.txt" "$REPO/.review/meta.txt"
assert_file_exists "commit: diff-stats.txt" "$REPO/.review/diff-stats.txt"
assert_file_exists "commit: diff-filtered.patch" "$REPO/.review/diff-filtered.patch"
assert_file_exists "commit: files-classified.txt" "$REPO/.review/files-classified.txt"
assert_file_exists "commit: commits.txt" "$REPO/.review/commits.txt"
assert_file_exists "commit: files-changed.txt" "$REPO/.review/files-changed.txt"

# Verify classifications
CLASSIFIED=$(cat "$REPO/.review/files-classified.txt")
assert_contains "commit: lockfile classified" "$CLASSIFIED" "lockfile:package-lock.json"
assert_contains "commit: style classified" "$CLASSIFIED" "style:src/styles/main.css"
assert_contains "commit: source classified" "$CLASSIFIED" "source:src/auth/login.ts"

# Verify noise filter worked
FILTERED=$(cat "$REPO/.review/diff-filtered.patch")
assert_not_contains "commit: lockfile filtered" "$FILTERED" "package-lock.json"
assert_contains "commit: source kept" "$FILTERED" "src/auth/login.ts"

# Verify stats
STATS=$(cat "$REPO/.review/diff-stats.txt")
assert_contains "commit: has total_files" "$STATS" "total_files="
assert_contains "commit: has source_files" "$STATS" "source_files="
assert_contains "commit: has diff_filtered_lines" "$STATS" "diff_filtered_lines="

# ============================================================
# Test: quick mode
# ============================================================

REPO="$IDIR/quick-mode"
setup_repo "$REPO"

.sherlock/scripts/collect-pr-data.sh --commit=last --quick >/dev/null 2>&1

assert_file_exists "quick: diff exists" "$REPO/.review/diff-filtered.patch"

LINT=$(cat "$REPO/.review/lint-results.txt")
assert_eq "quick: lint skipped" "SKIPPED: quick mode" "$LINT"

TYPES=$(cat "$REPO/.review/typecheck-results.txt")
assert_eq "quick: typecheck skipped" "SKIPPED: quick mode" "$TYPES"

# ============================================================
# Test: branch mode
# ============================================================

REPO="$IDIR/branch-mode"
setup_repo "$REPO"

# Create a feature branch
git checkout -b feature/test >/dev/null 2>&1
echo 'export function newFeature() { return 42 }' > src/api/new-endpoint.ts
git add . && git commit -m "feat: new endpoint" >/dev/null 2>&1

.sherlock/scripts/collect-pr-data.sh --base=main >/dev/null 2>&1

assert_file_exists "branch: meta.txt" "$REPO/.review/meta.txt"

META=$(cat "$REPO/.review/meta.txt")
assert_contains "branch: base=main" "$META" "base=main"

FILTERED=$(cat "$REPO/.review/diff-filtered.patch")
assert_contains "branch: new file in diff" "$FILTERED" "new-endpoint.ts"

# ============================================================
# Test: commit range (last:N)
# ============================================================

REPO="$IDIR/commit-range"
setup_repo "$REPO"

# Add another commit
echo 'export function extra() {}' > src/api/extra.ts
git add . && git commit -m "feat: extra" >/dev/null 2>&1

.sherlock/scripts/collect-pr-data.sh --commit=last:2 >/dev/null 2>&1

FILTERED=$(cat "$REPO/.review/diff-filtered.patch")
assert_contains "range: has auth/login (commit 1)" "$FILTERED" "src/auth/login.ts"
assert_contains "range: has api/extra (commit 2)" "$FILTERED" "src/api/extra.ts"

# ============================================================
# Test: with .sherlock.yml config
# ============================================================

REPO="$IDIR/with-config"
setup_repo "$REPO"

# Add a large file so diff context size actually matters
{
  for i in $(seq 1 30); do echo "line $i original content"; done
} > src/api/bigfile.ts
git add . && git commit -m "add big file" >/dev/null 2>&1
sed -i '' 's/line 15 original content/CHANGED LINE 15/' src/api/bigfile.ts
git add . && git commit -m "modify middle line" >/dev/null 2>&1

cat > .sherlock.yml << 'YML'
diff_context: 1
ignore_patterns:
  - "src/utils/*"
  - "src/styles/*"
YML

# Review last 3 commits to cover both auth and bigfile changes
.sherlock/scripts/collect-pr-data.sh --commit=last:3 >/dev/null 2>&1

FILTERED=$(cat "$REPO/.review/diff-filtered.patch")
assert_not_contains "config: utils ignored" "$FILTERED" "src/utils/config.ts"
assert_not_contains "config: styles ignored" "$FILTERED" "src/styles/main.css"
assert_contains "config: auth kept" "$FILTERED" "src/auth/login.ts"

# diff_context test: use only the bigfile commit (last:1) where context matters
echo "diff_context: 1" > .sherlock.yml
.sherlock/scripts/collect-pr-data.sh --commit=last >/dev/null 2>&1
FULL_LINES_CTX1=$(wc -l < "$REPO/.review/diff-full.patch" | tr -d ' ')
rm .sherlock.yml
.sherlock/scripts/collect-pr-data.sh --commit=last >/dev/null 2>&1
FULL_LINES_CTX3=$(wc -l < "$REPO/.review/diff-full.patch" | tr -d ' ')
assert_gt "config: context=1 smaller diff" "$FULL_LINES_CTX3" "$FULL_LINES_CTX1"

# ============================================================
# Test: chunking triggers on large diff
# ============================================================

REPO="$IDIR/chunking"
mkdir -p "$REPO"
cd "$REPO"
git init -b main >/dev/null 2>&1
git commit --allow-empty -m "init" >/dev/null 2>&1

# Create many files to exceed chunk threshold
mkdir -p src/mod-{a,b,c,d,e}
for mod in a b c d e; do
  for i in $(seq 1 5); do
    # ~20 lines each = ~500 total lines of diff
    {
      echo "// Module $mod file $i"
      for j in $(seq 1 18); do
        echo "export function func${mod}${i}_${j}() { return $j }"
      done
    } > "src/mod-$mod/file-$i.ts"
  done
done
git add . && git commit -m "feat: big change" >/dev/null 2>&1

mkdir -p .sherlock/scripts
cp "$SHERLOCK_DIR"/scripts/*.sh .sherlock/scripts/
chmod +x .sherlock/scripts/*.sh

# Use low threshold to ensure chunking
cat > .sherlock.yml << 'YML'
chunk_threshold: 50
max_chunk_lines: 100
YML

.sherlock/scripts/collect-pr-data.sh --commit=last >/dev/null 2>&1

assert_file_exists "chunk: manifest exists" "$REPO/.review/chunks/manifest.txt"
CHUNK_COUNT=$(wc -l < "$REPO/.review/chunks/manifest.txt" | tr -d ' ')
assert_gt "chunk: multiple chunks" "$CHUNK_COUNT" 1

# Verify summary mentions chunks
STATS=$(cat "$REPO/.review/diff-stats.txt")
assert_contains "chunk: stats has filtered lines" "$STATS" "diff_filtered_lines="

# ============================================================
# Test: REVIEW.md detection
# ============================================================

REPO="$IDIR/review-md"
setup_repo "$REPO"

echo "Always check for SQL injection" > REVIEW.md
git add . && git commit -m "add review guidelines" >/dev/null 2>&1

.sherlock/scripts/collect-pr-data.sh --commit=last >/dev/null 2>&1
assert_file_exists "review.md: detected" "$REPO/.review/project-review-guidelines.txt"

GUIDELINES=$(cat "$REPO/.review/project-review-guidelines.txt")
assert_contains "review.md: content copied" "$GUIDELINES" "SQL injection"
