---
description: Cancel the active iterative loop
argument-hint: ""
allowed-tools: Bash(bash */scripts/cancel-loop.sh:*)
model: haiku
hide-from-slash-command-tool: "true"
---

# Cancel loop

!`bash ${CLAUDE_PLUGIN_ROOT}/scripts/cancel-loop.sh`

Confirm the loop state file was updated to cancelled. If none was active, say so.
