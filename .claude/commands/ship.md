---
description: Final pre-merge checklist for the current change
allowed-tools: Task, Bash(git diff:*), Read, Grep, Glob, Bash(bash scripts/:*), Bash(./scripts/:*), Bash(bash */scripts/*.sh:*)
model: sonnet
---

# Ship Check

Run the pre-merge gate for the current change:
1. Delegate to **validator** — confirm `GATE: GREEN`. If RED, stop.
2. Delegate to **reviewer** (and **security** if the change touches sensitive surfaces). No unresolved Critical/High.
3. Confirm docs are updated (PROJECT_STATE, CHANGELOG) via **docs-writer**.
4. Confirm the commit is atomic and the message follows the convention in `CLAUDE.md`.

Report a GO / NO-GO with the one or two things left, if any. Do not push without explicit approval.
