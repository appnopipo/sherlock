#!/bin/bash
# test-classify.sh — Tests for classify-files.sh

CLASSIFY="$SHERLOCK_DIR/scripts/classify-files.sh"

run_classify() {
  echo "$1" | "$CLASSIFY"
}

# Lockfiles
assert_eq "lockfile: package-lock.json" "lockfile:package-lock.json" "$(run_classify package-lock.json)"
assert_eq "lockfile: yarn.lock" "lockfile:yarn.lock" "$(run_classify yarn.lock)"
assert_eq "lockfile: pnpm-lock.yaml" "lockfile:pnpm-lock.yaml" "$(run_classify pnpm-lock.yaml)"
assert_eq "lockfile: Gemfile.lock" "lockfile:Gemfile.lock" "$(run_classify Gemfile.lock)"
assert_eq "lockfile: Cargo.lock" "lockfile:Cargo.lock" "$(run_classify Cargo.lock)"
assert_eq "lockfile: go.sum" "lockfile:go.sum" "$(run_classify go.sum)"
assert_eq "lockfile: generic .lock" "lockfile:something.lock" "$(run_classify something.lock)"

# Generated
assert_eq "generated: .generated.ts" "generated:src/api.generated.ts" "$(run_classify src/api.generated.ts)"
assert_eq "generated: .g.ts" "generated:src/models.g.ts" "$(run_classify src/models.g.ts)"
assert_eq "generated: _generated dir" "generated:src/__generated__/types.ts" "$(run_classify src/__generated__/types.ts)"

# Test files
assert_eq "test: .test.ts" "test:src/login.test.ts" "$(run_classify src/login.test.ts)"
assert_eq "test: .spec.ts" "test:src/login.spec.ts" "$(run_classify src/login.spec.ts)"
assert_eq "test: _test.go" "test:handler_test.go" "$(run_classify handler_test.go)"
assert_eq "test: __tests__ dir" "test:src/__tests__/login.ts" "$(run_classify src/__tests__/login.ts)"
assert_eq "test: __mocks__ dir" "test:src/__mocks__/api.ts" "$(run_classify src/__mocks__/api.ts)"
assert_eq "test: .stories.tsx" "test:src/Button.stories.tsx" "$(run_classify src/Button.stories.tsx)"

# Docs
assert_eq "docs: .md" "docs:README.md" "$(run_classify README.md)"
assert_eq "docs: .txt" "docs:notes.txt" "$(run_classify notes.txt)"
assert_eq "docs: .rst" "docs:guide.rst" "$(run_classify guide.rst)"
assert_eq "docs: docs/ dir" "docs:docs/api.js" "$(run_classify docs/api.js)"

# Config
assert_eq "config: .json" "config:tsconfig.json" "$(run_classify tsconfig.json)"
assert_eq "config: .yaml" "config:docker-compose.yaml" "$(run_classify docker-compose.yaml)"
assert_eq "config: .yml" "config:ci.yml" "$(run_classify ci.yml)"
assert_eq "config: .toml" "config:pyproject.toml" "$(run_classify pyproject.toml)"
assert_eq "config: .env" "config:app.env" "$(run_classify app.env)"
assert_eq "config: dotfile" "config:.eslintrc" "$(run_classify .eslintrc)"
assert_eq "config: Dockerfile" "config:Dockerfile" "$(run_classify Dockerfile)"
assert_eq "config: Makefile" "config:Makefile" "$(run_classify Makefile)"

# Style
assert_eq "style: .css" "style:src/main.css" "$(run_classify src/main.css)"
assert_eq "style: .scss" "style:src/theme.scss" "$(run_classify src/theme.scss)"
assert_eq "style: .less" "style:styles.less" "$(run_classify styles.less)"

# Assets
assert_eq "asset: .png" "asset:logo.png" "$(run_classify logo.png)"
assert_eq "asset: .svg" "asset:icon.svg" "$(run_classify icon.svg)"
assert_eq "asset: .woff2" "asset:font.woff2" "$(run_classify font.woff2)"
assert_eq "asset: .pdf" "asset:doc.pdf" "$(run_classify doc.pdf)"

# Source (fallback)
assert_eq "source: .ts" "source:src/handler.ts" "$(run_classify src/handler.ts)"
assert_eq "source: .tsx" "source:src/App.tsx" "$(run_classify src/App.tsx)"
assert_eq "source: .js" "source:index.js" "$(run_classify index.js)"
assert_eq "source: .py" "source:main.py" "$(run_classify main.py)"
assert_eq "source: .go" "source:server.go" "$(run_classify server.go)"
assert_eq "source: .rs" "source:lib.rs" "$(run_classify lib.rs)"
assert_eq "source: .java" "source:Main.java" "$(run_classify Main.java)"

# Multiple files via stdin
MULTI=$(printf 'src/app.ts\npackage-lock.json\nREADME.md\n' | "$CLASSIFY")
assert_contains "multi: source detected" "$MULTI" "source:src/app.ts"
assert_contains "multi: lockfile detected" "$MULTI" "lockfile:package-lock.json"
assert_contains "multi: docs detected" "$MULTI" "docs:README.md"
