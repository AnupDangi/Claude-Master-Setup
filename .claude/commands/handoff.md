---
description: Write HANDOFF.md and sync state before ending a session
allowed-tools: Task, Read, Grep, Glob, Write, Edit, Bash(git log:*), Bash(git status:*)
model: haiku
---

# Session Handoff

Recent commits: !`git log --oneline -10 2>/dev/null`
Working tree: !`git status --short 2>/dev/null`

Delegate to the **docs-writer** subagent to:
1. Write/refresh `docs/HANDOFF.md` — what was done, current state, next task, open questions, anything the next session needs.
2. Update `docs/PROJECT_STATE.md` and `docs/SESSION.md`.
3. Confirm `.claude/state/loop.json` matches reality.

Keep it factual and grounded in the git log — no invented status.
