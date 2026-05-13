---
description: Rules for minimizing token consumption during review
---

# Token Economy

## General Rules
- Read `.review/diff-stats.txt` FIRST — decide review depth before reading the diff
- Read `.review/diff-filtered.patch` — NEVER read `diff-full.patch`
- NEVER read full source files. The diff provides sufficient context.
- Only fetch additional context (Read tool) for suspected P1/P2 — read specific line ranges, not whole files
- Output uses `file:line` references only — no code snippets, no echoing diff content
- Omit empty severity sections entirely
- Keep each finding to ONE line
- Total output under 200 lines

## Adaptive Chunking (large PRs)
- If `.review/chunks/manifest.txt` exists, the diff was auto-split into chunks
- Chunking activates when `diff_filtered_lines > 300`
- Each chunk targets ~500 lines grouped by module/directory proximity
- Review each chunk via subagent — this parallelizes the work and keeps focus tight
- Each subagent carries overhead (~1.5k tokens for rules + prompt), so total cost is higher than single-pass but quality per finding is better
- After chunk reviews, do ONE synthesis pass over combined findings — do not re-read the diffs
- For PRs under 300 filtered lines, always use single-pass — chunking adds unnecessary overhead
