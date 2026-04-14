---
description: Inverted severity model — all findings default to P4, promote only with documented evidence
---

# Severity Classification

Every finding starts at P4. Promote ONLY with inline evidence.

- **P1 Critical**: Runtime failure or security breach. No guards in the chain. BLOCKS merge.
- **P2 High**: Core functionality affected, no upstream mitigation. BLOCKS merge.
- **P3 Medium**: Confirmed real issue, isolated, has workaround. Schedule dependent.
- **P4 Low**: Default. Code hygiene, nice-to-have, future improvement.

**Rules:**
- If in doubt, keep it at lower severity
- A false P1 wastes more dev time than a missed P4
- When promoting, state: "Promoted to PX because [specific evidence]"
- Never promote based on theoretical risk alone — trace the actual code path
