---
description: Cancel the active iterative loop
argument-hint: ""
allowed-tools: Bash(bash */scripts/cancel-loop.sh:*)
model: haiku
hide-from-slash-command-tool: "true"
---

# Cancel loop

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/cancel-loop.sh`

## Role

Confirm cancellation from durable state. If no loop was active, say so in one line.

Handoff is written by cancel-loop when applicable — mention that the next session should read `.master/state/handoff.json`.
