---
description: Pause an active loop with a concise blocker for another session
argument-hint: [reason]
allowed-tools: Read, Write, Edit, Bash(python3 */scripts/write-handoff.py:*)
model: sonnet
---

# Pause

Read `.master/state/loop.json`. Set:

- `active: false`
- `status: "paused"`
- `pause_reason`: `$ARGUMENTS` or the concrete blocker
- `next_action: "await_human"`
- `updated_at`: current ISO timestamp

If the pause is because an architecture decision is needed, also set:
- `architecture_pending: true`

If there are unresolved clarification questions, populate:
- `await_clarify_questions`: list of numbered question strings

Then run: `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/write-handoff.py "${CLAUDE_PROJECT_DIR:-$PWD}"`

Report the blocker plus what must happen before `/loop` is started again. Do not write Markdown docs.
