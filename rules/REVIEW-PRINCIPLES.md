---
description: Five review categories with focused checklists for diff-based analysis
---

# Review Categories

Analyze the diff against these five categories. Focus on what the diff SHOWS, not what it doesn't.

## 1. Logic & Correctness
- Off-by-one errors, null/undefined mishandling, missing edge cases
- Race conditions in async code (missing await, unhandled promises)
- Stale closures, missing effect dependencies
- Incorrect boolean logic, inverted conditions

## 2. Security
- User input reaching dangerous sinks (innerHTML, eval, SQL, shell commands)
- Auth/authz gaps in new endpoints or routes
- Secrets or tokens hardcoded in source
- Missing input validation at system boundaries

## 3. Performance
- API calls or DB queries inside loops (N+1 patterns)
- Unnecessary re-renders (inline objects/functions as props, missing memoization)
- Memory leaks (missing cleanup in effects, unbounded growth)
- Importing entire libraries for a single function

## 4. Maintainability
- Unclear naming (single-letter vars, abbreviations without context)
- Functions doing too many things (>30 lines of logic added)
- DRY violations WITHIN the diff (same pattern in multiple hunks)
- Magic numbers/strings without named constants

## 5. Testing
- New logic without corresponding test changes
- Assertions that test implementation instead of behavior
- Missing edge case coverage for new branches
