---
description: Pause the active Agent Master run
argument-hint: "[--run ID] [--blocker TEXT] [--next TEXT]"
allowed-tools: Bash(node:*), Bash(git:*)
---

# Agent Master Pause

Run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" pause "$ARGUMENTS" --agent claude-code --format json
```

Report the blocker and next action.
