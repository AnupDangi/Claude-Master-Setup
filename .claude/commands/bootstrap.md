---
description: Inspect this repository once and create minimal project-specific context
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(test:*), Bash(git status:*), Bash(bash */scripts/detect-stack.sh:*)
model: sonnet
---

# Bootstrap

Read `${CLAUDE_PLUGIN_ROOT}/MASTER-PROMPT.md`, then inspect the repository before
writing anything. The repository is the source of truth.

Create or refine only:

- `CLAUDE.md` — this project's mission, stack, run/verify commands, conventions
- `.master/project.json` — structured facts and maturity
- `.master/state/loop.json` — idle state if missing
- optional `.master/docs/ROADMAP.md` — at most four evidence-backed outcomes

Never paste harness instructions, agent rosters, loop internals, or generic
architecture into the project's `CLAUDE.md`. Do not implement feature code.

Finish by suggesting `/loop "first concrete task"` (default two iterations).
