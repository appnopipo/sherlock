---
description: Full PR code review — structured analysis with pre-computed data
allowed-tools: Bash, Read
---

# PR Code Review

Review the current branch's changes against the base branch.

## Phase 1: Data Collection

Run the collection script:

```bash
.sherlock/scripts/collect-pr-data.sh $ARGUMENTS
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
- **> 300 lines**: Chunked review (see Phase 3B)

## Phase 3: Review the Diff

Check if `.review/chunks/manifest.txt` exists:
- **If NO chunks** (small/medium PR): follow **Phase 3A** (single-pass)
- **If chunks exist** (large PR): follow **Phase 3B** (chunked review)

### Phase 3A: Single-Pass Review (< 300 filtered lines)

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

### Phase 3B: Chunked Review (> 300 filtered lines)

Read `.review/chunks/manifest.txt` to see chunk layout. Each line has format:
`chunk-name|file-count|line-count|modules`

**For each chunk**, use the **Agent tool** (subagent) to review it in parallel. Each subagent receives:

1. The chunk patch file: `.review/chunks/<chunk-name>.patch`
2. The review principles (REVIEW-PRINCIPLES rule)
3. The severity definitions (SEVERITY rule)
4. Context from `.review/commits.txt` (intent)

**Subagent prompt template:**
```
Review this code diff chunk as part of a larger PR review.

Context: [paste 1-2 sentence summary from commits.txt]

Read the file .review/chunks/<chunk-name>.patch and analyze it against these principles:
- Correctness & Logic errors
- Security vulnerabilities
- Performance issues
- Error handling gaps
- Maintainability concerns

For each finding, output a JSON line:
{"file": "path/to/file.ts", "line": 42, "severity": "P2", "category": "Security", "comment": "Brief actionable description"}

Rules:
- Default severity is P4. Promote only with evidence.
- Do NOT read full source files. The diff is sufficient.
- Only output findings — no preamble, no summary.
- If no findings, output: {"findings": "none"}
```

After all subagents complete, **collect and merge** all findings.

**Cross-cutting synthesis**: After merging, do a quick scan of the combined findings plus `.review/files-classified.txt` to check for:
- Related changes across chunks that interact (e.g., API contract changes)
- Patterns that repeat across chunks (same mistake in multiple files)
- Missing integration concerns between modules

Add any cross-cutting findings to the merged list.

## Phase 4: Output

Generate the review in this exact format:

```markdown
# PR Review: [branch-name]

**Base**: [base] | **Commits**: N | **Files**: X source / Y total | **Delta**: +A -D

## Verdict: APPROVE | REQUEST_CHANGES | NEEDS_DISCUSSION

[1-2 sentence summary of what the PR does and overall assessment]

## Findings by File

Group all findings by file path. Within each file, list issues ordered by line number.

### `src/components/Example.tsx`

| Line | Severity | Comment |
|------|----------|---------|
| 12 | P2 | Unsanitized user input passed to `dangerouslySetInnerHTML` — no DOMPurify in chain |
| 45 | P4 | Magic number `86400` — extract to named constant (SECONDS_PER_DAY) |
| 78 | P3 | Missing `await` on async call — promise result is silently discarded |

### `src/services/api.ts`

| Line | Severity | Comment |
|------|----------|---------|
| 23 | P4 | Catch block returns empty array — consider discriminated union for error state |

[Repeat for each file with findings. Omit files with no findings.]

## Summary

| Severity | Count |
|----------|-------|
| P1 Critical | N |
| P2 High | N |
| P3 Medium | N |
| P4 Low | N |

**Lint**: [summary from lint-results.txt or "Clean"]
**Types**: [summary from typecheck-results.txt or "Clean"]
**Tests**: [summary from test-hint.txt or "All changed source files have tests"]

**Diff**: [raw lines] raw → [filtered lines] filtered ([X]% noise removed)
```

**Output rules:**
- Group findings by file, ordered by line number within each file
- Omit files with no findings
- Each comment is a brief, actionable English sentence
- For P1/P2, include evidence in the comment (why it's critical)
- Do NOT include code snippets — the line number is the reference
- Do NOT echo diff content back — the reviewer already has it
- Verdict is REQUEST_CHANGES only if P1 or P2 findings exist
- Total output under 200 lines
