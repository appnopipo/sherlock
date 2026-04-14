#!/bin/bash
# classify-files.sh — Categorizes changed files by type
# Input: file paths from stdin (one per line) or as arguments
# Output: category:path (one per line)
#
# Categories: lockfile, generated, test, docs, config, style, source

classify() {
  local file="$1"
  local basename="${file##*/}"
  local ext="${basename##*.}"

  # Lockfiles
  case "$basename" in
    package-lock.json|yarn.lock|pnpm-lock.yaml|Gemfile.lock|composer.lock|Pipfile.lock|poetry.lock|Cargo.lock|go.sum|flake.lock)
      echo "lockfile:$file"; return ;;
  esac
  case "$file" in
    *.lock) echo "lockfile:$file"; return ;;
  esac

  # Generated files
  case "$file" in
    *.generated.*|*.g.*|*_generated*|*.gen.*|*/generated/*|*/__generated__/*)
      echo "generated:$file"; return ;;
  esac
  # Check for auto-generated header (first line comment)
  if [ -f "$file" ] && head -2 "$file" 2>/dev/null | grep -qi "auto.generated\|do not edit\|this file is generated"; then
    echo "generated:$file"; return
  fi

  # Test files
  case "$file" in
    *.test.*|*.spec.*|*_test.*|*_spec.*|*/__tests__/*|*/__mocks__/*|*/test/*|*/tests/*|*_test.go|*.stories.*)
      echo "test:$file"; return ;;
  esac

  # Documentation
  case "$ext" in
    md|txt|rst|adoc)
      echo "docs:$file"; return ;;
  esac
  case "$file" in
    docs/*|doc/*|*/docs/*|*/doc/*)
      echo "docs:$file"; return ;;
  esac

  # Config files
  case "$basename" in
    Dockerfile|Makefile|Procfile|Vagrantfile|Taskfile.yml)
      echo "config:$file"; return ;;
  esac
  case "$basename" in
    .*)
      echo "config:$file"; return ;;
  esac
  case "$ext" in
    json|yaml|yml|toml|ini|cfg|conf|env|properties)
      echo "config:$file"; return ;;
  esac

  # Style files
  case "$ext" in
    css|scss|less|sass|styl)
      echo "style:$file"; return ;;
  esac

  # Assets
  case "$ext" in
    png|jpg|jpeg|gif|svg|ico|woff|woff2|ttf|eot|mp4|webm|mp3|pdf)
      echo "asset:$file"; return ;;
  esac

  # Everything else is source
  echo "source:$file"
}

# Read from stdin or arguments
if [ $# -gt 0 ]; then
  for file in "$@"; do
    classify "$file"
  done
else
  while IFS= read -r file; do
    [ -n "$file" ] && classify "$file"
  done
fi
