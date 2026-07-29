---
description: Cancel the active Agent Master run
argument-hint: "[--run ID] [--reason TEXT]"
allowed-tools: Bash(node:*), Bash(git:*)
---

# Agent Master Cancel

Run:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/cli.js" cancel "$ARGUMENTS" --agent claude-code --format json
```

Report the cancelled run ID and preserved repository state.
