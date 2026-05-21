#!/bin/bash
# test-chunk-diff.sh — Tests for chunk-diff.sh

CHUNK="$SHERLOCK_DIR/scripts/chunk-diff.sh"
CDIR="$TEST_TMPDIR/chunk-tests"
mkdir -p "$CDIR"

# Helper: generate a diff file section for a given path with N lines
gen_file_diff() {
  local path="$1" lines="$2"
  echo "diff --git a/$path b/$path"
  echo "--- a/$path"
  echo "+++ b/$path"
  echo "@@ -1,$lines +1,$lines @@"
  for i in $(seq 1 "$lines"); do
    echo "+line $i of $path"
  done
}

# ============================================================
# Basic chunking — two modules
# ============================================================

TDIR="$CDIR/basic"
mkdir -p "$TDIR/.review"

{
  gen_file_diff "src/api/handler.ts" 10
  gen_file_diff "src/api/router.ts" 8
  gen_file_diff "src/auth/login.ts" 12
  gen_file_diff "src/auth/register.ts" 10
} > "$TDIR/diff.patch"

cat > "$TDIR/classified.txt" << 'CLS'
source:src/api/handler.ts
source:src/api/router.ts
source:src/auth/login.ts
source:src/auth/register.ts
CLS

(cd "$TDIR" && "$CHUNK" diff.patch classified.txt 25 >/dev/null 2>&1)

assert_file_exists "basic: manifest exists" "$TDIR/.review/chunks/manifest.txt"

CHUNK_COUNT=$(wc -l < "$TDIR/.review/chunks/manifest.txt" | tr -d ' ')
assert_eq "basic: 2 chunks" "2" "$CHUNK_COUNT"

# Verify module grouping
CHUNK1_MODULES=$(head -1 "$TDIR/.review/chunks/manifest.txt" | cut -d'|' -f4)
CHUNK2_MODULES=$(tail -1 "$TDIR/.review/chunks/manifest.txt" | cut -d'|' -f4)
assert_contains "basic: chunk has src/api" "$CHUNK1_MODULES$CHUNK2_MODULES" "src/api"
assert_contains "basic: chunk has src/auth" "$CHUNK1_MODULES$CHUNK2_MODULES" "src/auth"

# Verify chunk files contain actual diff content
assert_file_not_empty "basic: chunk-01 has content" "$TDIR/.review/chunks/chunk-01.patch"
assert_file_not_empty "basic: chunk-02 has content" "$TDIR/.review/chunks/chunk-02.patch"

# ============================================================
# Same module stays together even if over limit
# ============================================================

TDIR="$CDIR/same-module"
mkdir -p "$TDIR/.review"

{
  gen_file_diff "src/api/a.ts" 10
  gen_file_diff "src/api/b.ts" 10
  gen_file_diff "src/api/c.ts" 10
} > "$TDIR/diff.patch"

cat > "$TDIR/classified.txt" << 'CLS'
source:src/api/a.ts
source:src/api/b.ts
source:src/api/c.ts
CLS

# Max 15 lines, but all files are in src/api — should stay together
(cd "$TDIR" && "$CHUNK" diff.patch classified.txt 15 >/dev/null 2>&1)

CHUNK_COUNT=$(wc -l < "$TDIR/.review/chunks/manifest.txt" | tr -d ' ')
assert_eq "same-module: 1 chunk (grouped)" "1" "$CHUNK_COUNT"

# ============================================================
# Single file edge case
# ============================================================

TDIR="$CDIR/single"
mkdir -p "$TDIR/.review"

gen_file_diff "src/only.ts" 5 > "$TDIR/diff.patch"

cat > "$TDIR/classified.txt" << 'CLS'
source:src/only.ts
CLS

(cd "$TDIR" && "$CHUNK" diff.patch classified.txt 500 >/dev/null 2>&1)

assert_file_exists "single: manifest exists" "$TDIR/.review/chunks/manifest.txt"
CHUNK_COUNT=$(wc -l < "$TDIR/.review/chunks/manifest.txt" | tr -d ' ')
assert_eq "single: 1 chunk" "1" "$CHUNK_COUNT"

# ============================================================
# Manifest format validation
# ============================================================

TDIR="$CDIR/manifest"
mkdir -p "$TDIR/.review"

{
  gen_file_diff "pkg/api/handler.go" 8
  gen_file_diff "pkg/db/store.go" 8
} > "$TDIR/diff.patch"

cat > "$TDIR/classified.txt" << 'CLS'
source:pkg/api/handler.go
source:pkg/db/store.go
CLS

(cd "$TDIR" && "$CHUNK" diff.patch classified.txt 10 >/dev/null 2>&1)

# Manifest format: chunk-name|file-count|line-count|modules
LINE=$(head -1 "$TDIR/.review/chunks/manifest.txt")
FIELDS=$(echo "$LINE" | tr '|' '\n' | wc -l | tr -d ' ')
assert_eq "manifest: 4 pipe-separated fields" "4" "$FIELDS"

NAME=$(echo "$LINE" | cut -d'|' -f1)
assert_eq "manifest: name is chunk-01" "chunk-01" "$NAME"

FCOUNT=$(echo "$LINE" | cut -d'|' -f2)
assert_eq "manifest: file count is numeric" "1" "$FCOUNT"

# ============================================================
# Many modules — proper splitting
# ============================================================

TDIR="$CDIR/many"
mkdir -p "$TDIR/.review"

{
  gen_file_diff "src/api/handler.ts" 5
  gen_file_diff "src/auth/login.ts" 5
  gen_file_diff "src/db/store.ts" 5
  gen_file_diff "src/utils/helpers.ts" 5
  gen_file_diff "src/mail/sender.ts" 5
} > "$TDIR/diff.patch"

cat > "$TDIR/classified.txt" << 'CLS'
source:src/api/handler.ts
source:src/auth/login.ts
source:src/db/store.ts
source:src/utils/helpers.ts
source:src/mail/sender.ts
CLS

(cd "$TDIR" && "$CHUNK" diff.patch classified.txt 12 >/dev/null 2>&1)

CHUNK_COUNT=$(wc -l < "$TDIR/.review/chunks/manifest.txt" | tr -d ' ')
assert_gt "many: multiple chunks created" "$CHUNK_COUNT" 1

# Verify no file is lost — all should appear in some chunk
ALL_CHUNKS=$(cat "$TDIR/.review/chunks/"*.patch)
assert_contains "many: api present" "$ALL_CHUNKS" "src/api/handler.ts"
assert_contains "many: auth present" "$ALL_CHUNKS" "src/auth/login.ts"
assert_contains "many: db present" "$ALL_CHUNKS" "src/db/store.ts"
assert_contains "many: utils present" "$ALL_CHUNKS" "src/utils/helpers.ts"
assert_contains "many: mail present" "$ALL_CHUNKS" "src/mail/sender.ts"

# ============================================================
# Empty diff
# ============================================================

TDIR="$CDIR/empty"
mkdir -p "$TDIR/.review"
> "$TDIR/diff.patch"
> "$TDIR/classified.txt"

RESULT=$(cd "$TDIR" && "$CHUNK" diff.patch classified.txt 500 2>&1)
assert_contains "empty: reports no files" "$RESULT" "nothing to chunk"
