---
description: Rules for minimizing token consumption during review
---

# Token Economy

- Read `.review/diff-stats.txt` FIRST — decide review depth before reading the diff
- Read `.review/diff-filtered.patch` — NEVER read `diff-full.patch`
- NEVER read full source files. The diff provides sufficient context.
- Only fetch additional context (Read tool) for suspected P1/P2 — read specific line ranges, not whole files
- Output uses `file:line` references only — no code snippets, no echoing diff content
- Omit empty severity sections entirely
- Keep each finding to ONE line
- Total output under 200 lines
