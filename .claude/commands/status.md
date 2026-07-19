---
description: Print the current loop phase and project state
allowed-tools: Read, Bash(cat:*), Bash(sed:*), Bash(git branch:*), Bash(git status:*)
model: haiku
---

# Status

- Loop state: !`cat .master/state/loop.json 2>/dev/null || echo "none — run /bootstrap first"`
- Project state: !`sed -n '1,30p' .master/docs/PROJECT_STATE.md 2>/dev/null || echo "no PROJECT_STATE.md"`
- Branch: !`git branch --show-current 2>/dev/null || echo "(not a git repo / detached)"`
- Uncommitted: !`git status --short 2>/dev/null | head -20 || echo "(git status unavailable)"`

Summarize in three lines: where the loop is, what's next, and whether anything is blocking.

Also print `pause_reason` / `await_clarify_questions` from `.master/state/loop.json` when present.
If phase is `paused` or `await_human_clarify`, tell the human how to resume (`/master:loop` after answers) or change a Decision (`/master:decide`).
