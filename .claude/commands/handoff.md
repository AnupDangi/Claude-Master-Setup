---
description: Write HANDOFF.md and sync state before ending a session
allowed-tools: Task, Read, Grep, Glob, Write, Edit, Bash(git log:*), Bash(git status:*)
model: haiku
---

# Session Handoff

Recent commits: !`git log --oneline -10 2>/dev/null || echo "(no git history)"`
Working tree: !`git status --short 2>/dev/null || echo "(git status unavailable)"`

Delegate to the **docs-writer** subagent to:
1. Write/refresh `.master/docs/HANDOFF.md` — what was done, current state, next task, open questions, anything the next session needs.
2. Update `.master/docs/PROJECT_STATE.md` and `.master/docs/SESSION.md`.
3. Confirm `.master/state/loop.json` matches reality.

Keep it factual and grounded in the git log — no invented status.
