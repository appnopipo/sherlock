# 🔍 Sherlock

**Fast, token-efficient PR code review for Claude Code and Roo Code.**

Sherlock is a code review toolkit that integrates with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and [Roo Code](https://docs.roocode.com/) to review pull requests. It was built around two priorities: **speed** (reviews complete in seconds, not minutes) and **token economy** (uses ~4k tokens for a medium PR where naive approaches consume ~30k).

The key insight: Bash does the heavy lifting *before* AI sees anything. Diffs are collected, files are classified, noise is stripped, and lint/typecheck run in parallel — all before a single token is spent. The AI receives only what it needs to make decisions.

## Quick Start

```bash
# Clone
git clone https://github.com/appnopipo/sherlock.git

# Install in your project (auto-detects Claude Code / Roo Code)
./sherlock/install.sh /path/to/your/project

# Or force a specific target
./sherlock/install.sh /path/to/your/project --claude
./sherlock/install.sh /path/to/your/project --roo
./sherlock/install.sh /path/to/your/project --all

# Then use the slash commands in Claude Code or Roo Code:
/review              # Full PR review against main
/review-pr           # Same as /review but posts inline comments on GitHub PR
/review-quick        # Ultra-fast gate check
/review-commit last  # Review the last commit
```

**Requirements**: `git`, standard unix tools (awk, sed, grep).
**Optional**: `eslint`, `tsc` (for lint/type checking), `gh` CLI (for PR metadata), `jq` (for install script permission merging).

## Why Sherlock?

| Problem | How Sherlock Solves It |
|---|---|
| AI reads entire files to review a 5-line change | Bash pre-computes the filtered diff — AI never reads full files |
| Lockfile diffs waste thousands of tokens | `filter-noise.sh` strips lockfiles, formatting-only changes, import reordering |
| Multiple agents re-read the same diff | Single-agent architecture — one pass through the diff |
| Reviews take minutes and cost $15-25 | Targets <30s AI time, ~4k tokens for a medium PR |
| False positives flood the review | Inverted severity model — everything starts at P4, promoted only with evidence |
| Can't coexist with other Claude Code toolkits | Granular symlink installer — no conflicts with Alfred or other tools |

## How It Works

```
/review main
    │
    ▼
[Phase 1] Bash collects data → .review/
    ├── git diff -U3 (3-line context saves 20% vs default)
    ├── classify-files.sh → source / test / config / lock / generated
    ├── filter-noise.sh → strips lockfiles, formatting, imports (40-70% smaller)
    ├── [parallel] eslint --format compact on changed source files
    ├── [parallel] tsc --noEmit filtered to changed files
    ├── [parallel] test file existence check
    └── [parallel] gh pr view for PR metadata
    │
    ▼
[Phase 2] AI reads stats first (~100 tokens)
    → Decides review depth based on diff size
    │
    ▼
[Phase 3] AI reads filtered diff (single read)
    → Analyzes against 5 categories
    → Fetches extra context ONLY for suspected P1/P2 issues
    │
    ▼
[Phase 4] Structured output (<200 lines)
    → Findings grouped by file with line-level comments
    → No code snippets — file:line references only
```

### Token Budget

| Component | Tokens |
|---|---|
| Command prompt | ~800 |
| Rules (3 files) | ~400 |
| Stats + metadata | ~300 |
| Filtered diff (medium PR, ~150 lines) | ~2,000 |
| Output | ~500 |
| **Total** | **~4,000** |

A naive approach reading full files: 20,000–50,000 tokens for the same PR.

## Commands

### `/review [base-branch]`

Full PR review. Collects diff data, runs lint/typecheck in parallel, analyzes against 5 categories (Logic, Security, Performance, Maintainability, Testing).

```
/review              # Auto-detects main/master as base
/review develop      # Diff against develop branch
```

Output is a structured report with findings grouped by file:

```markdown
# PR Review: feature/user-auth

**Base**: main | **Commits**: 3 | **Files**: 8 source / 12 total | **Delta**: +247 -89

## Verdict: REQUEST_CHANGES

Implements user authentication with JWT tokens. Solid overall but has an
unsanitized input path in the login handler.

## Findings by File

### `src/handlers/login.ts`

| Line | Severity | Comment |
|------|----------|---------|
| 34   | P2       | User-supplied `redirect_url` passed to `res.redirect()` without validation — open redirect vulnerability |
| 67   | P4       | Magic number `3600` — extract to `SESSION_TTL_SECONDS` constant |

### `src/middleware/auth.ts`

| Line | Severity | Comment |
|------|----------|---------|
| 12   | P3       | Missing `await` on `verifyToken()` — async result is silently discarded |

## Summary

| Severity | Count |
|----------|-------|
| P2 High  | 1     |
| P3 Medium| 1     |
| P4 Low   | 1     |

**Lint**: Clean
**Types**: Clean
**Tests**: MISSING_TEST: src/handlers/login.ts
```

### `/review-quick [base-branch]`

Ultra-fast gate check. No deep analysis — scans for red flags only: hardcoded secrets, `debugger`/`console.log`, `eval()`, `dangerouslySetInnerHTML`, TODO/FIXME/HACK comments.

```
/review-quick
```

Target: <1,000 tokens, <5 seconds of AI time.

### `/review-commit [sha|last|last:N]`

Review specific commit(s). Same analysis pipeline as `/review` but scoped to commit range.

```
/review-commit              # Review HEAD commit
/review-commit last         # Same as above
/review-commit last:3       # Review last 3 commits as a batch
/review-commit abc1234      # Review specific commit
```

### `/review-pr [base-branch]`

Same analysis as `/review`, but instead of terminal output, **posts findings as inline comments directly on the GitHub PR**. Each issue appears on the exact line of the diff where it was found.

```
/review-pr              # Auto-detects base branch
/review-pr develop      # Diff against develop
```

Requires: `gh` CLI authenticated with repo access.

**How it works:**
1. Runs the same data collection and analysis pipeline as `/review`
2. Detects the open PR for the current branch via `gh pr view`
3. Builds a review payload with inline comments (one per finding)
4. Posts via GitHub API: `POST /repos/{owner}/{repo}/pulls/{number}/reviews`

**Review event mapping:**
| Findings | GitHub Review Event |
|---|---|
| Any P1 or P2 | `REQUEST_CHANGES` |
| Only P3/P4 | `COMMENT` |
| No findings | `APPROVE` |

Each inline comment follows the format: `**[severity] [category]** — [description]. [suggestion]`

**Example output on GitHub:**

> **P2 Security** — Unsanitized user input passed to `res.redirect()` — open redirect vulnerability. Consider validating against an allowlist of internal paths.

This is ideal for CI/CD pipelines where you want findings to appear directly in the PR diff view.

## Severity Model

All findings default to **P4 (Low)**. Promotion requires documented evidence — a false P1 wastes more developer time than a missed P4.

| Level | Meaning | Merge Impact |
|---|---|---|
| **P1 Critical** | Runtime failure or security breach. No guards in the chain. | Blocks merge |
| **P2 High** | Core functionality affected. No upstream mitigation. | Blocks merge |
| **P3 Medium** | Confirmed real issue. Isolated, has workaround. | Schedule dependent |
| **P4 Low** | Code hygiene, nice-to-have, future improvement. | Does not block |

When promoting above P4, the evidence is stated inline in the comment (e.g., "User-supplied `redirect_url` passed to `res.redirect()` without validation — open redirect vulnerability").

## The Noise Filter

`filter-noise.sh` is the single biggest token saver. It processes the raw unified diff and removes:

1. **Lockfile diffs** — `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, etc. These can be 80% of a raw patch.
2. **Generated file diffs** — Files matching `*.generated.*`, `*.g.*`, or containing "auto-generated" / "do not edit" headers.
3. **Import-only hunks** — Where all added/removed lines are `import` statements (reordering, adding imports for new usage).
4. **Whitespace-only hunks** — Where stripped lines are identical (formatting changes).

The result is typically **40–70% smaller** than the raw diff.

## CI/CD Integration

### GitHub Actions — Inline PR Comments (recommended)

Use `/review-pr` with the [Claude Code GitHub Action](https://github.com/anthropics/claude-code-action) to post findings as **inline comments on the exact lines** of the PR diff:

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
          fetch-depth: 0  # Full history needed for git diff

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: "/review-pr ${{ github.event.pull_request.base.ref }}"
```

This creates a proper GitHub review with:
- `REQUEST_CHANGES` if P1/P2 issues found
- `COMMENT` if only P3/P4
- `APPROVE` if no issues
- Each finding as an inline comment on the exact diff line

### GitHub Actions — Markdown Comment

For a simpler approach that posts a single markdown comment (not inline):

```yaml
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: "/review ${{ github.event.pull_request.base.ref }}"
```

### GitHub Actions — Gate Check Only

For a lightweight check on every push:

```yaml
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: "/review-quick ${{ github.event.pull_request.base.ref }}"
```

### Standalone Pipeline (without Claude Code CLI)

The data collection scripts are plain bash — they work without Claude Code. You can build a custom pipeline that:

1. Runs `collect-pr-data.sh` to generate the `.review/` data files
2. Sends the filtered diff + review prompt directly to the Claude API
3. Posts the result via `gh pr comment`

```yaml
# Example: standalone pipeline step
- name: Collect PR data
  run: .sherlock/scripts/collect-pr-data.sh --base=${{ github.event.pull_request.base.ref }}

- name: Review with Claude API
  run: |
    DIFF=$(cat .review/diff-filtered.patch)
    STATS=$(cat .review/diff-stats.txt)
    # Call Claude API with the pre-computed data
    # Post result as PR comment
```

This approach gives full control over cost and output format.

## Compatibility

### Multi-Editor Support

Sherlock supports both Claude Code and Roo Code. The installer auto-detects which is present:

```bash
# Auto-detect (installs for whichever is found)
./install.sh /your/project

# Or be explicit
./install.sh /your/project --claude    # Claude Code only
./install.sh /your/project --roo       # Roo Code only
./install.sh /your/project --all       # Both
```

**How it maps:**

| Component | Claude Code | Roo Code |
|---|---|---|
| Commands | `.claude/commands/*.md` | `.roo/commands/*.md` |
| Rules | `.claude/rules/*.md` | `.roo/rules/*.md` |
| Scripts | `.sherlock/scripts/` (shared) | `.sherlock/scripts/` (shared) |
| Permissions | `.claude/settings.local.json` | `.roomodes` (custom mode) |
| Runtime output | `.review/` | `.review/` |

Scripts live in `.sherlock/scripts/` — a neutral path shared by both editors. Commands and rules are symlinked to each editor's expected directory. The prompt content is identical.

For Roo Code, the installer creates a `sherlock` custom mode with read + command permissions. You can use it directly or run the slash commands from any mode.

### With Alfred (Code Quality Toolkit)

Sherlock and Alfred can coexist in the same project with zero conflicts:

```bash
# Install both
/path/to/alfred/install.sh /your/project
/path/to/sherlock/install.sh /your/project
```

| Component | Alfred | Sherlock | Conflict? |
|---|---|---|---|
| Commands | `quality-*` | `review-*` | No |
| Scripts | `.claude/scripts/validate-*.sh` | `.sherlock/scripts/collect-*.sh` | No |
| Rules | `SEPARATION.md`, `DRY.md`, etc. | `SEVERITY.md`, `TOKEN-ECONOMY.md`, `REVIEW-PRINCIPLES.md` | No |
| Runtime dir | `.quality/` | `.review/` | No |
| Permissions | Merged via `jq` | Merged via `jq` | No |

### With Claude Code Review (REVIEW.md)

If your project has a `REVIEW.md` file (used by Claude's managed Code Review service), Sherlock reads it as additional review guidelines. The two systems are fully complementary.

## Installation

```bash
# Install (auto-detects Claude Code / Roo Code)
./install.sh /path/to/your/project

# Install for specific target
./install.sh /path/to/your/project --all

# Uninstall (removes only Sherlock files, preserves everything else)
./uninstall.sh /path/to/your/project
```

The installer creates individual symlinks for each file. Scripts go to `.sherlock/scripts/` (neutral), commands and rules go to each editor's directory. Other toolkits, custom commands, and project-specific rules are left untouched.

## Project Structure

```
sherlock/
├── install.sh                    # Multi-target symlink installer
├── uninstall.sh                  # Clean removal (preserves other toolkits)
├── commands/                     # Slash commands (symlinked to .claude/ and/or .roo/)
│   ├── review.md                 # /review — Full PR review (terminal output)
│   ├── review-pr.md              # /review-pr — Posts inline comments on GitHub PR
│   ├── review-quick.md           # /review-quick — Gate check
│   └── review-commit.md          # /review-commit — Commit review
├── scripts/                      # Bash scripts (symlinked to .sherlock/scripts/)
│   ├── collect-pr-data.sh        # Data collection orchestrator (parallel)
│   ├── classify-files.sh         # File categorization engine
│   └── filter-noise.sh           # Diff noise removal (40-70% reduction)
├── rules/                        # AI rules (symlinked to .claude/ and/or .roo/)
│   ├── SEVERITY.md               # Inverted severity model
│   ├── TOKEN-ECONOMY.md          # Token optimization rules for AI
│   └── REVIEW-PRINCIPLES.md      # 5 review categories
└── settings.local.json           # Claude Code permissions template
```

When installed in a project:

```
your-project/
├── .sherlock/scripts/             # Shared scripts (neutral path)
├── .claude/                       # Claude Code (if detected)
│   ├── commands/review*.md        # → symlinks to sherlock/commands/
│   └── rules/SEVERITY.md (etc)   # → symlinks to sherlock/rules/
├── .roo/                          # Roo Code (if detected)
│   ├── commands/review*.md        # → symlinks to sherlock/commands/
│   └── rules/SEVERITY.md (etc)   # → symlinks to sherlock/rules/
└── .review/                       # Runtime output (gitignored)
```

## License

MIT
