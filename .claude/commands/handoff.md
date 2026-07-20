---
description: Refresh and summarize structured cross-session handoff
argument-hint: ""
allowed-tools: Read, Bash(git:*), Bash(python3 */scripts/write-handoff.py:*)
model: haiku
---

# Handoff

!`python3 ${CLAUDE_PLUGIN_ROOT}/scripts/write-handoff.py "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || echo ".master/state/handoff.json unavailable"`

Read `.master/state/handoff.json` and report:
- Completed task and status
- Current phase
- Validation result
- Commit/branch
- Assigned agents (if any)
- Correction log entries (if any)
- Remaining tasks and blockers (blocked_on)
- Last error (if any)
- Recovery: run `/loop steer` to continue from current phase

Do not create or update Markdown session/project-state/changelog files.

If `.master/state/memory-pending.json` exists and a claude-mem observation tool
is available, record its single durable observation, then remove the pending file.
If claude-mem is absent, continue normally; repository handoff is authoritative.
