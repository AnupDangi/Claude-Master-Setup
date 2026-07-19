---
description: Print the current loop phase and project state
allowed-tools: Read, Bash(cat:*), Bash(git:*)
model: haiku
---

# Status

- Loop state: !`cat .master/state/loop.json 2>/dev/null || echo "none"`
- Project state: !`sed -n '1,30p' .master/docs/PROJECT_STATE.md 2>/dev/null || echo "no PROJECT_STATE.md"`
- Branch: !`git branch --show-current 2>/dev/null`
- Uncommitted: !`git status --short 2>/dev/null | head`

Summarize in three lines: where the loop is, what's next, and whether anything is blocking.
