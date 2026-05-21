#!/bin/bash
# test-filter-noise.sh — Tests for filter-noise.sh

FILTER="$SHERLOCK_DIR/scripts/filter-noise.sh"
FDIR="$TEST_TMPDIR/filter-tests"
mkdir -p "$FDIR"

# Helper: run filter with optional ignore patterns
run_filter() {
  local classified="${1:-}" diff_file="$2" patterns="${3:-}"
  SHERLOCK_IGNORE_PATTERNS="$patterns" "$FILTER" "$classified" "$diff_file"
}

# ============================================================
# Lockfile / generated / asset skip
# ============================================================

cat > "$FDIR/classified.txt" << 'CLS'
lockfile:package-lock.json
generated:src/api.generated.ts
asset:logo.png
source:src/handler.ts
CLS

cat > "$FDIR/diff-skip.patch" << 'PATCH'
diff --git a/package-lock.json b/package-lock.json
--- a/package-lock.json
+++ b/package-lock.json
@@ -1,3 +1,4 @@
 {
+  "lockfileVersion": 3,
   "packages": {}
 }
diff --git a/src/api.generated.ts b/src/api.generated.ts
--- a/src/api.generated.ts
+++ b/src/api.generated.ts
@@ -1,2 +1,3 @@
 // auto-generated
+export type Foo = string
diff --git a/logo.png b/logo.png
--- a/logo.png
+++ b/logo.png
@@ -1 +1 @@
-binary
+binary-changed
diff --git a/src/handler.ts b/src/handler.ts
--- a/src/handler.ts
+++ b/src/handler.ts
@@ -1,3 +1,4 @@
 export function handler() {
+  return true
 }
PATCH

RESULT=$(run_filter "$FDIR/classified.txt" "$FDIR/diff-skip.patch")
assert_not_contains "skip: lockfile removed" "$RESULT" "package-lock.json"
assert_not_contains "skip: generated removed" "$RESULT" "api.generated.ts"
assert_not_contains "skip: asset removed" "$RESULT" "logo.png"
assert_contains "skip: source kept" "$RESULT" "src/handler.ts"

# ============================================================
# Import-only hunk filtering
# ============================================================

cat > "$FDIR/diff-import.patch" << 'PATCH'
diff --git a/src/app.ts b/src/app.ts
--- a/src/app.ts
+++ b/src/app.ts
@@ -1,3 +1,5 @@
 import { A } from './a'
+import { B } from './b'
+import { C } from './c'

 export function app() {}
PATCH

RESULT=$(run_filter "" "$FDIR/diff-import.patch")
assert_eq "import-only: filtered out" "" "$RESULT"

# ============================================================
# Import + real change (should keep)
# ============================================================

cat > "$FDIR/diff-import-real.patch" << 'PATCH'
diff --git a/src/app.ts b/src/app.ts
--- a/src/app.ts
+++ b/src/app.ts
@@ -1,5 +1,7 @@
 import { A } from './a'
+import { B } from './b'

 export function app() {
+  return B.create()
 }
PATCH

RESULT=$(run_filter "" "$FDIR/diff-import-real.patch")
assert_contains "import+real: kept" "$RESULT" "B.create()"

# ============================================================
# Whitespace-only hunk filtering
# ============================================================

cat > "$FDIR/diff-whitespace.patch" << 'PATCH'
diff --git a/src/fmt.ts b/src/fmt.ts
--- a/src/fmt.ts
+++ b/src/fmt.ts
@@ -1,3 +1,3 @@
-export function foo(){
-  return true
-}
+export function foo() {
+  return true
+  }
PATCH

RESULT=$(run_filter "" "$FDIR/diff-whitespace.patch")
assert_eq "whitespace-only: filtered out" "" "$RESULT"

# ============================================================
# Real changes kept
# ============================================================

cat > "$FDIR/diff-real.patch" << 'PATCH'
diff --git a/src/auth.ts b/src/auth.ts
--- a/src/auth.ts
+++ b/src/auth.ts
@@ -1,4 +1,6 @@
 export function login(user: string) {
-  return false
+  if (!user) throw new Error('missing user')
+  const result = authenticate(user)
+  return result
 }
PATCH

RESULT=$(run_filter "" "$FDIR/diff-real.patch")
assert_contains "real: file present" "$RESULT" "src/auth.ts"
assert_contains "real: new code present" "$RESULT" "authenticate(user)"

# ============================================================
# Multiple hunks — keep real, drop import-only
# ============================================================

cat > "$FDIR/diff-multi-hunk.patch" << 'PATCH'
diff --git a/src/service.ts b/src/service.ts
--- a/src/service.ts
+++ b/src/service.ts
@@ -1,3 +1,4 @@
 import { X } from './x'
+import { Y } from './y'

 export class Service {
@@ -10,4 +11,5 @@
   process() {
-    return null
+    return this.validate()
   }
 }
PATCH

RESULT=$(run_filter "" "$FDIR/diff-multi-hunk.patch")
assert_not_contains "multi-hunk: import hunk dropped" "$RESULT" "import { Y }"
assert_contains "multi-hunk: real hunk kept" "$RESULT" "this.validate()"

# ============================================================
# Ignore patterns via environment variable
# ============================================================

cat > "$FDIR/classified-src.txt" << 'CLS'
source:src/api/handler.ts
source:src/utils/config.ts
source:src/utils/db.ts
source:src/api/Button.stories.tsx
CLS

cat > "$FDIR/diff-ignore.patch" << 'PATCH'
diff --git a/src/api/handler.ts b/src/api/handler.ts
--- a/src/api/handler.ts
+++ b/src/api/handler.ts
@@ -1,3 +1,4 @@
 export function handler() {
+  return true
 }
diff --git a/src/utils/config.ts b/src/utils/config.ts
--- /dev/null
+++ b/src/utils/config.ts
@@ -0,0 +1,3 @@
+export const config = {
+  port: 3000,
+}
diff --git a/src/utils/db.ts b/src/utils/db.ts
--- /dev/null
+++ b/src/utils/db.ts
@@ -0,0 +1,3 @@
+export const db = {
+  query() {},
+}
diff --git a/src/api/Button.stories.tsx b/src/api/Button.stories.tsx
--- /dev/null
+++ b/src/api/Button.stories.tsx
@@ -0,0 +1,2 @@
+export default { title: 'Button' }
+export const Primary = () => {}
PATCH

RESULT=$(run_filter "$FDIR/classified-src.txt" "$FDIR/diff-ignore.patch" 'src/utils/*\n*.stories.tsx')
assert_contains "ignore: handler kept" "$RESULT" "src/api/handler.ts"
assert_not_contains "ignore: utils/config filtered" "$RESULT" "src/utils/config.ts"
assert_not_contains "ignore: utils/db filtered" "$RESULT" "src/utils/db.ts"
assert_not_contains "ignore: stories filtered" "$RESULT" "Button.stories.tsx"

# ============================================================
# Empty diff
# ============================================================

> "$FDIR/diff-empty.patch"
RESULT=$(run_filter "" "$FDIR/diff-empty.patch")
assert_eq "empty diff: no output" "" "$RESULT"
