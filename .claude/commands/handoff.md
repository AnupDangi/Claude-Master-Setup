---
description: Checkpoint and hand off the active Agent Master run
argument-hint: "[--run ID] [--next TEXT]"
allowed-tools: Bash(node:*), Bash(git:*)
---

# Agent Master Handoff

Record completed work, decisions, remaining tasks, blockers, and the next action with `checkpoint`, then run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" handoff "$ARGUMENTS" --agent claude-code --format json
```

Return the JSON handoff summary. Do not claim validation is current unless Agent Master reports `green`.
