---
description: Ultra-fast PR gate check — automated signals only, no deep analysis
allowed-tools: Bash, Read
---

# Quick PR Review

Ultra-fast gate check. No deep logic analysis. Checks automated signals only.

## Step 1: Collect data

```bash
.claude/scripts/collect-pr-data.sh --quick $ARGUMENTS
```

## Step 2: Read stats only

Read these small files:
1. `.review/meta.txt`
2. `.review/diff-stats.txt`
3. `.review/files-classified.txt`

## Step 3: Scan diff for red flags ONLY

Read `.review/diff-filtered.patch` and scan ONLY for these patterns in added lines (lines starting with `+`):

- `console.log` / `console.debug` / `debugger` statements
- Hardcoded secrets: strings matching `api_key`, `secret`, `password`, `token` in assignments
- `eval(` or `new Function(`
- `dangerouslySetInnerHTML`
- `TODO` / `FIXME` / `HACK` / `XXX` comments
- `eslint-disable` without justification comment

Do NOT analyze logic. Do NOT trace data flow. Do NOT read source files.

## Step 4: Output

Use this exact format (keep under 30 lines total):

```
## Quick Review: [branch]

**Status**: CLEAN | HAS_FLAGS
**Range**: [range from meta.txt]
**Files**: N total (X source, Y test) | +A -D lines

[If flags found, list by file:]

### `src/components/Example.tsx`

| Line | Flag | Comment |
|------|------|---------|
| 23 | SECRET | Hardcoded API key in assignment |
| 45 | DEBUG | `console.log` left in production code |

[If no flags:]
All clear. No red flags detected in diff.
```
