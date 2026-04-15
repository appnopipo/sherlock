# Sherlock — PR Code Review Toolkit

Fast, token-efficient PR code review for Claude Code and Roo Code.

## Install

```bash
# Auto-detect targets (Claude Code / Roo Code)
./install.sh /path/to/your/project

# Force specific target
./install.sh /path/to/your/project --claude
./install.sh /path/to/your/project --roo
./install.sh /path/to/your/project --all

# Uninstall (removes only Sherlock files)
./uninstall.sh /path/to/your/project
```

**Requires**: `git`, standard unix tools (awk, sed, grep).
**Optional**: `eslint`, `tsc` (lint/type checking), `gh` CLI (PR metadata + inline comments), `jq` (permission merging).

## Commands

### `/review [base-branch]`

Full PR review. Collects diff data, runs lint/typecheck, analyzes against 5 categories.

```
/review            # Auto-detects main/master as base
/review develop    # Diff against develop branch
```

**Output**: Structured report with findings grouped by file, line-level comments, severity (P1-P4).

### `/review-pr [base-branch]`

Same analysis as `/review`, but posts findings as **inline comments directly on the GitHub PR**. Each issue appears on the exact diff line. Falls back to terminal output if `gh` is not installed or no PR exists.

```
/review-pr              # Auto-detects base branch
/review-pr develop      # Diff against develop
```

**Requires**: `gh` CLI authenticated with repo access.

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

## Multi-Editor Support

The installer auto-detects which editor(s) your project uses:

| Component | Claude Code | Roo Code |
|---|---|---|
| Commands | `.claude/commands/*.md` | `.roo/commands/*.md` |
| Rules | `.claude/rules/*.md` | `.roo/rules/*.md` |
| Scripts | `.sherlock/scripts/` (shared) | `.sherlock/scripts/` (shared) |
| Permissions | `.claude/settings.local.json` | `.roomodes` (custom mode) |

Scripts live in `.sherlock/scripts/` — a neutral path shared by both editors. Commands and rules are symlinked to each editor's expected directory with identical content.

For Roo Code, the installer creates a `sherlock` custom mode with read + command permissions.

## CI/CD Integration

### GitHub Actions — Inline PR Comments

```yaml
# .github/workflows/sherlock-review.yml
name: Sherlock PR Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: "/review-pr ${{ github.event.pull_request.base.ref }}"
```

### GitHub Actions — Gate Check Only

```yaml
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: "/review-quick ${{ github.event.pull_request.base.ref }}"
```

### Standalone Pipeline (without Claude Code CLI)

The data collection scripts are plain bash:

```yaml
- name: Collect PR data
  run: .sherlock/scripts/collect-pr-data.sh --base=${{ github.event.pull_request.base.ref }}

- name: Review with Claude API
  run: |
    DIFF=$(cat .review/diff-filtered.patch)
    STATS=$(cat .review/diff-stats.txt)
    # Call Claude API with the pre-computed data
    # Post result as PR comment
```

## Compatibility

### With Alfred (Code Quality Toolkit)

Both tools coexist with zero conflicts. Alfred uses `quality-*` prefixes, Sherlock uses `review-*`. Permissions are merged automatically.

```bash
/path/to/alfred/install.sh /your/project
/path/to/sherlock/install.sh /your/project
```

### With Claude Code Review (REVIEW.md)

If your project has a `REVIEW.md`, Sherlock reads it as additional review guidelines — fully complementary.

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
├── install.sh / uninstall.sh      # Multi-target symlink installer
├── commands/                       # Slash commands (→ .claude/ and/or .roo/)
│   ├── review.md                  # /review — Full PR review
│   ├── review-pr.md               # /review-pr — Inline comments on GitHub PR
│   ├── review-quick.md            # /review-quick — Gate check
│   └── review-commit.md           # /review-commit — Commit review
├── scripts/                       # Bash data collection (→ .sherlock/scripts/)
│   ├── collect-pr-data.sh         # Orchestrator (parallel execution)
│   ├── classify-files.sh          # File categorization
│   └── filter-noise.sh            # Diff noise removal (40-70% reduction)
├── rules/                         # AI rules (→ .claude/ and/or .roo/)
│   ├── SEVERITY.md                # Inverted severity model
│   ├── TOKEN-ECONOMY.md           # Token optimization rules
│   └── REVIEW-PRINCIPLES.md       # 5 review categories
└── settings.local.json            # Claude Code permissions template
```
