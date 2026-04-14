---
description: Full PR code review — structured analysis with pre-computed data
allowed-tools: Bash, Read
---

# PR Code Review

Review the current branch's changes against the base branch.

## Phase 1: Data Collection

Run the collection script:

```bash
.claude/scripts/collect-pr-data.sh $ARGUMENTS
```

## Phase 2: Triage

Read these small files FIRST — they tell you what to focus on:

1. `.review/meta.txt` — branch info, commit count
2. `.review/diff-stats.txt` — change size by category
3. `.review/files-classified.txt` — what types of files changed
4. `.review/commits.txt` — commit messages (understand intent)

Read pre-computed tool results:
5. `.review/lint-results.txt` — lint issues (if available)
6. `.review/typecheck-results.txt` — type errors (if available)
7. `.review/test-hint.txt` — missing test files

If `.review/project-review-guidelines.txt` exists, read it — these are the project's REVIEW.md guidelines.

**Decide review depth based on diff_filtered_lines from stats:**
- **< 50 lines**: Single pass, read entire filtered diff
- **50–300 lines**: Read filtered diff, focus analysis on source files
- **> 300 lines**: Read diff file-by-file, prioritize highest-churn source files

## Phase 3: Review the Filtered Diff

Read `.review/diff-filtered.patch`.

**TOKEN RULES — strictly follow:**
- Do NOT read any full source files. The diff has sufficient context.
- Only fetch additional context (Read tool with line offsets) if you suspect a P1/P2 issue that requires understanding code OUTSIDE the diff window to verify.
- When fetching context, read ONLY the specific function — never the whole file.

**Analyze the diff against the 5 categories defined in REVIEW-PRINCIPLES rule.**

For each potential finding:
1. Identify the issue in the diff
2. Classify severity (default P4 — see SEVERITY rule)
3. If promoting above P4, document the evidence inline
4. Write a one-line finding with suggestion

**Common false positives to avoid:**
- `console.log` in logging utilities or debug modules
- `any` types in .d.ts declaration files
- Missing tests for configuration or type-only files
- "Complex" code that is inherently complex domain logic
- Style preferences that aren't bugs

## Phase 4: Output

Generate the review in this exact format:

```markdown
# PR Review: [branch-name]

**Base**: [base] | **Commits**: N | **Files**: X source / Y total | **Delta**: +A -D

## Verdict: APPROVE | REQUEST_CHANGES | NEEDS_DISCUSSION

[1-2 sentence summary of what the PR does and overall assessment]

## Findings

### P1 Critical
- **[category]** `file:line` — [description]. Evidence: [why P1]. Suggestion: [fix]

### P2 High
- **[category]** `file:line` — [description]. Evidence: [why P2]. Suggestion: [fix]

### P3 Medium
- **[category]** `file:line` — [description]. Suggestion: [fix]

### P4 Low
- **[category]** `file:line` — [description]. Suggestion: [fix]

## Pre-computed Signals

**Lint**: [summary from lint-results.txt or "Clean"]
**Types**: [summary from typecheck-results.txt or "Clean"]
**Tests**: [summary from test-hint.txt or "All changed source files have tests"]

## Stats

- Diff: [raw lines] raw → [filtered lines] filtered ([X]% noise removed)
- Categories: [breakdown from files-classified.txt]
```

**Output rules:**
- Omit empty severity sections entirely (no "### P1 Critical" if no P1s)
- Do NOT include code snippets — use `file:line` references only
- Do NOT echo diff content back — the reviewer already has it
- Keep each finding to ONE line
- Verdict is REQUEST_CHANGES only if P1 or P2 findings exist
- Total output under 200 lines
