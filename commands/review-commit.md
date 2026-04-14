---
description: Review specific commit(s) — pass SHA, "last", or "last:N"
allowed-tools: Bash, Read
---

# Commit Review

Review specific commit(s). Uses the same analysis pipeline as /review but scoped to commit range.

## Arguments

- No argument or `last`: review the HEAD commit
- `<sha>`: review that specific commit
- `last:N`: review the last N commits as a batch

## Step 1: Collect data

```bash
.claude/scripts/collect-pr-data.sh --commit=$ARGUMENTS
```

If no argument was provided, use `--commit=last`.

## Step 2-4: Follow /review workflow

Follow the exact same Phase 2 (Triage), Phase 3 (Review), and Phase 4 (Output) as the `/review` command.

The only difference: the header says "Commit Review" instead of "PR Review", and shows the commit SHA(s) instead of branch name.

```markdown
# Commit Review: [short-sha] [commit-message]

**Commits**: N | **Files**: X source / Y total | **Delta**: +A -D

[... same format as /review ...]
```
