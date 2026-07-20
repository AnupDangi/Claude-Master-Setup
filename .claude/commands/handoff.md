---
description: Refresh and summarize structured cross-session handoff
argument-hint: ""
allowed-tools: Read, Bash(git:*), Bash(python3 */scripts/write-handoff.py:*)
model: haiku
---

# Handoff

!`python3 ${CLAUDE_PLUGIN_ROOT}/scripts/write-handoff.py "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || echo ".master/state/handoff.json unavailable"`

## Role

You refresh **cross-session memory**. Repository handoff beats chat and optional claude-mem.

## Report (from handoff.json + loop.json)

- Task + status
- Phase, iteration
- Validation
- Branch / last commit hint
- Assigned agents
- Correction log (brief)
- Blockers / last_error
- Recovery: `/loop` with steer text, or resume after pause

No Markdown PROJECT_STATE/SESSION/CHANGELOG writes.

If `memory-pending.json` exists and claude-mem is available, record that one observation and remove the pending file; otherwise continue.
