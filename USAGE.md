# Sherlock — PR Code Review Toolkit for Claude Code

Fast, token-efficient PR code review powered by Claude Code CLI.

## Install

```bash
# Install in your project (granular symlinks — compatible with Alfred)
./install.sh /path/to/your/project

# Uninstall (removes only Sherlock files)
./uninstall.sh /path/to/your/project
```

Requires: `git`, standard unix tools. Optional: `eslint`, `tsc`, `gh` CLI.

## Commands

### `/review [base-branch]`

Full PR review. Collects diff data, runs lint/typecheck, analyzes against 5 categories.

```
/review            # Auto-detects main/master as base
/review develop    # Diff against develop branch
```

**Output**: Structured report with findings by severity (P1-P4), pre-computed signals, stats.

### `/review-quick [base-branch]`

Ultra-fast gate check. No deep analysis — scans for red flags only (secrets, debugger, eval, etc).

```
/review-quick
```

**Target**: <1,000 tokens, <5s AI time.

### `/review-commit [sha|last|last:N]`

Review specific commit(s).

```
/review-commit             # Review HEAD commit
/review-commit last        # Same as above
/review-commit last:3      # Review last 3 commits
/review-commit abc1234     # Review specific commit
```

## How It Works

```
/review main
    │
    ▼
[1] Bash collects data → .review/
    ├── diff (filtered: lockfiles, formatting, imports removed)
    ├── file classification (source/test/config/generated)
    ├── lint + typecheck results (parallel)
    └── test coverage hints
    │
    ▼
[2] AI reads stats first (tiny — decides review depth)
    │
    ▼
[3] AI reads filtered diff (single read — no full files)
    │
    ▼
[4] Structured output (<200 lines, no code snippets)
```

**Token budget** (medium PR, ~150 lines): ~4,000 tokens vs. ~30,000 naive approach.

## Compatibility

### With Alfred (Code Quality Toolkit)

Both tools can coexist in the same project:

```bash
# Install both
/path/to/alfred/install.sh /your/project
/path/to/sherlock/install.sh /your/project
```

No conflicts — Alfred uses `quality-*` prefixes, Sherlock uses `review-*`. Permissions are merged automatically.

### With Claude Code Review (REVIEW.md)

If your project has a `REVIEW.md` (used by Claude's managed Code Review service), Sherlock reads it as additional guidelines — fully complementary.

## Severity Model

All findings default to P4 (Low). Promotion requires documented evidence:

| Level | Meaning | Merge? |
|-------|---------|--------|
| P1 Critical | Runtime failure or security breach | BLOCKS |
| P2 High | Core functionality affected | BLOCKS |
| P3 Medium | Real issue, has workaround | Schedule dependent |
| P4 Low | Code hygiene, nice-to-have | Does not block |

## Project Structure

```
sherlock/
├── install.sh / uninstall.sh    # Granular symlink installer
├── commands/                     # Claude Code slash commands
│   ├── review.md                # /review — Full PR review
│   ├── review-quick.md          # /review-quick — Gate check
│   └── review-commit.md         # /review-commit — Commit review
├── scripts/                     # Bash data collection
│   ├── collect-pr-data.sh       # Orchestrator (parallel execution)
│   ├── classify-files.sh        # File categorization
│   └── filter-noise.sh          # Diff noise removal
├── rules/                       # Auto-loaded by Claude Code
│   ├── SEVERITY.md              # Inverted severity model
│   ├── TOKEN-ECONOMY.md         # Token optimization rules
│   └── REVIEW-PRINCIPLES.md     # 5 review categories
└── settings.local.json          # Permissions
```
