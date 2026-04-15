---
description: Full PR review posted as inline comments on GitHub PR via API
allowed-tools: Bash, Read
---

# PR Review → GitHub Inline Comments

Review the current branch and post findings as inline comments directly on the GitHub PR.
Each finding appears on the exact line of the diff where the issue was found.

## Phase 1: Data Collection

```bash
.sherlock/scripts/collect-pr-data.sh $ARGUMENTS
```

## Phase 2: Triage

Read these small files FIRST:

1. `.review/meta.txt` — branch info, commit count
2. `.review/diff-stats.txt` — change size by category
3. `.review/files-classified.txt` — what types of files changed
4. `.review/commits.txt` — commit messages (understand intent)
5. `.review/lint-results.txt` — lint issues (if available)
6. `.review/typecheck-results.txt` — type errors (if available)
7. `.review/test-hint.txt` — missing test files

If `.review/project-review-guidelines.txt` exists, read it for project guidelines.

**Review depth based on diff_filtered_lines:**
- **< 50 lines**: Single pass
- **50–300 lines**: Focus on source files
- **> 300 lines**: File-by-file, highest-churn first

## Phase 3: Review the Filtered Diff

Read `.review/diff-filtered.patch`.

**TOKEN RULES — strictly follow:**
- Do NOT read full source files. The diff is sufficient.
- Only fetch extra context for suspected P1/P2 — specific line ranges only.

**Analyze against the 5 categories in REVIEW-PRINCIPLES rule.**

For each finding, capture:
- `path`: relative file path (e.g., `src/handlers/login.ts`)
- `line`: the line number in the NEW version of the file (right side of diff)
- `severity`: P1/P2/P3/P4
- `comment`: brief actionable English sentence

**Common false positives to avoid:**
- `console.log` in logging utilities or debug modules
- `any` types in .d.ts declaration files
- Missing tests for configuration or type-only files
- "Complex" code that is inherently complex domain logic
- Style preferences that aren't bugs

## Phase 4: Check if GitHub posting is possible

First, check if `gh` CLI is available and if there's an open PR:

```bash
command -v gh >/dev/null 2>&1 && echo "GH_AVAILABLE" || echo "GH_MISSING"
```

If `gh` is available, get the PR info:

```bash
gh pr view --json number,headRefOid,title,baseRefName
```

**Three possible outcomes:**

| Situation | Action |
|---|---|
| `gh` not installed | **Fallback to terminal output** (same format as `/review`) with a note: "⚠ `gh` CLI not found. Showing review in terminal. Install `gh` and run `/review-pr` again to post inline comments on GitHub." |
| `gh` available but no open PR | **Fallback to terminal output** with a note: "⚠ No open PR found for this branch. Showing review in terminal. Push your branch and open a PR, then run `/review-pr` again." |
| `gh` available and PR exists | **Continue to Phase 5** to post inline comments |

When falling back, use the exact same output format as the `/review` command (Findings by File tables), but prepend the warning note at the top.

## Phase 5: Post Review to GitHub

This phase only runs if `gh` is available AND an open PR exists.

Build the review payload and post it via `gh api`.

**Determine the review event:**
- Any P1 or P2 findings → `REQUEST_CHANGES`
- Only P3/P4 findings → `COMMENT`
- No findings → `APPROVE`

**Build the review body** (summary posted as the main review comment):

```
🔍 **Sherlock PR Review**

[1-2 sentence summary of the PR and overall assessment]

| Severity | Count |
|----------|-------|
| P1 Critical | N |
| P2 High | N |
| P3 Medium | N |
| P4 Low | N |

*Automated review by Sherlock — [token-efficient PR review toolkit](https://github.com/appnopipo/sherlock)*
```

**Build inline comments array.** Each finding becomes a comment object:

```json
{
  "path": "src/handlers/login.ts",
  "line": 34,
  "side": "RIGHT",
  "body": "**P2 Security** — Unsanitized user input passed to `res.redirect()` — open redirect vulnerability. Consider validating against an allowlist of internal paths."
}
```

**Comment body format:** `**[severity] [category]** — [description]. [suggestion]`

**Post the review using `gh api`:**

```bash
gh api repos/{owner}/{repo}/pulls/{number}/reviews \
  --method POST \
  --input .review/gh-review-payload.json
```

To build and post the payload, write the JSON to `.review/gh-review-payload.json` first, then post it.

The JSON structure:

```json
{
  "commit_id": "<head SHA from Phase 4>",
  "event": "REQUEST_CHANGES | COMMENT | APPROVE",
  "body": "<review summary from above>",
  "comments": [
    {
      "path": "src/handlers/login.ts",
      "line": 34,
      "side": "RIGHT",
      "body": "**P2 Security** — description. Suggestion."
    }
  ]
}
```

Get the `{owner}/{repo}` from:
```bash
gh repo view --json nameWithOwner --jq '.nameWithOwner'
```

**IMPORTANT:**
- The `line` must be a line number in the NEW file (right side of diff, `side: "RIGHT"`)
- For deleted lines, use `side: "LEFT"` and the line number from the OLD file
- The `commit_id` MUST be the HEAD SHA of the PR (from Phase 4)
- If posting fails with 422, the line number may not be in the diff — skip that comment and retry without it

## Phase 6: Output confirmation

After posting, output a brief confirmation:

```
## Review Posted

**PR**: #[number] — [title]
**Verdict**: [APPROVE|REQUEST_CHANGES|COMMENT]
**Findings**: N total (X inline comments posted)
**URL**: [PR URL]

[If any comments failed to post:]
⚠ [N] comments could not be posted (lines not in diff range)
```
