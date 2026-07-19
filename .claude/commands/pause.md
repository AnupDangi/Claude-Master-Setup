---
description: Pause an active loop with a concise blocker for another session
argument-hint: [reason]
allowed-tools: Read, Write, Edit
model: sonnet
---

# Pause

Read `.master/state/loop.json`. Set:

- `active: false`
- `status: "paused"`
- `pause_reason`: `$ARGUMENTS` or the concrete blocker
- `next_action: "await_human"`
- `updated_at`: current ISO timestamp

Then refresh `.master/state/handoff.json` if possible and report the blocker plus
what must happen before `/loop` is started again. Do not write Markdown docs.
